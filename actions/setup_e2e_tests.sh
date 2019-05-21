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
    if [[ "$RHVERSION" -ge 7 ]]; then
        sudo yum install -y jq

    else
        # For RHEL/CentOS 6
        sudo yum install -y epel-release
        sudo yum install -y jq
    fi
    # Remove bats-core if it already exists (this happens when test workflows
    # are re-run on a server when tests are debugged)
    if [[ -d bats-core ]]; then
        rm -rf bats-core
    fi
    # Install from GitHub
    # RHEL 7+ has both bats and jq package, so we don't need to do this once we
    # drop RHEL 6 support
    git clone --branch add_per_test_timing_information --depth 1 https://github.com/Kami/bats-core.git
    (cd bats-core; sudo ./install.sh /usr/local)
elif [[ -n "$DEBTEST" ]]; then
    DEBVERSION=`lsb_release --release | awk '{ print $2 }'`
    echo "*** Detected Distro is ${DEBTEST} - ${DEBVERSION} ***"
    sudo apt-get -q -y install build-essential jq python-pip python-dev wget
    # Remove bats-core if it already exists (this happens when test workflows
    # are re-run on a server when tests are debugged)
    if [[ -d bats-core ]]; then
        rm -rf bats-core
    fi
    # Install from GitHub
    # Ubuntu 16.04 has both bats and jq packages, so we don't need to do this
    # once we drop Ubuntu 14.04 support
    git clone --branch add_per_test_timing_information --depth 1 https://github.com/Kami/bats-core.git
    (cd bats-core; sudo ./install.sh /usr/local)
else
    echo "Unknown Operating System."
    exit 2
fi

# Setup crypto key file
ST2_CONF="/etc/st2/st2.conf"
CRYPTO_BASE="/etc/st2/keys"
CRYPTO_KEY_FILE="${CRYPTO_BASE}/key.json"

sudo mkdir -p ${CRYPTO_BASE}
if [[ ! -e "${CRYPTO_KEY_FILE}" ]]; then
    sudo st2-generate-symmetric-crypto-key --key-path ${CRYPTO_KEY_FILE}
    sudo chgrp st2packs ${CRYPTO_KEY_FILE}
fi

# This looks overly complicated...
sudo bash -c "cat <<keyvalue_options >>${ST2_CONF}
[keyvalue]
encryption_key_path=${CRYPTO_KEY_FILE}
keyvalue_options"

# Reload required for testing st2 upgrade
st2ctl reload --register-all

# Remove the st2tests directory if it exists (this happens when test workflows
# are re-run on a server when tests are debugged)
if [[ -d st2tests ]]; then
    rm -rf st2tests
fi

# Install packs for testing
if [[ ${BRANCH} == "master" ]]; then
    echo "Installing st2tests from '${BRANCH}' branch at location: `pwd`..."
    # Can use --recurse-submodules with Git 2.13 and later
    git clone --recursive -b ${BRANCH} --depth 1 https://github.com/StackStorm/st2tests.git
else
    echo "Installing st2tests from 'v${BRANCH}' branch at location: `pwd`"
    # Can use --recurse-submodules with Git 2.13 and later
    git clone --recursive -b v${BRANCH} --depth 1 https://github.com/StackStorm/st2tests.git
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
pip install -r test-requirements.txt


# Restart st2 primarily reload the keyvalue configuration
sudo st2ctl restart
sleep 5
