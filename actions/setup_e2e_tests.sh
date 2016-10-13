#!/bin/bash
set -e

VERSION=$1

# Install OS specific pre-reqs (Better moved to puppet at some point.)
DEBTEST=`lsb_release -a 2> /dev/null | grep Distributor | awk '{print $3}'`
RHTEST=`cat /etc/redhat-release 2> /dev/null | sed -e "s~\(.*\)release.*~\1~g"`

if [[ -n "$RHTEST" ]]; then
  echo "*** Detected Distro is ${RHTEST} ***"
  sudo yum install -y bc
elif [[ -n "$DEBTEST" ]]; then
  echo "*** Detected Distro is ${DEBTEST} ***"
  sudo apt-get install -y bc
else
  echo "Unknown Operating System."
  exit 2
fi

# Setup crypto key file
ST2_CONF="/etc/st2/st2.conf"
CRYPTO_BASE="/etc/st2/keys"
CRYPTO_KEY_FILE="${CRYPTO_BASE}/key.json"

sudo mkdir -p ${CRYPTO_BASE}
sudo st2-generate-symmetric-crypto-key --key-path ${CRYPTO_KEY_FILE}
sudo chgrp st2packs ${CRYPTO_KEY_FILE}

sudo bash -c "cat <<keyvalue_options >>${ST2_CONF}
[keyvalue]
encryption_key_path=${CRYPTO_KEY_FILE}
keyvalue_options"

if [[ ${VERSION} == "master" ]]; then
    echo "Installing st2tests from '${VERSION}' branch at location: `pwd`..."
    git clone -b ${VERSION} --depth 1 https://github.com/StackStorm/st2tests.git
    echo "Installing Packs: tests, asserts, fixtures, webui..."
    st2 run packs.install subtree=true branch=${VERSION} repo_url=StackStorm/st2tests packs=tests,asserts,fixtures,webui
else
   echo "Installing st2tests from 'v${VERSION}' branch at location: `pwd`"
   git clone -b v${VERSION} --depth 1 https://github.com/StackStorm/st2tests.git
    echo "Installing Packs: tests, asserts, fixtures, webui..."
   st2 run packs.install subtree=true branch=v${VERSION} repo_url=StackStorm/st2tests packs=tests,asserts,fixtures,webui
fi

sudo cp -R /usr/share/doc/st2/examples /opt/stackstorm/packs/
st2 run packs.setup_virtualenv packs=examples
st2ctl reload

# Robotframework requirements
cd st2tests
virtualenv venv
. venv/bin/activate
pip install -r robotfm_tests/test-requirements.txt

# Restart st2 primarily reload the keyvalue configuration
sudo st2ctl restart
sleep 5
