#!/usr/bin/env bash

# Default file name for the stanley private key file
DEFAULT_KEY_FILE_NAME="st2_stanley_key"

PRIVATE_KEY_PATH="/home/stanley/.ssh/${DEFAULT_KEY_FILE_NAME}"
AUTHORIZED_KEYS_PATH="/home/stanley/.ssh/authorized_keys"

# 1. Verify default private key is not installed
if [ -f ${PRIVATE_KEY_PATH} ]; then
    echo "Found default private ssh key (${PRIVATE_KEY_PATH}) for stanley user"
    exit 1
fi

# 2. Verify no other private keys are installed
PRIVATE_KEY_FILES=$(find /home/stanley/.ssh/ -type f ! -name authorized_keys | wc -l)

if [ ${PRIVATE_KEY_FILES} -gt 0 ]; then
    echo "Found private SSH key files for stanley user"
    exit 2
fi

# 3. Verify default publich key is not installed
if [ -f ${AUTHORIZED_KEYS_PATH} ]; then
    AUTHORIZED_KEYS_LINES=$(cat ${AUTHORIZED_KEYS_PATH} | grep ${DEFAULT_KEY_FILE_NAME} | wc -l)

    if [ ${AUTHORIZED_KEYS_LINES} -gt 0 ]; then
        echo "Found default stanley public key in authorized_keys (${AUTHORIZED_KEYS_PATH})"
        exit 3
    fi
fi

exit 0
