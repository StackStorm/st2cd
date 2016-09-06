#!/bin/bash
set -e

PROJECT=$1
VERSION=$2
FORK=$3
LOCAL_REPO=$4
GIT_REPO="git@github.com:${FORK}/${PROJECT}.git"
SHORT_VERSION=`echo ${VERSION} | cut -d "." -f1-2`
BRANCH="v${SHORT_VERSION}"
CWD=`pwd`


# CHECK IF BRANCH EXISTS
BRANCH_EXISTS=`git ls-remote --heads ${GIT_REPO} | grep refs/heads/${BRANCH} || true`

if [[ ! -z "${BRANCH_EXISTS}" ]]; then
    >&2 echo "ERROR: Branch ${BRANCH} already exist in ${GIT_REPO}."
    exit 1
fi


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

echo "Creating new branch ${BRANCH}..."
git checkout -b ${BRANCH} origin/master


# SET NEW BWC VERSION INFO
VERSION_FILE="pkg_version"
VERSION_STR="${VERSION}"

VERSION_STR_MATCH=`grep "^${VERSION_STR}" ${VERSION_FILE} || true`
if [[ -z "${VERSION_STR_MATCH}" ]]; then
    echo "Setting version in ${VERSION_FILE} to ${VERSION}..."
    echo ${VERSION} > ${VERSION_FILE}

    VERSION_STR_MATCH=`grep "^${VERSION_STR}" ${VERSION_FILE} || true`
    if [[ -z "${VERSION_STR_MATCH}" ]]; then
        >&2 echo "ERROR: Unable to update the bwc version in ${VERSION_FILE}."
        exit 1
    fi
fi

MODIFIED=`git status | grep modified || true`
if [[ ! -z "${MODIFIED}" ]]; then
    git add ${VERSION_FILE}
    git commit -qm "Update version info for release - ${VERSION}"
    git push origin ${BRANCH} -q
fi


# CLEANUP
cd ${CWD}
rm -rf ${LOCAL_REPO}
