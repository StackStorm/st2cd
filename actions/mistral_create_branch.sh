#!/bin/bash
set -e

VERSION=$1
REPO_MAIN=$2
REPO_CLIENT=$3
REPO_ACTION=$4
REQUIREMENTS=$(echo "$5" | sed 's/\\\\n/\n/g' | sed 's/\\n/\n/g')

GIT=`which git`
SHORT_VERSION=`echo ${VERSION} | cut -d "." -f1-2`
BRANCH=st2-${VERSION}

REGEX="^([0-9])+.([0-9])+.([0-9])+$"

if ! [[ ${VERSION} =~ ${REGEX} ]]; then
    >&2 echo "ERROR: Invalid version format."
    exit 1
fi

echo "Checking if branches exist..."
REPOS=(
    ${REPO_MAIN}
    ${REPO_CLIENT}
    ${REPO_ACTION}
)

for REPO in "${REPOS[@]}"
do
    if [[ ! -d "${REPO}" ]]; then
        >&2 echo "ERROR: ${REPO} does not exist."
        exit 1
    fi

    cd ${REPO}
    BRANCH_EXISTS=`${GIT} ls-remote --heads | grep refs/heads/${BRANCH}; echo $?`
    if [[ ${BRANCH_EXISTS} != 1 ]]; then
        >&2 echo "ERROR: Branch ${BRANCH} already exists in ${REPO}."
        exit 1
    fi
done



echo "Creating branch for mistralclient..."
cd ${REPO_CLIENT}
${GIT} checkout -b ${BRANCH}

VERSION_FILE="mistralclient/__init__.py"
echo "Setting version in ${VERSION_FILE} to ${VERSION}..."
echo "__version__ = '${VERSION}'" > ${VERSION_FILE}
${GIT} add ${VERSION_FILE}

VERSION_FILE="setup.cfg"
echo "Setting version in ${VERSION_FILE} to ${VERSION}..."
# 1. First delete all "version = " occurences - this way we handle both - minor and patch
# release correctly
sed -i '/^version = .*$/d' ${VERSION_FILE}
# 2. Append a version
sed -i "s/^name = python-mistralclient/name = python-mistralclient\nversion = ${VERSION}/g" ${VERSION_FILE}
${GIT} add ${VERSION_FILE}

${GIT} commit -qm "Update version info for release - ${VERSION}"
${GIT} push origin ${BRANCH} -q


#####################################
# st2mistral
#####################################
echo "Creating branch for st2mistral..."
cd ${REPO_ACTION}
${GIT} checkout -b ${BRANCH}
${GIT} push origin ${BRANCH} -q


#####################################
# mistral
#####################################
echo "Creating branch for mistral..."
cd ${REPO_MAIN}
${GIT} checkout -b ${BRANCH}

VERSION_FILE="version_st2.py"
echo "Setting version in ${VERSION_FILE} to ${VERSION}..."
sed -i -e "s/\(__version__ = \).*/\1'${VERSION}'/" ${VERSION_FILE}


# Update 'ST2_PACKAGES_BRANCH' to latest stable "vX.Y" branch at 'circle.yml'
VERSION_FILE="circle.yml"
NEW_ST2_PACKAGES_BRANCH_STR="ST2_PACKAGES_BRANCH: v${SHORT_VERSION}"
NEW_ST2_PACKAGES_BRANCH_STR_MATCH=`grep "${NEW_ST2_PACKAGES_BRANCH_STR}" ${VERSION_FILE} || true`
if [[ -z "${NEW_ST2_PACKAGES_BRANCH_STR_MATCH}" ]]; then
    echo "[mistral][${BRANCH}] Setting 'ST2_PACKAGES_BRANCH' in '${VERSION_FILE}' to latest stable 'v${SHORT_VERSION}' branch..."
    sed -i -e "s/\(ST2_PACKAGES_BRANCH:\).*/\1 v${SHORT_VERSION}/" ${VERSION_FILE}

    NEW_ST2_PACKAGES_BRANCH_STR_MATCH=`grep "${NEW_ST2_PACKAGES_BRANCH_STR}" ${VERSION_FILE} || true`
    if [[ -z "${NEW_ST2_PACKAGES_BRANCH_STR_MATCH}" ]]; then
        >&2 echo "[mistral][${BRANCH}] ERROR: Unable to update the 'ST2_PACKAGES_BRANCH' in '${VERSION_FILE}'!"
        exit 1
    fi
fi

# Update 'ST2MISTRAL_GITREV' to latest stable "st2-X.Y.Z" branch at 'circle.yml'
VERSION_FILE="circle.yml"
NEW_ST2MISTRAL_GITREV_STR="ST2MISTRAL_GITREV: ${BRANCH}"
NEW_ST2MISTRAL_GITREV_STR_MATCH=`grep "${NEW_ST2MISTRAL_GITREV_STR}" ${VERSION_FILE} || true`
if [[ -z "${NEW_ST2MISTRAL_GITREV_STR_MATCH}" ]]; then
    echo "[mistral][${BRANCH}] Setting 'ST2MISTRAL_GITREV' in '${VERSION_FILE}' to latest stable '${BRANCH}' branch..."
    sed -i -e "s/\(ST2MISTRAL_GITREV:\).*/\1 ${BRANCH}/" ${VERSION_FILE}

    NEW_ST2MISTRAL_GITREV_STR_MATCH=`grep "${NEW_ST2MISTRAL_GITREV_STR}" ${VERSION_FILE} || true`
    if [[ -z "${NEW_ST2MISTRAL_GITREV_STR_MATCH}" ]]; then
        >&2 echo "[mistral][${BRANCH}] ERROR: Unable to update the 'ST2MISTRAL_GITREV' in '${VERSION_FILE}'!"
        exit 1
    fi
fi


git add -A
git commit -qm "Update version info for release - ${VERSION}"

if [[ $(grep -c . <<< "${REQUIREMENTS}") > 1 ]]; then
    echo "Updating requirements.txt..."
    REQUIREMENTS=`echo "${REQUIREMENTS}" | sed '/https:\/\/github.com\/stackstorm/Id'`
    echo "${REQUIREMENTS}" > requirements.txt

    grep -q 'python-mistralclient' requirements.txt || echo "git+https://github.com/StackStorm/python-mistralclient.git@${BRANCH}#egg=python-mistralclient" >> requirements.txt

    # Note: Newer versions of troveclient (>=2.10.0) don't work with our mistralclient fork because of the version changing we do
    # See https://github.com/StackStorm/mistral/pull/24 for context and details
    sed -i "s/^python-troveclient.*/python-troveclient==2.9.0/g" requirements.txt

    ${GIT} add requirements.txt
    ${GIT} diff --quiet --exit-code --cached || ${GIT} commit -m "Pin dependencies in requirements.txt"
fi

${GIT} push origin ${BRANCH} -q
