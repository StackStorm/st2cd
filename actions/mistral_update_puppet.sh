#!/bin/bash
set -e

VERSION=$1
REPO_PUPPET=$2
REPO_PUPPET_BRANCH=$3

GIT=`which git`

MISTRAL_BRANCH=st2-${VERSION}
echo "Updating puppet manifest for mistral to version ${MISTRAL_BRANCH}..."

REGEX="^([0-9])+.([0-9])+.([0-9])+$"

if ! [[ ${VERSION} =~ ${REGEX} ]]; then
    >&2 echo "ERROR: Invalid version format."
    exit 1
fi

echo "Checkout branch..."
if [[ ! -d "${REPO_PUPPET}" ]]; then
    >&2 echo "ERROR: ${REPO_PUPPET} does not exist."
    exit 1
fi

cd ${REPO_PUPPET}
REMOTE_BRANCH_EXISTS=`${GIT} ls-remote --heads | grep refs/heads/${REPO_PUPPET_BRANCH}`
if [[ -z "${REMOTE_BRANCH_EXISTS}" ]]; then
    >&2 echo "ERROR: Remote branch ${REPO_PUPPET_BRANCH} does not exist in ${REPO_PUPPET}."
    exit 1
fi

LOCAL_BRANCH_EXISTS=`${GIT} branch | grep ${REPO_PUPPET_BRANCH}`
if [[ -z "${LOCAL_BRANCH_EXISTS}" ]]; then
    ${GIT} checkout -b ${REPO_PUPPET_BRANCH}
fi

echo "Updating puppet manifest..."
sed -i "s/st2-\([0-9.]*\)/${MISTRAL_BRANCH}/" ${REPO_PUPPET}/manifests/init.pp
VERSION_UPDATED=`cat ${REPO_PUPPET}/manifests/init.pp | grep ${MISTRAL_BRANCH} || true` 
if [ -z "${VERSION_UPDATED}" ]; then
    >&2 echo "ERROR: Unable to update puppet manifest for mistral to version ${MISTRAL_BRANCH}."
    exit 1
fi

echo "Committing change..."
${GIT} add -A
${GIT} commit -m "Update version of mistral_git_branch"
${GIT} push origin ${REPO_PUPPET_BRANCH}
