#!/bin/bash
set -e

GIT=`which git`
REPO=$1
VERSION=$2
BRANCH=$3

MISTRAL_VERSION=st2-${VERSION}
MISTRALCLIENT_REPO=https://github.com/StackStorm/python-mistralclient.git

# Check if the branch exists in the python-mistralclient repo.
MISTRAL_BRANCH_EXISTS=`${GIT} ls-remote --heads ${MISTRALCLIENT_REPO} | grep refs/heads/${MISTRAL_VERSION} || true`

if [[ -z "${MISTRAL_BRANCH_EXISTS}" ]]; then
    >&2 echo "ERROR: Branch ${MISTRAL_VERSION} does not exist in ${MISTRALCLIENT_REPO}."
    exit 1
fi

# Replace the python-mistralclient version number in st2.
OLD_REQUIREMENT=git+${MISTRALCLIENT_REPO}#egg=python-mistralclient
NEW_REQUIREMENT=git+${MISTRALCLIENT_REPO}@${MISTRAL_VERSION}#egg=python-mistralclient

ST2_ACTION_IN_REQ_FILE=${REPO}/st2actions/in-requirements.txt
sed -i 's/${OLD_REQUIREMENT}/${NEW_REQUIREMENT}/' ${ST2_ACTION_IN_REQ_FILE}

ST2_ACTION_IN_REQ_CHANGED=`cat ${ST2_ACTION_IN_REQ_FILE} | grep ${NEW_REQUIREMENT} || true`
if [[ -z "${ST2_ACTION_IN_REQ_CHANGED}" ]]; then
    >&2 echo "ERROR: Unable to update the mistralclient version in ${ST2_ACTION_IN_REQ_FILE}."
    exit 1
fi

ST2_REQ_FILE=${REPO}/requirements.txt
sed -i 's/${OLD_REQUIREMENT}/${NEW_REQUIREMENT}/' ${ST2_REQ_FILE}

ST2_REQ_CHANGED=`cat ${ST2_REQ_FILE} | grep ${NEW_REQUIREMENT} || true`
if [[ -z "${ST2_REQ_CHANGED}" ]]; then
    >&2 echo "ERROR: Unable to update the mistralclient version in ${ST2_REQ_FILE}."
    exit 1
fi
