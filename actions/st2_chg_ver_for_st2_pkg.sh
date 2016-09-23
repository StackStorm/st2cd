#!/bin/bash
set -e

PROJECT=$1
VERSION=$2
FORK=$3
BRANCH=$4
LOCAL_REPO=$5
GIT_REPO="git@github.com:${FORK}/${PROJECT}.git"

MISTRAL_BRANCH="master"
if [ "${BRANCH}" != "master" ]; then 
    MISTRAL_BRANCH="st2-${VERSION}"
fi

CWD=`pwd`


# CHECK IF BRANCH EXISTS
BRANCH_EXISTS=`git ls-remote --heads ${GIT_REPO} | grep refs/heads/${BRANCH} || true`

if [[ -z "${BRANCH_EXISTS}" ]]; then
    >&2 echo "ERROR: Branch ${BRANCH} does not exist in ${GIT_REPO}."
    exit 1
fi

# GIT CLONE SPECIFIC BRANCH
if [[ -z ${LOCAL_REPO} ]]; then
    CURRENT_TIMESTAMP=`date +'%s'`
    RANDOM_NUMBER=`awk -v min=100 -v max=999 'BEGIN{srand(); print int(min+rand()*(max-min+1))}'`
    LOCAL_REPO=${PROJECT}_${CURRENT_TIMESTAMP}_${RANDOM_NUMBER}
fi

echo "Cloning ${GIT_REPO} to ${LOCAL_REPO}..."

if [ -d "${LOCAL_REPO}" ]; then
    rm -rf ${LOCAL_REPO}
fi

git clone -b ${BRANCH} --single-branch ${GIT_REPO} ${LOCAL_REPO}

cd ${LOCAL_REPO}
echo "Currently at directory `pwd`..."

# SET VERSION INFO
VERSION_FILE="rake/build/environment.rb"

# Update the mistral version (1st location)
NEW_MISTRAL_VERSION_STR="envpass :gitrev,[ ]*'${MISTRAL_BRANCH}',[ ]*from: 'ST2MISTRAL_GITREV'"
NEW_MISTRAL_VERSION_STR_MATCH=`grep "${NEW_MISTRAL_VERSION_STR}" ${VERSION_FILE} || true`
if [[ -z "${NEW_MISTRAL_VERSION_STR_MATCH}" ]]; then
    echo "Setting mistral version (1st location) in ${VERSION_FILE} to ${MISTRAL_BRANCH}..."
    sed -i -e "s/\(envpass :gitrev,[ ]*'\).*\(',[ ]*from: 'ST2MISTRAL_GITREV'\)/\1${MISTRAL_BRANCH}\2/" ${VERSION_FILE}

    NEW_MISTRAL_VERSION_STR_MATCH=`grep "${NEW_MISTRAL_VERSION_STR}" ${VERSION_FILE} || true`
    if [[ -z "${NEW_MISTRAL_VERSION_STR_MATCH}" ]]; then
        >&2 echo "ERROR: Unable to update the mistral version (1st location) in ${VERSION_FILE}."
        exit 1
    fi
fi

# Update the mistral version (2nd location)
NEW_MISTRAL_VERSION_STR="envpass :mistral_version, '${VERSION}'"
NEW_MISTRAL_VERSION_STR_MATCH=`grep "${NEW_MISTRAL_VERSION_STR}" ${VERSION_FILE} || true`
if [[ -z "${NEW_MISTRAL_VERSION_STR_MATCH}" ]]; then
    echo "Setting mistral version (2nd location) in ${VERSION_FILE} to ${MISTRAL_BRANCH}..."
    sed -i -e "s/\(envpass :mistral_version, \).*/\1'${VERSION}'/" ${VERSION_FILE}

    NEW_MISTRAL_VERSION_STR_MATCH=`grep "${NEW_MISTRAL_VERSION_STR}" ${VERSION_FILE} || true`
    if [[ -z "${NEW_MISTRAL_VERSION_STR_MATCH}" ]]; then
        >&2 echo "ERROR: Unable to update the mistral version (2nd location) in ${VERSION_FILE}."
        exit 1
    fi
fi

# Update the st2 version at rake/build/environment.rb
NEW_VERSION_STR="envpass :gitrev,[ ]*'${BRANCH}',[ ]*from: 'ST2_GITREV'"
NEW_VERSION_STR_MATCH=`grep "${NEW_VERSION_STR}" ${VERSION_FILE} || true`
if [[ -z "${NEW_VERSION_STR_MATCH}" ]]; then
    echo "Setting version in ${VERSION_FILE} to ${BRANCH}..."
    sed -i -e "s/\(envpass :gitrev,[ ]*'\).*\(',[ ]*from: 'ST2_GITREV'\)/\1${BRANCH}\2/" ${VERSION_FILE}

    NEW_VERSION_STR_MATCH=`grep "${NEW_VERSION_STR}" ${VERSION_FILE} || true`
    if [[ -z "${NEW_VERSION_STR_MATCH}" ]]; then
        >&2 echo "ERROR: Unable to update the st2 version in ${VERSION_FILE}."
        exit 1
    fi
fi

# Update the st2 version at circle.yml
CIRCLE_YML_FILE="circle.yml"
echo "Setting version in ${CIRCLE_YML_FILE} to ${BRANCH}..."
sed -i -e "s/\(ST2_GITREV:[ ]*\).*/\1${BRANCH}/" ${CIRCLE_YML_FILE}
sed -i -e "s/\(ST2MISTRAL_GITREV:[ ]*\).*/\1${MISTRAL_BRANCH}/" ${CIRCLE_YML_FILE}

MODIFIED=`git status | grep modified || true`
if [[ ! -z "${MODIFIED}" ]]; then
    git add -A
    git commit -qm "Update version to ${VERSION}"
    git push origin ${BRANCH} -q
fi


# CLEANUP
cd ${CWD}
rm -rf ${LOCAL_REPO}
