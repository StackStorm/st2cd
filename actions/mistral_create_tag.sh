#!/bin/bash
set -e

VERSION=$1
REPO_MAIN=$2
REPO_CLIENT=$3
REPO_ACTION=$4

GIT=`which git`

BRANCH=st2-${VERSION}
echo "Tagging release for version ${BRANCH}..."

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
    BRANCH_EXISTS=`${GIT} ls-remote --heads | grep refs/heads/${BRANCH}`
    if [[ -z "${BRANCH_EXISTS}" ]]; then
        >&2 echo "ERROR: Branch ${BRANCH} does not exist in ${REPO}."
        exit 1
    fi
done

for REPO in "${REPOS[@]}"
do
    echo "Creating tag in ${REPO}..."
    cd ${REPO}
    ${GIT} tag -a ${BRANCH} -m "Release for st2 v${VERSION}"
    ${GIT} push --tags
done
