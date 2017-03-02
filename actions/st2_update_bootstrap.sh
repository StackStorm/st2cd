#!/bin/bash
set -e

PROJECT="st2-packages"
BRANCH="master"
FORK="StackStorm"
LOCAL_REPO=$1
GIT_REPO="git@github.com:${FORK}/${PROJECT}.git"
CWD=`pwd`


# CHECK IF BRANCH EXISTS
BRANCH_EXISTS=`git ls-remote --heads ${GIT_REPO} | grep refs/heads/${BRANCH} || true`

if [[ -z "${BRANCH_EXISTS}" ]]; then
    >&2 echo "ERROR: Branch ${BRANCH} doesn't exist in ${GIT_REPO}."
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

# CHECKOUT BRANCH
if [ "${BRANCH}" != "master" ]; then
    echo "Checking out branch ${BRANCH}..."
    git checkout -b ${BRANCH} origin/${BRANCH}
fi

# Replace BRANCH that uses single-quotes with new version
sed -i "s/BRANCH=.*${PREVIOUS_VERSION}.*/BRANCH='${VERSION}'/g" ./scripts/st2_bootstrap.sh

git add ./scripts
git commit -m "Updating bootstrap script with $VERSION release"
git push


# CLEANUP
cd ${CWD}
rm -rf ${LOCAL_REPO}
