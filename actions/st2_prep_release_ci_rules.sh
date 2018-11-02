#!/usr/bin/env bash
# To be created:
# st2ci
############################################
set -e

PROJECT=$1
FORK=$2
VERSION=$3
PREV_VERSION=$4
LOCAL_REPO=$5
GIT_REPO="git@github.com:${FORK}/${PROJECT}.git"
SHORT_VERSION=`echo ${VERSION} | cut -d "." -f1-2`
BRANCH="v${SHORT_VERSION}"
PREV_SHORT_VERSION=`echo ${PREV_VERSION} | cut -d "." -f1-2`
PREV_BRANCH="v${PREV_SHORT_VERSION}"
PREV_FILE_POSTFIX_UNDERSCORE=`echo $PREV_BRANCH | sed 's/\./_/g'`
FILE_POSTFIX_UNDERSCORE=`echo $BRANCH | sed 's/\./_/g'`
CWD=`pwd`


function git_repo {
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
}

function create_new_rules {
    echo "Creating new rules"
}

function update_new_rules {
    echo "Updating new rules"
}

function git_finish {
    git add ./rules
    git commit -m "Adding/Updating rules for $VERSION release" || true
    git push
}

function clean_up {
    # CLEANUP
    cd ${CWD}
    rm -rf ${LOCAL_REPO}
}

function main {
    git_repo
    create_new_rules
    update_new_rules
    git_finish
    clean_up
}

main
