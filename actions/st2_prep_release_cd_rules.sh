#!/usr/bin/env bash
# To be created:
# st2cd
############################################
# bwc_docs_ipfabric_prod_{{version}}.yaml
# st2_docs_{{version}}.yaml
# bwc_docs_prod_{{version}}.yaml
# st2_pkg_test_stable_{{os}}.yaml
# st2_pkg_test_stable_{{os}}_enterprise.yaml
set -e

PROJECT=$1
FORK=$2
VERSION=$3
PREV_VERSION=$4
OSES=$5
LOCAL_REPO=$6
GIT_REPO="git@github.com:${FORK}/${PROJECT}.git"
SHORT_VERSION=`echo ${VERSION} | cut -d "." -f1-2`
BRANCH="v${SHORT_VERSION}"
PREV_SHORT_VERSION=`echo ${PREV_VERSION} | cut -d "." -f1-2`
PREV_BRANCH="v${PREV_SHORT_VERSION}"
PREV_FILE_POSTFIX=`echo $PREV_BRANCH | sed 's/\.//g'`
FILE_POSTFIX=`echo $BRANCH | sed 's/\.//g'`
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
    # Ignoring "file already exists" error (this will happen for patch releases, since minor release created this file already)
    cat ./rules/bwc_docs_ipfabric_prod_$PREV_FILE_POSTFIX_UNDERSCORE.yaml > ./rules/bwc_docs_ipfabric_prod_$FILE_POSTFIX_UNDERSCORE.yaml || true
    cat ./rules/st2_docs_$PREV_FILE_POSTFIX.yaml > ./rules/st2_docs_$FILE_POSTFIX.yaml || true
    cat ./rules/bwc_docs_prod_$PREV_FILE_POSTFIX_UNDERSCORE.yaml > ./rules/bwc_docs_prod_$FILE_POSTFIX_UNDERSCORE.yaml  || true
}

function update_new_rules {
    sed -i "s/$PREV_FILE_POSTFIX_UNDERSCORE/$FILE_POSTFIX_UNDERSCORE/g" ./rules/bwc_docs_ipfabric_prod_$FILE_POSTFIX_UNDERSCORE.yaml
    sed -i "s/$PREV_FILE_POSTFIX_UNDERSCORE/$FILE_POSTFIX_UNDERSCORE/g" ./rules/st2_docs_$FILE_POSTFIX.yaml
    sed -i "s/$PREV_FILE_POSTFIX_UNDERSCORE/$FILE_POSTFIX_UNDERSCORE/g" ./rules/bwc_docs_prod_$FILE_POSTFIX_UNDERSCORE.yaml

    sed -i "s/$PREV_BRANCH/$BRANCH/g" ./rules/bwc_docs_ipfabric_prod_$FILE_POSTFIX_UNDERSCORE.yaml
    sed -i "s/$PREV_BRANCH/$BRANCH/g" ./rules/st2_docs_$FILE_POSTFIX.yaml
    sed -i "s/$PREV_BRANCH/$BRANCH/g" ./rules/bwc_docs_prod_$FILE_POSTFIX_UNDERSCORE.yaml
}

function update_existing_rules {
    for os in $OSES; do
        sed -i "s/${PREV_VERSION}/${VERSION}/g" ./rules/st2_pkg_test_stable_${os}.yaml
        sed -i "s/${PREV_VERSION}/${VERSION}/g" ./rules/st2_pkg_test_stable_${os}_enterprise.yaml
    done
}

function git_finish {
    git add ./rules
    git commit -m "Adding/Updating rules for $VERSION release"
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
    update_existing_rules
    git_finish
    clean_up
}

main
