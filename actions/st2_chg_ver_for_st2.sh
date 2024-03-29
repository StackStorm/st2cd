#!/bin/bash
set -e

PROJECT=$1
VERSION=$2
FORK=$3
BRANCH=$4
UPDATE_CHANGELOG=$5
LOCAL_REPO=$6
GIT_REPO="git@github.com:${FORK}/${PROJECT}.git"
CWD=`pwd`
PUSH=0

# Temporary workaround until we fix "False" default value for boolean
# See https://github.com/StackStorm/st2/issues/4649
if [ "$#" -eq 4 ]; then
    # UPDATE_CHANGELOG not provided due to bug in StackStorm
    UPDATE_CHANGELOG="0"
fi


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

# SET ST2 VERSION INFO
COMMON_INIT_FILES=(
    "st2common/st2common/__init__.py"
    "st2client/st2client/__init__.py"
    "st2actions/st2actions/__init__.py"
    "st2api/st2api/__init__.py"
    "st2auth/st2auth/__init__.py"
    "st2reactor/st2reactor/__init__.py"
    "st2stream/st2stream/__init__.py"
    "st2tests/st2tests/__init__.py"
)

# Add all the runners
RUNNER_INIT_FILES=($(find contrib/runners -mindepth 3 -maxdepth 3 -name __init__.py -not -path "*tests*" -not -path "*query*" -not -path "*callback*" -not -path "*functions*"))

ALL_INIT_FILES=("${COMMON_INIT_FILES[@]}" "${RUNNER_INIT_FILES[@]}")

for INIT_FILE in "${ALL_INIT_FILES[@]}"
do
    echo "Setting version in: ${INIT_FILE}"

    if [[ ! -e "${INIT_FILE}" ]]; then
        >&2 echo "ERROR: Version file ${INIT_FILE} does not exist."
        exit 1
    fi

    # The black lint checker forces us to use double quotes for these
    # but we check for both single quotes and double quotes to ensure
    # that we find them all
    VERSION_STR="__version__ = ['\"]${VERSION}['\"]"

    VERSION_STR_MATCH=`grep "${VERSION_STR}" ${INIT_FILE} || true`
    if [[ -z "${VERSION_STR_MATCH}" ]]; then
        echo "Setting version in ${INIT_FILE} to ${VERSION}..."
        sed -i -e "s/\(__version__ = \).*/\1\"${VERSION}\"/" ${INIT_FILE}

        VERSION_STR_MATCH=`grep "${VERSION_STR}" ${INIT_FILE} || true`
        if [[ -z "${VERSION_STR_MATCH}" ]]; then
            >&2 echo "ERROR: Unable to update the version in ${INIT_FILE}."
            exit 1
        fi
    fi
done

# Set version attribute for all the bundled packs (core, linux, examples, etc.)
BUNDLED_PACKS_METADATA_FILES=($(find contrib/ -mindepth 2 -maxdepth 2 -name pack.yaml))

# Temporary disable fail on failure for grep step where failure is OK
set +e

# NOTE: We don't set dev versions because pack version needs to be a valid semver string
# (e.g 1.2.3) and Python dev version is not a valid semver string (e.g 2.10dev)
IS_DEV_VERSION=$(echo ${VERSION} |grep -v "dev$")
EXIT_CODE=$?


if [ ${EXIT_CODE} -eq 1 ]; then
    IS_DEV_VERSION=true
else
    IS_DEV_VERSION=false
fi

if [ "${IS_DEV_VERSION}" = "false" ]; then
    for PACK_METADATA_FILE in "${BUNDLED_PACKS_METADATA_FILES[@]}"
    do
        echo "Setting pack version in: ${PACK_METADATA_FILE}"

        if [[ ! -e "${PACK_METADATA_FILE}" ]]; then
            >&2 echo "ERROR: Pack metadata file ${PACK_METADATA_FILE} does not exist."
            exit 1
        fi

        VERSION_STR_MATCH=`grep -Po "^version\s*:\s*${VERSION}" ${PACK_METADATA_FILE}`
        if [[ -z "${VERSION_STR_MATCH}" ]]; then
            echo "Setting version in ${PACK_METADATA_FILE} to ${VERSION}..."
            sed -i -E "s/^version\s*:\s*(.*?)$/version: ${VERSION}/" ${PACK_METADATA_FILE}

            VERSION_STR_MATCH=`grep "${VERSION}" ${PACK_METADATA_FILE} || true`
            if [[ -z "${VERSION_STR_MATCH}" ]]; then
                >&2 echo "ERROR: Unable to update the version in >${PACK_METADATA_FILE}."
                exit 1
            fi
        fi
    done
else
    echo "Skipping setting version attribute in pack.yaml files for dev version"
fi

# Re-enable fail on failure
set -e

MODIFIED=`git status | grep modified || true`
if [[ ! -z "${MODIFIED}" ]]; then
    echo "Committing the st2 version update on branch ${BRANCH}..."
    git add -A
    git commit -qm "Update version to ${VERSION}"
    PUSH=1
fi


# SET VERSION AND DATE IN CHANGELOG
if [ "${UPDATE_CHANGELOG}" -eq "1" ]; then
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
        sed -i "s/^In development/${RELEASE_STRING}/Ig" ${CHANGELOG_FILE}
        sed -i "/${RELEASE_STRING}/!b;n;c${DASH_HEADER}" ${CHANGELOG_FILE}
        sed -i "/${RELEASE_STRING}/i \In development\n--------------\n\n" ${CHANGELOG_FILE}
    fi

    MODIFIED=`git status | grep modified || true`
    if [[ ! -z "${MODIFIED}" ]]; then
        echo "Committing the changelog update on branch ${BRANCH}..."
        git add ${CHANGELOG_FILE}
        git commit -qm "Update changelog for ${VERSION}"
        PUSH=1
    fi
fi


# PUSH COMMITS TO RELEASE BRANCH
if [[ ${PUSH} -eq 1 ]]; then
    echo "Pushing commits to origin ${BRANCH}..."
    git push origin ${BRANCH} -q
fi


# CLEANUP
cd ${CWD}
rm -rf ${LOCAL_REPO}
