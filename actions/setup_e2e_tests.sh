#!/bin/bash
set -ex

BRANCH="$1"

if [[ -z "$BRANCH" ]]; then
    echo "Abort: Can not setup e2e tests without a branch name."
    exit 2
fi

# Install OS specific prerequisites (TODO: Use a configuration management tool for this such as mgmt-config.)

# Get system release information prefix with OS_ to avoid name conflicts.
source <(sed -r 's/^/OS_/g' /etc/os-release)

if ! grep -q ttlMonitorSleepSecs /etc/mongod.conf; then
    # Decrease interval for MongoDB TTL expire thread. By default it runs every 60 seconds which
    # means we would need to wait at least 60 seconds in our key expire end to end tests.
    # By decreasing it, we can speed up those tests
    # TODO: Use db.adminCommand, but for that we need to fix admin user permissions in bootstrap script
    echo "Updating MongoDB config..."
    echo -e "\nsetParameter:\n  ttlMonitorSleepSecs: 1" | sudo tee -a /etc/mongod.conf > /dev/null
fi
sudo cat /etc/mongod.conf


echo "*** Detected Distro is ${OS_ID} - ${OS_VERSION_ID} ***"
if [[ $OS_ID =~ rocky|redhat|centos ]]; then
    # Restart MongoDB for the config changes above to take an affect
    echo "Restarting MongoDB..."
    sudo systemctl restart mongod

    # Install dnf for consistent package management
    command -v dnf || yum install dnf

    if [[ "$OS_VERSION_ID" =~ ^8"." ]]; then
        # Rocky 8 is installed with py36 by default, so install py38
        # and set it as the default python interpreter.
        sudo dnf install -y python38 python38-pip wget jq
        sudo alternatives --set python3 /usr/bin/python3.8
        sudo alternatives --display python3
    else
        sudo dnf install -y python3-pip wget jq
    fi

    # bats not available in epel for EL 8, Install from npm
    sudo npm install --global bats

elif [[ $OS_ID =~ debian|ubuntu ]]; then
    # Restart MongoDB for the config changes above to take an affect
    echo "Restarting MongoDB..."
    sudo systemctl restart mongod
    PKGS=(
        build-essential
        jq
        python3-pip
        python3-venv
        python3-dev
        wget
    )
    sudo apt-get -q -y install ${PKGS[@]}

    # Remove bats-core if it already exists (this happens when test workflows
    # are re-run on a server when tests are debugged)
    if [[ -d bats-core ]]; then
        rm -rf bats-core
    fi

    # Install from GitHub
    git clone https://github.com/bats-core/bats-core.git
    (cd bats-core; sudo ./install.sh /usr/local)
else
    echo "Aborting: Unsupported Operating System."
    exit 2
fi

# Set python3 variables
PIP="pip3"
PY3BIN="python3"
PY3VER=$(python3 --version | sed -r 's/.*([[0-9]+\.[0-9]+)\.[0-9]+.*/\1/g')


# Setup crypto key file
ST2_CONF="/etc/st2/st2.conf"
CRYPTO_BASE="/etc/st2/keys"
CRYPTO_KEY_FILE="${CRYPTO_BASE}/key.json"

sudo mkdir -p ${CRYPTO_BASE}
if [[ ! -e "${CRYPTO_KEY_FILE}" ]]; then
    sudo st2-generate-symmetric-crypto-key --key-path ${CRYPTO_KEY_FILE}
    sudo chgrp st2packs ${CRYPTO_KEY_FILE}
fi

if ! grep -qE "encryption_key_path[[:space:]]*=[[:space:]]*" ${ST2_CONF}; then
    # Add a new keyvalue.encryption_key_path
    # This looks overly complicated...
    sudo bash -c "cat <<keyvalue_options >>${ST2_CONF}
[keyvalue]
encryption_key_path = ${CRYPTO_KEY_FILE}
keyvalue_options"
elif ! grep -qE "encryption_key_path[[:space:]]*=[[:space:]]*${CRYPTO_KEY_FILE}" ${ST2_CONF}; then
    # If keyvalue.encryption_key_path exists, then modify it
    sudo sed -i "s|^encryption_key_path[[:space:]]*=[[:space:]]*[^[:space:]]\{1,\}$|encryption_key_path = ${CRYPTO_KEY_FILE}|" ${ST2_CONF}
fi

# Reload required for testing st2 upgrade
st2ctl reload --register-all

# Remove the st2tests directory if it exists (this happens when test workflows
# are re-run on a server when tests are debugged)
if [[ -d st2tests ]]; then
    rm -rf st2tests
fi

# Install packs for testing

echo "Installing st2tests from '${BRANCH}' branch at location: $(pwd)..."
# Can use --recurse-submodules with Git 2.13 and later
#~ git clone --recursive -b ${BRANCH} --depth 1 https://github.com/StackStorm/st2tests.git
echo "WARNING: Using nzlosh repo, revert to official StackStorm after testing."
# temporarily use st2v3.9 update branch from nzlosh repo
git clone --recursive -b st2v3.9_updates --depth 1 https://github.com/nzlosh/st2tests.git

echo "Installing Packs: tests, asserts, fixtures, webui..."
sudo cp -R st2tests/packs/* /opt/stackstorm/packs/

echo "Apply st2 CI configuration if it exists..."
if [ -f st2tests/conf/st2.ci.conf ]; then
    # Skip the CI config if it's already applied
    if [[ ! $(grep -qE 'enable_common_libs[[:space:]]*=[[:space:]]*True' /etc/st2/st2.conf) ]]; then
        sudo cp -f /etc/st2/st2.conf /etc/st2/st2.conf.bkup
        sudo crudini --merge  /etc/st2/st2.conf < st2tests/conf/st2.ci.conf
    fi
fi

sudo cp -R /usr/share/doc/st2/examples /opt/stackstorm/packs/
st2 run packs.setup_virtualenv packs=examples,tests,asserts,fixtures,webui,chatops_tests
sudo touch /opt/stackstorm/chatops/.hubot_history
sudo chown stanley:stanley /opt/stackstorm/chatops/.hubot_history
st2ctl reload --register-all

# Robotframework requirements
cd st2tests
PIP_VERSION=$(curl --silent https://raw.githubusercontent.com/StackStorm/st2/${BRANCH}/Makefile | awk '/PIP_VERSION \?= / {print $3 }')

# Fallback to using master branch if it wasn't found in the provided BRANCH.
if [[ -z "$PIP_VERSION" ]]; then
    PIP_VERSION=$(curl --silent https://raw.githubusercontent.com/StackStorm/st2/master/Makefile | awk '/PIP_VERSION \?= / {print $3 }')
fi

sudo ${PIP} install --upgrade "pip==$PIP_VERSION"

rm -rf "$HOME/venv"
${PY3BIN} -m venv "$HOME/venv"
source "$HOME/venv/bin/activate"

${PY3BIN} --version
${PIP} --version
# Update pip in the virtualenv to ensure dependencies can be successfully installed
${PIP} install --upgrade "pip==$PIP_VERSION"

# Install the test dependencies (these are generated in st2tests using pip-compile).
${PIP} install -r test-requirements-${PY3VER}.txt


# Restart st2 primarily reload the keyvalue configuration
sudo st2ctl restart
sleep 5
