#!/bin/bash

WORKROOM_DIR=${1}
PUPPET_ST2_BRANCH_TO_TEST=${2}

if [ -z "$WORKROOM_DIR" ]; then
    echo "Workroom dir not present"
    exit 1
fi

PUPPETFILE = ${WORKROOM_DIR}/Puppetfile
if [ -z "$PUPPETFILE" ]; then
    echo "$PUPPERFILE not found."
    exit 2
fi

sed -i "/mod 'stackstorm-st2'/d" $PUPPETFILE
if [[ $? != 0 ]]; then
    echo "Failed deleting stackstorm-st2 from Puppetfile."
    exit 3
fi

read -r -d '' PUPPET_ST2_REF << EOM
mod 'stackstorm-st2',
  :git => 'https://github.com/StackStorm/puppet-st2',
  :ref => "$PUPPET_ST2_BRANCH_TO_TEST"
EOM

echo $PUPPET_ST2_REF >> $Puppetfile
if [[ $? != 0 ]]; then
    echo "Failed setting puppet-st2 ref to $PUPPET_ST2_REF in $PUPPETFILE"
    exit 4
fi
