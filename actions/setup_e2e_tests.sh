#!/bin/bash
set -e

VERSION=$1
BRANCH=`echo ${VERSION} | cut -d "." -f1-2`

# Install OS specific pre-reqs (Better moved to puppet at some point.)
DEBTEST=`lsb_release -a 2> /dev/null | grep Distributor | awk '{print $3}'`
RHTEST=`cat /etc/redhat-release 2> /dev/null | sed -e "s~\(.*\)release.*~\1~g"`

if [[ -n "$RHTEST" ]]; then
  echo "*** Detected Distro is ${RHTEST} ***"
  sudo yum install -y bc
  sudo yum install -y python-pip wget
elif [[ -n "$DEBTEST" ]]; then
  echo "*** Detected Distro is ${DEBTEST} ***"
  sudo apt-get install -y bc wget
  sudo apt-get -q -y install python-pip python-dev build-essential
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

if [[ ${BRANCH} == "master" ]]; then
    echo "Installing st2tests from '${BRANCH}' branch at location: `pwd`..."
    git clone -b ${BRANCH} --depth 1 https://github.com/StackStorm/st2tests.git
else
   echo "Installing st2tests from 'v${BRANCH}' branch at location: `pwd`"
   git clone -b v${BRANCH} --depth 1 https://github.com/StackStorm/st2tests.git
fi
echo "Installing Packs: tests, asserts, fixtures, webui..."
sudo cp -R st2tests/packs/* /opt/stackstorm/packs/

sudo cp -R /usr/share/doc/st2/examples /opt/stackstorm/packs/
st2 run packs.setup_virtualenv packs=examples,tests,asserts,fixtures,webui
st2ctl reload --register-all

# Robotframework requirements
cd st2tests
sudo pip install --upgrade pip
sudo pip install --upgrade virtualenv
virtualenv venv
. venv/bin/activate
pip install -r robotfm_tests/test-requirements.txt


# Restart st2 primarily reload the keyvalue configuration
sudo st2ctl restart
sleep 5
