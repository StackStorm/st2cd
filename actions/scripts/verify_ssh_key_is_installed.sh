#!/usr/bin/env bash

# Script which verfies that the provided public and private
# SSH keys are installed for the provided user

USERNAME=$1
PUBLIC_SSH_KEY=$2
PRIVATE_SSH_KEY=$3

if [ $# -lt 3 ]; then
    echo "Usage: <username> <public key content> <private key content>"
    exit 1
fi

# Default file name for the stanley private key file
DEFAULT_KEY_FILE_NAME="st2_${USERNAME}_key"

AUTHORIZED_KEYS_PATH="/home/${USERNAME}/.ssh/authorized_keys"
PRIVATE_KEY_PATH="/home/${USERNAME}/.ssh/${DEFAULT_KEY_FILE_NAME}"

# 1. Verify authorized_keys file exists
if [ ! -f ${AUTHORIZED_KEYS_PATH} ]; then
    echo "authorized_keys file ${AUTHORIZED_KEYS_PATH} doesn't exist"
    exit 2
fi


# 2. Verify private key file exists
if [ ! -f ${PRIVATE_KEY_PATH} ]; then
    echo "Private key file ${PRIVATE_KEY_PATH} doesn't exist"
    exit 3
fi

# 3. Verify authorized_keys file contains correct public key
AUTHORIZED_KEYS_LINES=$(cat ${AUTHORIZED_KEYS_PATH} | grep ${PUBLIC_SSH_KEY} | wc -l)

if [ ${AUTHORIZED_KEYS_LINES} -lt 1 ]; then
    echo "authorized_keys file (${AUTHORIZED_KEYS_PATH}) doesn't contain public key"
    exit 4
fi

# 4. Verify private key file contains correct private key
PRIVATE_KEYS_LINES=$(cat ${PRIVATE_KEY_PATH} | grep ${PRIVATE_SSH_KEY} | wc -l)

if [ ${PRIVATE_KEYS_LINES} -lt 1 ]; then
    echo "Private key (${PRIVATE_KEY_PATH}) file doesn't contain private key"
    exit 5
fi

echo "All good - public and private keys are present!"
exit 0
