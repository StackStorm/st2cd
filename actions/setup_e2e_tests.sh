#!/bin/bash
set -e

# Setup crypto key file
ST2_CONF="/etc/st2/st2.conf"
CRYPTO_BASE="/etc/st2/keys"
CRYPTO_KEY_FILE="${CRYPTO_BASE}/key.json"

sudo mkdir -p ${CRYPTO_BASE}
sudo st2-generate-symmetric-crypto-key --key-path ${CRYPTO_KEY_FILE}
sudo chgrp st2packs ${CRYPTO_KEY_FILE}

cat <<keyvalue_options >>${ST2_CONF}
[keyvalue]
encryption_key_path=${CRYPTO_KEY_FILE}
keyvalue_options

st2 run packs.install subtree=true repo_url=StackStorm/st2tests packs=tests,asserts,fixtures,webui
sudo cp -R /usr/share/doc/st2/examples /opt/stackstorm/packs/
st2 run packs.setup_virtualenv packs=examples
st2ctl reload
git clone https://github.com/StackStorm/st2tests.git
cd st2tests
virtualenv venv
. venv/bin/activate
pip install -r robotfm_tests/test-requirements.txt

# Restart st2 primarily reload the keyvalue configuration
st2ctl restart
sleep 5
