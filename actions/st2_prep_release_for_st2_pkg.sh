#!/bin/bash
set -e

PROJECT=$1
VERSION=$2
FORK=$3
LOCAL_REPO=$4
GIT_REPO="git@github.com:${FORK}/${PROJECT}.git"
SHORT_VERSION=`echo ${VERSION} | cut -d "." -f1-2`
MISTRAL_VERSION="st2-${VERSION}"
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


# SET NEW MISTRAL VERSION INFO AT MASTER
VERSION_FILE="rake/build/environment.rb"

# Update the mistral version (1st location)
echo "Setting mistral version in ${VERSION_FILE} to ${MISTRAL_VERSION}..."
sed -i -e "s/\(envpass :gitrev,[ ]*'\).*\(',[ ]*from: 'ST2MISTRAL_GITREV'\)/\1${MISTRAL_VERSION}\2/" ${VERSION_FILE}
NEW_MISTRAL_VERSION_STR="envpass :gitrev,[ ]*'${MISTRAL_VERSION}',[ ]*from: 'ST2MISTRAL_GITREV'"
NEW_MISTRAL_VERSION_STR_MATCH=`grep "${NEW_MISTRAL_VERSION_STR}" ${VERSION_FILE} || true`
if [[ -z "${NEW_MISTRAL_VERSION_STR_MATCH}" ]]; then
    >&2 echo "ERROR: Unable to update the mistral version (1st location) in ${VERSION_FILE}."
    exit 1
fi

# Update the mistral version (2nd location)
sed -i -e "s/\(envpass :mistral_version, \).*/\1'${VERSION}'/" ${VERSION_FILE}
NEW_MISTRAL_VERSION_STR="envpass :mistral_version, '${VERSION}'"
NEW_MISTRAL_VERSION_STR_MATCH=`grep "${NEW_MISTRAL_VERSION_STR}" ${VERSION_FILE} || true`
if [[ -z "${NEW_MISTRAL_VERSION_STR_MATCH}" ]]; then
    >&2 echo "ERROR: Unable to update the mistral version (2nd location) in ${VERSION_FILE}."
    exit 1
fi

git add ${VERSION_FILE}
git commit -qm "Update version info for release - ${VERSION}"
git push origin master -q


# SET NEW ST2 VERSION INFO AT RELEASE BRANCH
echo "Creating new branch ${BRANCH}..."
git checkout -b ${BRANCH} origin/master
VERSION_FILE="rake/build/environment.rb"

# Update the st2 version
echo "Setting version in ${VERSION_FILE} to ${BRANCH}..."
sed -i -e "s/\(envpass :gitrev,[ ]*'\).*\(',[ ]*from: 'ST2_GITREV'\)/\1${BRANCH}\2/" ${VERSION_FILE}
NEW_VERSION_STR="envpass :gitrev,[ ]*'${BRANCH}',[ ]*from: 'ST2_GITREV'"
NEW_VERSION_STR_MATCH=`grep "${NEW_VERSION_STR}" ${VERSION_FILE} || true`
if [[ -z "${NEW_VERSION_STR_MATCH}" ]]; then
    >&2 echo "ERROR: Unable to update the st2 version in ${VERSION_FILE}."
    exit 1
fi

git add ${VERSION_FILE}
git commit -qm "Update version info for release - ${VERSION}"
git push origin ${BRANCH} -q


# CLEANUP
cd ${CWD}
rm -rf ${LOCAL_REPO}
