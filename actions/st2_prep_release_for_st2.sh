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
PUSH=0


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


# SET VERSION AND DATE IN CHANGELOG ON MASTER
DATE=`date +%s`
RELEASE_DATE=`date +"%B %d, %Y"`
CHANGELOG_FILE="CHANGELOG.rst"
RELEASE_STRING="${VERSION} - ${RELEASE_DATE}"
DASH_HEADER_CMD="printf '%.0s-' {1..${#RELEASE_STRING}}"
DASH_HEADER=$(/bin/bash -c "${DASH_HEADER_CMD}")

if [[ ! -e "${CHANGELOG_FILE}" ]]; then
    >&2 echo "ERROR: Changelog ${CHANGELOG_FILE} does not exist."
    exit 1
fi

CHANGELOG_VERSION_MATCH=`grep "${VERSION} - " ${CHANGELOG_FILE} || true`
if [[ -z "${CHANGELOG_VERSION_MATCH}" ]]; then
    echo "Setting version in ${CHANGELOG_FILE} to ${VERSION}..."
    sed -i "s/^in development/${RELEASE_STRING}/Ig" ${CHANGELOG_FILE}
    sed -i "/${RELEASE_STRING}/!b;n;c${DASH_HEADER}" ${CHANGELOG_FILE}
    sed -i "/${RELEASE_STRING}/i \in development\n--------------\n\n" ${CHANGELOG_FILE}
fi

MODIFIED=`git status | grep modified || true`
if [[ ! -z "${MODIFIED}" ]]; then
    echo "Committing the changelog update to origin master..."
    git add ${CHANGELOG_FILE}
    git commit -qm "Update changelog info for release - ${VERSION}"
    git push origin master -q
fi


# CREATE RELEASE BRANCH AND SET NEW ST2 VERSION INFO
echo "Creating new branch ${BRANCH}..."
git checkout -b ${BRANCH} origin/master

COMMON_INIT_FILES=(
    "st2common/st2common/__init__.py"
    "st2client/st2client/__init__.py"
)

# Add all the runners
RUNNER_INIT_FILES=($(find contrib/runners -maxdepth 3 -name __init__.py -not -path "*tests*" -not -path "*query*" -not -path "*callback*" -not -path "*functions*"))

ALL_INIT_FILES=("${COMMON_INIT_FILES[@]}" "${RUNNER_INIT_FILES[@]}")

for f in "${ALL_INIT_FILES[@]}"
do
    if [[ ! -e "$f" ]]; then
        >&2 echo "ERROR: Version file ${f} does not exist."
        exit 1
    fi

    VERSION_STR="__version__ = '${VERSION}'"

    VERSION_STR_MATCH=`grep "${VERSION_STR}" ${f} || true`
    if [[ -z "${VERSION_STR_MATCH}" ]]; then
        echo "Setting version in ${f} to ${VERSION}..."
        sed -i -e "s/\(__version__ = \).*/\1'${VERSION}'/" ${f}

        VERSION_STR_MATCH=`grep "${VERSION_STR}" ${f} || true`
        if [[ -z "${VERSION_STR_MATCH}" ]]; then
            >&2 echo "ERROR: Unable to update the st2 version in ${f}."
            exit 1
        fi
    fi
done

MODIFIED=`git status | grep modified || true`
if [[ ! -z "${MODIFIED}" ]]; then
    echo "Committing the st2 version update on branch ${BRANCH}..."
    git add -A
    git commit -qm "Update version info for release - ${VERSION}"
	PUSH=1
fi


# SET NEW MISTRAL VERSION
MISTRAL_VERSION=st2-${VERSION}
MISTRALCLIENT_REPO=https://github.com/StackStorm/python-mistralclient.git
MISTRALCLIENT_REPO_NAME=python-mistralclient.git

# Check if the branch exists in the python-mistralclient repo.
MISTRAL_BRANCH_EXISTS=`git ls-remote --heads ${MISTRALCLIENT_REPO} | grep refs/heads/${MISTRAL_VERSION} || true`

if [[ -z "${MISTRAL_BRANCH_EXISTS}" ]]; then
    >&2 echo "WARNING: Branch ${MISTRAL_VERSION} does not exist in ${MISTRALCLIENT_REPO}."
fi

# Replace the python-mistralclient version number in st2.
OLD_REQUIREMENT=${MISTRALCLIENT_REPO_NAME}
NEW_REQUIREMENT=${MISTRALCLIENT_REPO_NAME}@${MISTRAL_VERSION}

ST2_ACTION_IN_REQ_FILE="st2actions/in-requirements.txt"

if [[ ! -e "${ST2_ACTION_IN_REQ_FILE}" ]]; then
    >&2 echo "ERROR: Requirement file ${ST2_ACTION_IN_REQ_FILE} does not exist."
    exit 1
fi  

NEW_REQUIREMENT_STR_MATCH=`grep "${NEW_REQUIREMENT}" ${ST2_ACTION_IN_REQ_FILE} || true`
if [[ -z "${NEW_REQUIREMENT_STR_MATCH}" ]]; then
    echo "Updating requirement in ${ST2_ACTION_IN_REQ_FILE} to \"${NEW_REQUIREMENT}\"..."
    sed -i "s/${OLD_REQUIREMENT}/${NEW_REQUIREMENT}/g" ${ST2_ACTION_IN_REQ_FILE}

    NEW_REQUIREMENT_STR_MATCH=`grep "${NEW_REQUIREMENT}" ${ST2_ACTION_IN_REQ_FILE} || true`
    if [[ -z "${NEW_REQUIREMENT_STR_MATCH}" ]]; then
        >&2 echo "ERROR: Unable to update the mistralclient version in ${ST2_ACTION_IN_REQ_FILE}."
        exit 1
    fi
fi

ST2_REQ_FILE="requirements.txt"

if [[ ! -e "${ST2_REQ_FILE}" ]]; then
    >&2 echo "ERROR: Requirement file ${ST2_REQ_FILE} does not exist."
    exit 1
fi

NEW_REQUIREMENT_STR_MATCH=`grep "${NEW_REQUIREMENT}" ${ST2_REQ_FILE} || true`
if [[ -z "${NEW_REQUIREMENT_STR_MATCH}" ]]; then
    echo "Updating requirement in ${ST2_REQ_FILE} to \"${NEW_REQUIREMENT}\"..."
    sed -i "s/${OLD_REQUIREMENT}/${NEW_REQUIREMENT}/g" ${ST2_REQ_FILE}

    NEW_REQUIREMENT_STR_MATCH=`grep "${NEW_REQUIREMENT}" ${ST2_REQ_FILE} || true`
    if [[ -z "${NEW_REQUIREMENT_STR_MATCH}" ]]; then
        >&2 echo "ERROR: Unable to update the mistralclient version in ${ST2_REQ_FILE}."
        exit 1
    fi
fi

MODIFIED=`git status | grep modified || true`
if [[ ! -z "${MODIFIED}" ]]; then
	echo "Committing the mistralclient version update on branch ${BRANCH}..."
    git add -A
    git commit -qm "Update mistralclient version - ${MISTRAL_VERSION}"
	PUSH=1
fi


# PUSH COMMITS TO RELEASE BRANCH
if [[ ${PUSH} -eq 1 ]]; then
	echo "Pushing commits to origin ${BRANCH}..."
    git push origin ${BRANCH} -q
fi


# CLEANUP
cd ${CWD}
rm -rf ${LOCAL_REPO}
