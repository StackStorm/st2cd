#!/bin/bash
set -e

PROJECT=$1
VERSION=$2
NEXT_VERSION=$3
FORK=$4
LOCAL_REPO=$5
GIT_REPO="git@github.com:${FORK}/${PROJECT}.git"
SHORT_VERSION=`echo ${VERSION} | cut -d "." -f1-2`
DEV_VERSION="${SHORT_VERSION}dev"
DEV_NEXT_VERSION="${NEXT_VERSION}dev"
BRANCH="master"
CWD=`pwd`


# GIT CLONE AND BRANCH
if [[ -z ${LOCAL_REPO} ]]; then
    CURRENT_TIMESTAMP=`date +'%s'`
    RANDOM_NUMBER=`awk -v min=100 -v max=999 'BEGIN{srand(); print int(min+rand()*(max-min+1))}'`
    LOCAL_REPO=${PROJECT}_${CURRENT_TIMESTAMP}_${RANDOM_NUMBER}
fi

echo "Cloning ${GIT_REPO} to ${LOCAL_REPO}..."

if [ -d "${LOCAL_REPO}" ]; then
    rm -rf ${LOCAL_REPO}
fi

git clone ${GIT_REPO} ${LOCAL_REPO}

cd ${LOCAL_REPO}
echo "Currently at directory `pwd`..."
git checkout master


# SET NEW ST2 VERSION INFO
VERSION_FILE="update-versions"
VERSION_STR=`cat ${VERSION_FILE}`
VERSION_ARRAY=(${VERSION_STR})
OLD_VERSION=${VERSION_ARRAY[1]}
OLD_VERSION_STR="${DEV_VERSION} ${OLD_VERSION}"
NEW_VERSION_STR="${DEV_NEXT_VERSION} ${SHORT_VERSION}"

NEW_VERSION_STR_MATCH=`grep "${NEW_VERSION_STR}" ${VERSION_FILE} || true`
if [[ -z "${NEW_VERSION_STR_MATCH}" ]]; then
    sed -i "s/${OLD_VERSION_STR}/${NEW_VERSION_STR}/g" ${VERSION_FILE}
fi

NEW_VERSION_STR_MATCH=`grep "${NEW_VERSION_STR}" ${VERSION_FILE} || true`
if [[ -z "${NEW_VERSION_STR_MATCH}" ]]; then
    >&2 echo "ERROR: Unable to update the st2 version in ${VERSION_FILE}."
    exit 1
fi

git add ${VERSION_FILE}
git commit -qm "Update version info for release - ${VERSION}"


# PUSH NEW BRANCH WITH COMMITS
git push origin ${BRANCH} -q


# CLEANUP
cd ${CWD}
rm -rf ${LOCAL_REPO}
