#!/bin/bash
set -e

VERSION=$1
REPO_MAIN=$2
REPO_CLIENT=$3
REPO_ACTION=$4
REQUIREMENTS=$(echo "$5" | sed 's/\\n/\n/g')

GIT=`which git`
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

echo "Creating branch for mistral..."
cd ${REPO_MAIN}
${GIT} checkout master
${GIT} pull origin master -q
${GIT} checkout -b ${BRANCH}

if [[ $(grep -c . <<< "${REQUIREMENTS}") > 1 ]]; then
    echo "Updating requirements.txt..."
    REQUIREMENTS=`echo "${REQUIREMENTS}" | sed '/https:\/\/github.com\/stackstorm/d'`
    echo "${REQUIREMENTS}" > requirements.txt
    ${GIT} add requirements.txt
    ${GIT} commit -m "Pin dependencies in requirements.txt"
fi

${GIT} push origin ${BRANCH} -q

echo "Creating branch for mistralclient..."
cd ${REPO_CLIENT}
${GIT} checkout master
${GIT} pull origin master -q
${GIT} checkout -b ${BRANCH}
${GIT} push origin ${BRANCH} -q

echo "Creating branch for st2mistral..."
cd ${REPO_ACTION}
${GIT} checkout master
${GIT} pull origin master -q
${GIT} checkout -b ${BRANCH}
${GIT} push origin ${BRANCH} -q
