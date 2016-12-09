#!/usr/bin/env bash
# To be created:
# st2ci
############################################
# st2_pkg_build_{{version}}_on_pytest.yaml
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

    ST2CI_BRANCH="feat/${LOCAL_REPO}_add_release_rules"
    echo "Cloning ${GIT_REPO} to ${LOCAL_REPO}..."

    if [ -d "${LOCAL_REPO}" ]; then
        rm -rf ${LOCAL_REPO}
    fi

    git clone ${GIT_REPO} ${LOCAL_REPO}

    cd ${LOCAL_REPO}
    echo "Currently at directory `pwd`..."


    git checkout -b ${ST2CI_BRANCH}
    
}

function create_new_rules {
    cat ./rules/st2_pkg_build_${PREV_FILE_POSTFIX_UNDERSCORE}_on_pytest.yaml > ./rules/st2_pkg_build_${FILE_POSTFIX_UNDERSCORE}_on_pytest.yaml
}

function update_new_rules {
    sed -i "s/$PREV_BRANCH/$BRANCH/g" ./rules/st2_pkg_build_${FILE_POSTFIX_UNDERSCORE}_on_pytest.yaml
}

function git_finish {
    git add ./rules
    git commit -m "Adding/Updating rules for $VERSION release"
    git push -u origin ${ST2CI_BRANCH}
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
