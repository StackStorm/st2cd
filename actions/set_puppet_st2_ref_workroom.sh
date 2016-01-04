#!/bin/bash

WORKROOM_DIR=${1}
WORKROOM_TARGET_BRANCH=${2}
PUPPET_ST2_BRANCH_TO_TEST=${3}

if [ -z "$WORKROOM_DIR" ]; then
    echo "Workroom dir not present"
    exit 1
fi

PUPPETFILE='Puppetfile'
PUPPETFILE_PATH=$WORKROOM_DIR/$PUPPETFILE

if [ ! -f "$PUPPETFILE_PATH" ]; then
    echo "File $PUPPETFILE_PATH not found."
    exit 2
fi

cd "$WORKROOM_DIR"
# If branch already exists, let's abort for now.
git branch -a | grep remotes/origin/$WORKROOM_TARGET_BRANCH
if [[ $? == 0 ]]; then
    echo "Branch $WORKROOM_TARGET_BRANCH already exists. Aborting."
    exit 3
fi

git checkout -b $WORKROOM_TARGET_BRANCH

sed -i "/mod 'stackstorm-st2'/d" $PUPPETFILE
if [[ $? != 0 ]]; then
    echo "Failed deleting stackstorm-st2 from Puppetfile."
    exit 4
fi

read -r -d '' PUPPET_ST2_REF << EOM
mod 'stackstorm-st2',
  :git => 'https://github.com/StackStorm/puppet-st2',
  :ref => "$PUPPET_ST2_BRANCH_TO_TEST"
EOM

echo $PUPPET_ST2_REF >> $PUPPETFILE_PATH
if [[ $? != 0 ]]; then
    echo "Failed setting puppet-st2 ref to $PUPPET_ST2_REF in $PUPPETFILE_PATH"
    exit 5
fi
