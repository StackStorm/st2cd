#!/bin/bash
set -e

BRANCH=$1

VERSION=
# Try to convert the branch to a major.minor version number
# master              ->  master
# 0.1.0               ->  0.1
# v0.1.0              ->  v0.1
# testing             -> testing
# something/python.py -> something/python.py
if [[ $BRANCH =~ v?[[:digit:]]{1,}\.[[:digit:]]{1,} ]]; then
    VERSION=$(echo ${BRANCH} | cut -d "." -f1-2 | sed 's/^v//')
fi

PIP="pip"

# Install OS specific pre-reqs (Better moved to puppet at some point.)
DEBTEST=`lsb_release -a 2> /dev/null | grep Distributor | awk '{print $3}'`
RHTEST=`cat /etc/redhat-release 2> /dev/null | sed -e "s~\(.*\)release.*~\1~g"`

# Decrease interval for MongoDB TTL expire thread. By default it runs every 60 seconds which
# means we would need to wait at least 60 seconds in our key expire end to end tests.
# By decreasing it, we can speed up those tests
# TODO: Use db.adminCommand, but for that we need to fix admin user permissions in bootstrap script
echo "Updating MongoDB config..."
echo -e "\nsetParameter:\n  ttlMonitorSleepSecs: 1" | sudo tee -a /etc/mongod.conf > /dev/null
sudo cat /etc/mongod.conf

if [[ -n "$RHTEST" ]]; then
    RHVERSION=`cat /etc/redhat-release 2> /dev/null | sed -r 's/([^0-9]*([0-9]*)){1}.*/\2/'`
    echo "*** Detected Distro is ${RHTEST} - ${RHVERSION} ***"

    echo "Restarting MongoDB..."
    if [[ "$RHVERSION" -ge 7 ]]; then
        # Restart MongoDB for the config changes above to take an affect
        sudo systemctl restart mongod
    else
        # Restart MongoDB for the config changes above to take an affect
        sudo service mongod restart
    fi

    if [[ "$RHVERSION" -eq 7 ]]; then
        # For RHEL/CentOS 7
        sudo yum install -y python-pip jq
    else
        # For RHEL/CentOS 8 and above
        sudo yum install -y python3-pip wget jq
        PIP="pip3"
    fi

    # Remove bats-core if it already exists (this happens when test workflows
    # are re-run on a server when tests are debugged)
    if [[ -d bats-core ]]; then
        rm -rf bats-core
    fi

elif [[ -n "$DEBTEST" ]]; then
    DEBVERSION=`lsb_release --release | awk '{ print $2 }'`
    SUBTYPE=`lsb_release -a 2>&1 | grep Codename | grep -v "LSB" | awk '{print $2}'`
    echo "*** Detected Distro is ${DEBTEST} - ${DEBVERSION} ***"

    echo "Restarting MongoDB..."
    # Restart MongoDB for the config changes above to take an affect
    if [[ "$SUBTYPE" == 'xenial' || "${SUBTYPE}" == "bionic" ]]; then
      sudo systemctl restart mongod
    fi

    sudo apt-get -q -y install build-essential jq python-pip python-dev wget

    # Remove bats-core if it already exists (this happens when test workflows
    # are re-run on a server when tests are debugged)
    if [[ -d bats-core ]]; then
        rm -rf bats-core
    fi

    # Install from GitHub
    git clone https://github.com/bats-core/bats-core.git
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
# If we didn't recognize a version string, treat it like a branch
if [[ -z "$VERSION" ]]; then
    echo "Installing st2tests from '${BRANCH}' branch at location: $(pwd)..."
    # Can use --recurse-submodules with Git 2.13 and later
    git clone --recursive -b ${BRANCH} --depth 1 https://github.com/StackStorm/st2tests.git
else
    echo "Installing st2tests from 'v${VERSION}' branch at location: $(pwd)"
    # Can use --recurse-submodules with Git 2.13 and later
    # Treat $VERSION like a version string and prepend 'v'
    git clone --recursive -b v${VERSION} --depth 1 https://github.com/StackStorm/st2tests.git
fi
echo "Installing Packs: tests, asserts, fixtures, webui..."
sudo cp -R st2tests/packs/* /opt/stackstorm/packs/

echo "Apply st2 CI configuration if it exists..."
if [ -f st2tests/conf/st2.ci.conf ]; then
    sudo cp -f /etc/st2/st2.conf /etc/st2/st2.conf.bkup
    sudo crudini --merge  /etc/st2/st2.conf < st2tests/conf/st2.ci.conf
fi

sudo cp -R /usr/share/doc/st2/examples /opt/stackstorm/packs/
st2 run packs.setup_virtualenv packs=examples,tests,asserts,fixtures,webui,chatops_tests
st2ctl reload --register-all

# Robotframework requirements
cd st2tests
sudo ${PIP} install --upgrade "pip>=9.0,<9.1"
sudo ${PIP} install --upgrade "virtualenv==15.1.0"

virtualenv --no-download venv
. venv/bin/activate
${PIP} install -r test-requirements.txt


# Restart st2 primarily reload the keyvalue configuration
sudo st2ctl restart
sleep 5
