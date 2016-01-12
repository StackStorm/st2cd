#!/usr/bin/env bash

PRIVATE_KEY_PATH="/home/stanley/.ssh/st2_stanley_key"
AUTHORIZED_KEYS_PATH="/home/stanley/.ssh/authorized_keys"

# 1. Verify default private key is not installed
if [ -f ${PRIVATE_KEY_PATH} ]; then
    echo "Private SSH key file exists for stanley user"
    exit 1
fi

# 2. Verify no other private key is installed
PRIVATE_KEY_FILES=$(find /home/stanley/.ssh/ -type f ! -name authorized_keys | wc -l)

if [ ${PRIVATE_KEY_FILES} -gt 0 ]; then
    echo "Found private SSH key files for stanley user"
    exit 2
fi

# 3. Verify default publich key is not installed
AUTHORIZED_KEYS_LINES=$(cat /home/stanley/.ssh/authorized_keys | grep st2_stanley_key | wc -l)

if [ ${AUTHORIZED_KEYS_LINES} -gt 0 ]; then
    echo "Found default stanley key in authorized_keys"
    exit 3
fi

exit 0
