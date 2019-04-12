#!/bin/bash
set -e

PROJECT=$1
VERSION=$2
FORK=$3
LOCAL_REPO=$4
BRANCH=$5
GIT_REPO="git@github.com:${FORK}/${PROJECT}.git"
TAGGED_VERSION="v${VERSION}"
CWD=`pwd`


# CHECK IF BRANCH EXISTS
BRANCH_EXISTS=`git ls-remote --heads ${GIT_REPO} | grep refs/heads/${BRANCH} || true`

if [[ -z "${BRANCH_EXISTS}" ]]; then
    >&2 echo "ERROR: Branch ${BRANCH} does not exist in ${GIT_REPO}."
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
git checkout -B ${BRANCH} origin/${BRANCH}


# CHECK IF TAG EXISTS
TAGGED=`git tag -l ${TAGGED_VERSION} || true`
if [[ -z "${TAGGED}" ]]; then
    # TAG RELEASE
    echo "Tagging release ${TAGGED_VERSION} for ${PROJECT} on branch ${BRANCH}..."
    git tag -a ${TAGGED_VERSION} -m "Creating tag ${TAGGED_VERSION} for branch ${BRANCH}"
    git push origin ${TAGGED_VERSION} -q
else
    echo "Tag ${TAGGED_VERSION} already exists."
fi

# CLEANUP
cd ${CWD}
rm -rf ${LOCAL_REPO}
