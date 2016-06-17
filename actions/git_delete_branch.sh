#!/bin/bash
set -e

PROJECT=$1
BRANCH=$2
FORK=$3
GIT_REPO="git@github.com:${FORK}/${PROJECT}.git"
CURRENT_TIMESTAMP=`date +'%s'`
RANDOM_NUMBER=`awk -v min=100 -v max=999 'BEGIN{srand(); print int(min+rand()*(max-min+1))}'`
LOCAL_REPO=${PROJECT}_${CURRENT_TIMESTAMP}_${RANDOM_NUMBER}
CWD=`pwd`


# DELETING MASTER NOT ALLOWED
if [ "${BRANCH}" == "master" ]; then
    >&2 echo "ERROR: Deleting master branch is not permitted."
    exit 1
fi


# CHECK IF BRANCH EXISTS
BRANCH_EXISTS=`git ls-remote --heads ${GIT_REPO} | grep refs/heads/${BRANCH} || true`

if [[ -z "${BRANCH_EXISTS}" ]]; then
    echo "Branch ${BRANCH} does not exist in ${GIT_REPO}."
    exit 0
fi


# GIT CLONE AND BRANCH
echo "Cloning ${GIT_REPO} to ${LOCAL_REPO}..."
git clone ${GIT_REPO} ${LOCAL_REPO}
cd ${LOCAL_REPO}


# DELETE REMOTE BRANCH
git push origin :${BRANCH}


# CLEANUP
cd ${CWD}
rm -rf ${LOCAL_REPO}
