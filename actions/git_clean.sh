#!/bin/bash

REPO=$1
REPO_DIR=$2
ALT_REPO=$REPO_DIR/$REPO

if [[ ! -d $REPO ]]; then
    echo "$REPO does not exist. Trying $ALT_REPO."

    if [[ ! -d $ALT_REPO ]]; then
        echo "$ALT_REPO does not exist."
        exit 0
    else
        REPO=$ALT_REPO
    fi
fi

echo "Removing $REPO..."
rm -Rf $REPO

if [[ -d $REPO ]]; then
    echo "Unable to remove $REPO."
    exit 1
else
    echo "$REPO deleted."
fi
