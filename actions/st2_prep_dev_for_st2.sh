#!/bin/bash
set -e

PROJECT=$1
VERSION=$2
FORK=$3
LOCAL_REPO=$4
GIT_REPO="git@github.com:${FORK}/${PROJECT}.git"
SHORT_VERSION=`echo ${VERSION} | cut -d "." -f1-2`
DEV_VERSION="${SHORT_VERSION}dev"
BRANCH="master"
CWD=`pwd`


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

git clone ${GIT_REPO} ${LOCAL_REPO}

cd ${LOCAL_REPO}
echo "Currently at directory `pwd`..."


# SET DEV ST2 VERSION INFO
files=(
    "st2common/st2common/__init__.py"
    "st2client/st2client/__init__.py"
)

for f in "${files[@]}"
do
    if [[ ! -e "$f" ]]; then
        >&2 echo "ERROR: Version file ${f} does not exist."
        exit 1
    fi

    echo "Setting version in ${f} to ${DEV_VERSION}..."
    sed -i -e "s/\(__version__ = \).*/\1'${DEV_VERSION}'/" ${f}

    VERSION_INFO="__version__ = '${DEV_VERSION}'"
    grep "${VERSION_INFO}" ${f}
    if [[ $? -ne 0 ]]; then
        >&2 echo "ERROR: Unable to update the st2 version in ${f}."
        exit 1
    fi

    git add ${f}
done

git commit -qm "Update version info for development - ${DEV_VERSION}"


# PUSH NEW BRANCH WITH COMMITS
git push origin ${BRANCH} -q


# CLEANUP
cd ${CWD}
rm -rf ${LOCAL_REPO}
