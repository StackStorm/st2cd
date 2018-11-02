#!/bin/bash
set -e

PROJECT=$1
BRANCH=$2
FORK=$3
LOCAL_REPO=$4
DOCS_URL=$5
DEFAULT_DOCS_URL="docs.stackstorm.com"
GIT_REPO="git@github.com:${FORK}/${PROJECT}.git"
CWD=`pwd`


# CHECK IF BRANCH EXISTS
BRANCH_EXISTS=`git ls-remote --heads ${GIT_REPO} | grep refs/heads/${BRANCH} || true`

if [[ -z "${BRANCH_EXISTS}" ]]; then
    >&2 echo "ERROR: Branch ${BRANCH} doesn't exist in ${GIT_REPO}."
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

# Make sure latest version of virtualenv is installed
sudo pip install --upgrade "virtualenv==15.1.0"

git clone ${GIT_REPO} ${LOCAL_REPO}

cd ${LOCAL_REPO}
echo "Currently at directory `pwd`..."


# UPDATE DOCS URL
CONF_FILE="docs/source/info.py"
DOCS_URL_MATCH=`grep "${DOCS_URL}" ${CONF_FILE} || true`
if [[ -z "${DOCS_URL_MATCH}" ]]; then
    sed -i -e "s/${DEFAULT_DOCS_URL}/${DOCS_URL}/g" ${CONF_FILE}
fi

DOCS_URL_MATCH=`grep "${DOCS_URL}" ${CONF_FILE} || true`
if [[ -z "${DOCS_URL_MATCH}" ]]; then
    >&2 echo "ERROR: Unable to update the docs url in ${CONF_FILE}."
    exit 1
fi


# CHECKOUT BRANCH
if [ "${BRANCH}" != "master" ]; then
    echo "Checking out branch ${BRANCH}..."
    git checkout -b ${BRANCH} origin/${BRANCH}
fi


# MAKE DOCS
make docs


# UPLOAD TO DOCS SITE
VERSION=`cat version.txt`
LOCAL_DOCS_DIR="docs/build/html"
cd ${LOCAL_DOCS_DIR}

if [ "${BRANCH}" = "master" ]; then
    DOCS_PATHS=("/${VERSION}/" "/latest/")
else
    DOCS_PATHS=("/${VERSION}/" "/")
fi

for DOCS_PATH in "${DOCS_PATHS[@]}"
do
    S3_URL="s3://${DOCS_URL}${DOCS_PATH}"
    echo "Uploading docs to ${S3_URL}..."
    s3cmd put --no-mime-magic --guess-mime-type --recursive * ${S3_URL}
done


# CLEANUP
cd ${CWD}
rm -rf ${LOCAL_REPO}
