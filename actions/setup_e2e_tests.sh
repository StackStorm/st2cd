#!/bin/bash
set -e

VERSION=$1
BRANCH=`echo ${VERSION} | cut -d "." -f1-2`

# Install OS specific pre-reqs (Better moved to puppet at some point.)
DEBTEST=`lsb_release -a 2> /dev/null | grep Distributor | awk '{print $3}'`
RHTEST=`cat /etc/redhat-release 2> /dev/null | sed -e "s~\(.*\)release.*~\1~g"`

if [[ -n "$RHTEST" ]]; then
    RHVERSION=`cat /etc/redhat-release 2> /dev/null | sed -r 's/([^0-9]*([0-9]*)){1}.*/\2/'`
    echo "*** Detected Distro is ${RHTEST} - ${RHVERSION} ***"
    sudo yum install -y python-pip wget
elif [[ -n "$DEBTEST" ]]; then
    echo "*** Detected Distro is ${DEBTEST} ***"
    sudo apt-get install -y wget
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

# Reload required for testing st2 upgrade
st2ctl reload --register-all

# Install packs for testing
if [[ ${BRANCH} == "master" ]]; then
    echo "Installing st2tests from '${BRANCH}' branch at location: `pwd`..."
    git clone -b ${BRANCH} --depth 1 https://github.com/StackStorm/st2tests.git
else
   echo "Installing st2tests from 'v${BRANCH}' branch at location: `pwd`"
   git clone -b v${BRANCH} --depth 1 https://github.com/StackStorm/st2tests.git
fi
echo "Installing Packs: tests, asserts, fixtures, webui..."
sudo cp -R st2tests/packs/* /opt/stackstorm/packs/

echo "Apply st2 CI configuration if it exists..."
if [ -f st2tests/conf/st2.ci.conf ]; then
    sudo cp -f /etc/st2/st2.conf /etc/st2/st2.conf.bkup
    sudo crudini --merge  /etc/st2/st2.conf < st2tests/conf/st2.ci.conf
fi

sudo cp -R /usr/share/doc/st2/examples /opt/stackstorm/packs/
st2 run packs.setup_virtualenv packs=examples,tests,asserts,fixtures,webui
st2ctl reload --register-all

# Robotframework requirements
cd st2tests
sudo pip install --upgrade "pip>=9.0,<9.1"
sudo pip install --upgrade "virtualenv==15.1.0"

# wheel==0.30.0 doesn't support python 2.6 (default on el6)
if [[ "$RHVERSION" == 6 ]]; then
    virtualenv --no-download venv -p /opt/stackstorm/st2/bin/python2.7
else
    virtualenv --no-download venv
fi
. venv/bin/activate
pip install -r robotfm_tests/test-requirements.txt


# Restart st2 primarily reload the keyvalue configuration
sudo st2ctl restart
sleep 5
