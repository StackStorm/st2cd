#!/bin/bash
set -e

PROJECT=$1
VERSION=$2
FORK=$3
LOCAL_REPO=$4
GIT_REPO="git@github.com:${FORK}/${PROJECT}.git"
SHORT_VERSION=`echo ${VERSION} | cut -d "." -f1-2`
DEV_VERSION="${SHORT_VERSION}dev"
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


# SET DEV BWC VERSION INFO
VERSION_FILE="bwc_cli/__init__.py"
VERSION_STR="__version__ = '${DEV_VERSION}'"

VERSION_STR_MATCH=`grep "^${VERSION_STR}" ${VERSION_FILE} || true`
if [[ -z "${VERSION_STR_MATCH}" ]]; then
    echo "Setting version in ${VERSION_FILE} to ${DEV_VERSION}..."
    sed -i -e "s/\(__version__ = \).*/\1'${DEV_VERSION}'/" ${VERSION_FILE}

    VERSION_STR_MATCH=`grep "^${VERSION_STR}" ${VERSION_FILE} || true`
    if [[ -z "${VERSION_STR_MATCH}" ]]; then
        >&2 echo "ERROR: Unable to update the bwc version in ${VERSION_FILE}."
        exit 1
    fi
fi

MODIFIED=`git status | grep modified || true`
if [[ ! -z "${MODIFIED}" ]]; then
    git add -A
    git commit -qm "Update version info for development - ${DEV_VERSION}"
    git push origin ${BRANCH} -q
fi


# CLEANUP
cd ${CWD}
rm -rf ${LOCAL_REPO}
