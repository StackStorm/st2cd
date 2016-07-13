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
VERSION=${10}  # Should be of the form ${major}.${minor}.${patch}
REPO=enterprise

if [ "${PKG_ENV}" = "staging" ]; then
    REPO="${PKG_ENV}-${REPO}"
fi

if [ "${RELEASE}" = "unstable" ]; then
    REPO="${REPO}-${RELEASE}"
fi

get_apt_pkg_latest_revision() {
    # Returns string of form 1.5.1-5. Note how this is different from rpm :/
    local PKG_NAME=$1
    local PKG_VERSION=$2

    apt-cache show $PKG_NAME | grep Version | awk '{print $2}' | grep $PKG_VERSION | sort --version-sort | tail -n 1
}

get_rpm_pkg_name_with_latest_revision() {
    # Returns string of form st2-0:1.5.1-3.x86_64
    local PKG_NAME=$1
    local PKG_VERSION=$2

    yum install -y yum-utils # need repoquery
    repoquery --show-duplicates $PKG_NAME-$PKG_VERSION* | sort --version-sort | tail -n 1
}

install_enterprise_bits() {
    # Install enterprise bits from packagecloud
    echo "Downloading from repo ${REPO}..."

    if [[ ${DISTRO} = \UBUNTU* ]]; then
        curl -s https://${LICENSE_KEY}:@packagecloud.io/install/repositories/StackStorm/${REPO}/script.deb.sh | bash
        if [[ -z $VERSION ]]; then
            apt-get install -y st2flow
            apt-get install -y st2-auth-ldap
        else
            local FLOW_PKG_VERSION=$(get_apt_pkg_latest_revision st2flow $VERSION)
            local LDAP_PKG_VERSION=$(get_apt_pkg_latest_revision st2-auth-ldap $VERSION)
            apt-get install -y st2flow=$FLOW_PKG_VERSION
            apt-get install -y st2-auth-ldap=$LDAP_PKG_VERSION
        fi
    else
        curl -s https://${LICENSE_KEY}:@packagecloud.io/install/repositories/StackStorm/${REPO}/script.rpm.sh | sudo bash
        if [[ -z $VERSION ]]; then
            yum install -y st2flow
            yum install -y st2-auth-ldap
        else
            local FLOW_PKG=$(get_rpm_pkg_name_with_latest_revision st2flow $VERSION)
            local LDAP_PKG=$(get_rpm_pkg_name_with_latest_revision st2-auth-ldap $VERSION)
            yum install -y $FLOW_PKG
            yum install -y $LDAP_PKG
        fi
    fi
}

update_st2_conf() {
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
}

restart_st2() {
    st2ctl restart
}

install_enterprise_bits
update_st2_conf
restart_st2
