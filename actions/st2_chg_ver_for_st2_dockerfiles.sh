#!/bin/bash
set -e

# When there's a st2 release:
#  - if missing, create a branch named ${BRANCH} (i.e., "vX.Y") in ${PROJECT}.
#  - update the Makefile on this branch to reference $ST2_VERSION (i.e., "X.Y.Z").
# Another script will update the master branch with the next dev release.

FORK=$1
PROJECT=$2
ST2_VERSION=$3
BRANCH=$4

GIT_REPO="git@github.com:${FORK}/${PROJECT}.git"
CWD=`pwd`

echo "Checking existence of branch ${BRANCH}"
BRANCH_EXISTS=`git ls-remote --heads ${GIT_REPO} | grep refs/heads/${BRANCH} || true`

if [[ -z ${LOCAL_REPO} ]]; then
    CURRENT_TIMESTAMP=`date +'%s'`
    RANDOM_NUMBER=`awk -v min=100 -v max=999 'BEGIN{srand(); print int(min+rand()*(max-min+1))}'`
    LOCAL_REPO=${PROJECT}_${CURRENT_TIMESTAMP}_${RANDOM_NUMBER}
fi

if [ -d "${LOCAL_REPO}" ]; then
    echo "Deleting ${LOCAL_REPO}"
    rm -rf ${LOCAL_REPO}
fi

echo "Cloning repository to ${LOCAL_REPO}"
git clone ${GIT_REPO} ${LOCAL_REPO}

cd ${LOCAL_REPO}
echo "Current directory: `pwd`..."

if [[ -z "${BRANCH_EXISTS}" ]]; then
    echo "Creating branch ${BRANCH}"
    git branch ${BRANCH}
fi

echo "Checking out ${BRANCH}"
git checkout ${BRANCH}

echo "Updating Makefile"
# Replace line in Makefile beginning "ST2_VERSION ?=" with "ST2_VERSION ?= ${ST2_VERSION}"
sed -i "/^ST2_VERSION.*/cST2_VERSION ?= ${ST2_VERSION}" Makefile
git add Makefile

echo "Committing and pushing changes to Makefile"
git commit -m "Update Makefile with ST2 version"
git push -u origin ${BRANCH} -q

echo "Cleaning up droppings"
cd ${CWD}
rm -rf ${LOCAL_REPO}
