#!/bin/bash
set -e

PROJECT=$1
VERSION=$2
FORK=$3
LOCAL_REPO=$4
GIT_REPO="git@github.com:${FORK}/${PROJECT}.git"
SHORT_VERSION=`echo ${VERSION} | cut -d "." -f1-2`
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


# SET NEW BWC VERSION INFO
VERSION_FILE="update-versions"
VERSION_STR=`cat ${VERSION_FILE}`
VERSION_ARRAY=(${VERSION_STR})
OLD_DEV_VERSION=${VERSION_ARRAY[0]}
OLD_VERSION_STR="${VERSION_STR}"
NEW_VERSION_STR="${OLD_DEV_VERSION} ${VERSION}"

NEW_VERSION_STR_MATCH=`grep "${NEW_VERSION_STR}" ${VERSION_FILE} || true`
if [[ -z "${NEW_VERSION_STR_MATCH}" ]]; then
    echo "Setting version in ${VERSION_FILE} to \"${NEW_VERSION_STR}\"..."
    sed -i "s/${OLD_VERSION_STR}/${NEW_VERSION_STR}/g" ${VERSION_FILE}

    NEW_VERSION_STR_MATCH=`grep "${NEW_VERSION_STR}" ${VERSION_FILE} || true`
    if [[ -z "${NEW_VERSION_STR_MATCH}" ]]; then
        >&2 echo "ERROR: Unable to update the version in ${VERSION_FILE}."
        exit 1
    fi
fi

MODIFIED=`git status | grep modified || true`
if [[ ! -z "${MODIFIED}" ]]; then
    git add ${VERSION_FILE}
    git commit -qm "Update version to ${VERSION}"
    git push origin ${BRANCH} -q
fi


# CLEANUP
cd ${CWD}
rm -rf ${LOCAL_REPO}
