#!/bin/bash
set -e

LICENSE_KEY=$1
DISTRO=$2
RELEASE=$3
PKG_ENV=$4
VERSION=$5  # Should be of the form ${major}.${minor}.${patch}
LDAP_HOST=$6
LDAP_BIND_DN=$7
LDAP_BIND_PASSWD=$8
LDAP_BASE_OU=$9
LDAP_GROUP_DN=${10}
ST2_USERNAME=st2admin
REPO=enterprise

if [ $VERSION = "None" ]; then
    VERSION=''
fi

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

    repoquery --quiet --show-duplicates $PKG_NAME-$PKG_VERSION* 2>/dev/null | sort --version-sort | tail -n 1
}

install_enterprise_bits() {
    # Install enterprise bits from packagecloud
    echo "Downloading from repo ${REPO}..."
    echo "Version: $VERSION"

    if [[ ${DISTRO} = \UBUNTU* ]]; then
        curl -s https://${LICENSE_KEY}:@packagecloud.io/install/repositories/StackStorm/${REPO}/script.deb.sh | bash
        if [[ -z $VERSION ]]; then
            apt-get install -y bwc-enterprise
        else
            local BWC_ENTERPRISE_PKG_VERSION=$(get_apt_pkg_latest_revision bwc-enterprise $VERSION)
            local ST2FLOW_PKG_VERSION=$(get_apt_pkg_latest_revision st2flow $VERSION)
            local ST2LDAP_PKG_VERSION=$(get_apt_pkg_latest_revision st2-auth-ldap $VERSION)
            local BWCUI_PKG_VERSION=$(get_apt_pkg_latest_revision bwc-ui $VERSION)
            echo "##########################################################"
            echo "#### Following versions of packages will be installed ####"
            echo "bwc-enterprise${BWC_ENTERPRISE_PKG_VERSION}"
            echo "st2flow${ST2FLOW_PKG_VERSION}"
            echo "st2-auth-ldap${ST2LDAP_PKG_VERSION}"
            echo "bwc-ui${BWCUI_PKG_VERSION}"
            echo "##########################################################"
            apt-get install -y bwc-enterprise${BWC_ENTERPRISE_PKG_VERSION} st2flow${ST2FLOW_PKG_VERSION} st2-auth-ldap${ST2LDAP_PKG_VERSION} bwc-ui${BWCUI_PKG_VERSION}
        fi
    else
        curl -s https://${LICENSE_KEY}:@packagecloud.io/install/repositories/StackStorm/${REPO}/script.rpm.sh | sudo bash
        if [[ -z $VERSION ]]; then
            yum install -y bwc-enterprise
        else
            yum install -y yum-utils # need repoquery
            local BWC_PKG=$(get_rpm_pkg_name_with_latest_revision bwc-enterprise $VERSION)
            local ST2FLOW_PKG=$(get_rpm_pkg_name_with_latest_revision st2flow $VERSION)
            local ST2LDAP_PKG=$(get_rpm_pkg_name_with_latest_revision st2-auth-ldap $VERSION)
            local BWCUI_PKG=$(get_rpm_pkg_name_with_latest_revision bwc-ui $VERSION)
            local BWC_ENTERPRISE_PKG="${BWC_PKG} ${ST2FLOW_PKG} ${ST2LDAP_PKG} ${BWCUI_PKG}"
            echo "##########################################################"
            echo "#### Following versions of packages will be installed ####"
            echo "${BWC_ENTERPRISE_PKG}"
            echo "##########################################################"
            yum install -y $BWC_ENTERPRISE_PKG
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

enable_and_configure_rbac() {
  if [[ ${DISTRO} = \UBUNTU* ]]; then
      sudo apt-get install -y crudini
  else
      sudo yum install -y crudini
  fi
  # Enable RBAC
  sudo crudini --set /etc/st2/st2.conf rbac enable 'True'

  # TODO: Move directory creation to package
  sudo mkdir -p /opt/stackstorm/rbac/assignments/
  sudo mkdir -p /opt/stackstorm/rbac/roles/

  # Write role assignment for admin user
  ROLE_ASSIGNMENT_FILE="/opt/stackstorm/rbac/assignments/${ST2_USERNAME}.yaml"
  sudo bash -c "cat > ${ROLE_ASSIGNMENT_FILE}" <<EOL
---
  username: "${ST2_USERNAME}"
  roles:
    - "system_admin"
EOL

  # Write role assignment for stanley (system) user
  ROLE_ASSIGNMENT_FILE="/opt/stackstorm/rbac/assignments/stanley.yaml"
  sudo bash -c "cat > ${ROLE_ASSIGNMENT_FILE}" <<EOL
---
  username: "stanley"
  roles:
    - "admin"
EOL

  # Sync roles and assignments
  sudo st2-apply-rbac-definitions --config-file /etc/st2/st2.conf

}


restart_st2() {
    st2ctl restart
}

install_enterprise_bits
update_st2_conf
enable_and_configure_rbac
restart_st2
