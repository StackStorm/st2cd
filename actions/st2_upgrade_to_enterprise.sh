#!/bin/bash
set -e

LICENSE_KEY=$1
DISTRO=$2
RELEASE=$3
PKG_ENV=$4
REPO=enterprise

if [ "${PKG_ENV}" = "staging" ]; then
    REPO="${PKG_ENV}-${REPO}"
fi

if [ "${RELEASE}" = "unstable" ]; then
    REPO="${REPO}-${RELEASE}"
fi

echo "Downloading from repo ${REPO}..."

if [[ ${DISTRO} = \UBUNTU* ]]; then
    curl -s https://${LICENSE_KEY}:@packagecloud.io/install/repositories/StackStorm/${REPO}/script.deb.sh | sudo bash
    sudo apt-get install -y st2flow
    sudo apt-get install -y st2-auth-ldap
else
    curl -s https://${LICENSE_KEY}:@packagecloud.io/install/repositories/StackStorm/${REPO}/script.rpm.sh | sudo bash
    sudo yum install -y st2flow
    sudo yum install -y st2-auth-ldap
fi

sudo st2ctl restart
