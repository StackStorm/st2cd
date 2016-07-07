#!/bin/bash
set -e

LICENSE_KEY=$1
DISTRO=$2
RELEASE=$3
PKG_ENV=$4
LDAP_HOST=$5
LDAP_BIND_DN=$6
LDAP_BIND_PASSWD=$7
LDAP_BASE_OU=$8
LDAP_GROUP_DN=$9
REPO=enterprise

if [ "${PKG_ENV}" = "staging" ]; then
    REPO="${PKG_ENV}-${REPO}"
fi

if [ "${RELEASE}" = "unstable" ]; then
    REPO="${REPO}-${RELEASE}"
fi

# Install enterprise bits
echo "Downloading from repo ${REPO}..."

if [[ ${DISTRO} = \UBUNTU* ]]; then
    curl -s https://${LICENSE_KEY}:@packagecloud.io/install/repositories/StackStorm/${REPO}/script.deb.sh | bash
    apt-get install -y st2flow
    apt-get install -y st2-auth-ldap
else
    curl -s https://${LICENSE_KEY}:@packagecloud.io/install/repositories/StackStorm/${REPO}/script.rpm.sh | sudo bash
    yum install -y st2flow
    yum install -y st2-auth-ldap
fi

# Replace the auth section
echo "Updating st2.conf..."
sed -i -e '/\[system\]/ p' -e '/\[auth\]/,/\[system\]/ d' /etc/st2/st2.conf

cat <<CONF >> /etc/st2/st2.conf

[auth]
host = 0.0.0.0
port = 9100
use_ssl = False
debug = False
enable = True
logging = /etc/st2/logging.auth.conf

mode = standalone

# Note: Settings below are only used in "standalone" mode
backend = ldap
backend_kwargs = {"bind_dn": "${LDAP_BIND_DN}", "bind_password": "${LDAP_BIND_PASSWD}", "base_ou": "${LDAP_BASE_OU}", "group_dns": ["${LDAP_GROUP_DN}"], "id_attr": "samAccountName", "host": "${LDAP_HOST}"}

# Base URL to the API endpoint excluding the version (e.g. http://myhost.net:9101/)
api_url =

CONF

# Restart st2
st2ctl restart
