#!/bin/bash
set -e

PROJECT=$1
VERSION=$2
FORK=$3
LOCAL_REPO=$4
GIT_REPO="git@github.com:${FORK}/${PROJECT}.git"
SHORT_VERSION=`echo ${VERSION} | cut -d "." -f1-2`
DEV_VERSION="$(sed "s/\(.\)\(.\)/\1.\2/" <<< "$((${SHORT_VERSION//.}+1))")dev"
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


####################################
# MASTER
####################################

# Update mistral 'mistral_version' to latest dev "X.Ydev" at 'rake/build/environment.rb'
VERSION_FILE="rake/build/environment.rb"
NEW_MISTRAL_VERSION_STR="envpass :mistral_version, '${DEV_VERSION}'"
NEW_MISTRAL_VERSION_STR_MATCH=`grep "${NEW_MISTRAL_VERSION_STR}" ${VERSION_FILE} || true`
if [[ -z "${NEW_MISTRAL_VERSION_STR_MATCH}" ]]; then
    echo "[master] Setting 'mistral_version' in '${VERSION_FILE}' to latest dev: '${DEV_VERSION}'..."
    sed -i -e "s/\(envpass :mistral_version, \).*/\1'${DEV_VERSION}'/" ${VERSION_FILE}

    NEW_MISTRAL_VERSION_STR_MATCH=`grep "${NEW_MISTRAL_VERSION_STR}" ${VERSION_FILE} || true`
    if [[ -z "${NEW_MISTRAL_VERSION_STR_MATCH}" ]]; then
        >&2 echo "[master] ERROR: Unable to update the 'mistral_version' to latest dev in '${VERSION_FILE}'."
        exit 1
    fi
fi

# Pin bash installer to latest stable 'st2-packages' branch in 'master'
# Replace only the first occurrence!
VERSION_FILE="scripts/st2_bootstrap.sh"
echo "[master] Setting version in ${VERSION_FILE} to ${BRANCH}..."
sed "0,/BRANCH=.*/ s//BRANCH='${BRANCH}'/" ${VERSION_FILE}


MODIFIED=`git status | grep modified || true`
if [[ ! -z "${MODIFIED}" ]]; then
    git add ${VERSION_FILE}
    git commit -qm "Update version info for release - ${VERSION}"
    git push origin master -q
fi

####################################
# NEW BRANCH
####################################
# CREATE RELEASE BRANCH AND SET NEW ST2 VERSION INFO
echo "Creating new branch ${BRANCH}..."
git checkout -b ${BRANCH} origin/master


# Update st2 'ST2_GITREV' to latest stable 'vX.Y' branch at 'rake/build/environment.rb'
VERSION_FILE="rake/build/environment.rb"
NEW_VERSION_STR="envpass :gitrev,[ ]*'${BRANCH}',[ ]*from: 'ST2_GITREV'"
NEW_VERSION_STR_MATCH=`grep "${NEW_VERSION_STR}" ${VERSION_FILE} || true`
if [[ -z "${NEW_VERSION_STR_MATCH}" ]]; then
    echo "[${BRANCH}] Setting version in '${VERSION_FILE}' to '${BRANCH}'..."
    sed -i -e "s/\(envpass :gitrev,[ ]*'\).*\(',[ ]*from: 'ST2_GITREV'\)/\1${BRANCH}\2/" ${VERSION_FILE}

    NEW_VERSION_STR_MATCH=`grep "${NEW_VERSION_STR}" ${VERSION_FILE} || true`
    if [[ -z "${NEW_VERSION_STR_MATCH}" ]]; then
        >&2 echo "[${BRANCH}] ERROR: Unable to update the st2 version in '${VERSION_FILE}'."
        exit 1
    fi
fi

# Update mistral 'ST2MISTRAL_GITREV' branch to latest stable 'st2-X.Y' at 'rake/build/environment.rb'
VERSION_FILE="rake/build/environment.rb"
NEW_MISTRAL_VERSION_STR="envpass :gitrev,[ ]*'${MISTRAL_VERSION}',[ ]*from: 'ST2MISTRAL_GITREV'"
NEW_MISTRAL_VERSION_STR_MATCH=`grep "${NEW_MISTRAL_VERSION_STR}" ${VERSION_FILE} || true`
if [[ -z "${NEW_MISTRAL_VERSION_STR_MATCH}" ]]; then
    echo "[master] Setting 'ST2MISTRAL_GITREV' branch in '${VERSION_FILE}' to latest stable '${MISTRAL_VERSION}'..."
    sed -i -e "s/\(envpass :gitrev,[ ]*'\).*\(',[ ]*from: 'ST2MISTRAL_GITREV'\)/\1${MISTRAL_VERSION}\2/" ${VERSION_FILE}

    NEW_MISTRAL_VERSION_STR_MATCH=`grep "${NEW_MISTRAL_VERSION_STR}" ${VERSION_FILE} || true`
    if [[ -z "${NEW_MISTRAL_VERSION_STR_MATCH}" ]]; then
        >&2 echo "[master] ERROR: Unable to update the 'ST2MISTRAL_GITREV' in '${VERSION_FILE}'."
        exit 1
    fi
fi

# Update mistral 'mistral_version' to latest stable 'X.Y' version at 'rake/build/environment.rb'
VERSION_FILE="rake/build/environment.rb"
NEW_MISTRAL_VERSION_STR="envpass :mistral_version, '${VERSION}'"
NEW_MISTRAL_VERSION_STR_MATCH=`grep "${NEW_MISTRAL_VERSION_STR}" ${VERSION_FILE} || true`
if [[ -z "${NEW_MISTRAL_VERSION_STR_MATCH}" ]]; then
    echo "[master] Setting 'mistral_version' in '${VERSION_FILE}' to latest stable '${VERSION}'..."
    sed -i -e "s/\(envpass :mistral_version, \).*/\1'${VERSION}'/" ${VERSION_FILE}

    NEW_MISTRAL_VERSION_STR_MATCH=`grep "${NEW_MISTRAL_VERSION_STR}" ${VERSION_FILE} || true`
    if [[ -z "${NEW_MISTRAL_VERSION_STR_MATCH}" ]]; then
        >&2 echo "[master] ERROR: Unable to update the 'mistral_version' in '${VERSION_FILE}'."
        exit 1
    fi
fi

# Update 'ST2_GITREV' in 'circle.yml'
CIRCLE_YML_FILE="circle.yml"
echo "[${BRANCH}] Setting 'ST2_GITREV' in '${CIRCLE_YML_FILE}' to '${BRANCH}'..."
sed -i -e "s/#\s*\(ST2_GITREV:\s*\).*/\1${BRANCH}/" ${CIRCLE_YML_FILE}

# Update 'ST2MISTRAL_GITREV' in 'circle.yml'
echo "[${BRANCH}] Setting 'ST2MISTRAL_GITREV' in '${CIRCLE_YML_FILE}' to '${MISTRAL_VERSION}'..."
sed -i -e "s/#\s*\(ST2MISTRAL_GITREV:\s*\).*/\1${MISTRAL_VERSION}/" ${CIRCLE_YML_FILE}


MODIFIED=`git status | grep modified || true`
if [[ ! -z "${MODIFIED}" ]]; then
    git add -A
    git commit -qm "Update version info for release - ${VERSION}"
    git push origin ${BRANCH} -q
fi


# CLEANUP
cd ${CWD}
rm -rf ${LOCAL_REPO}
