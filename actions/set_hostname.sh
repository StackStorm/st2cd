#!/bin/bash
set -e

HOSTNAME=$1
DISTRO=$2

DISTRO_LCASE=`echo "${DISTRO}" | awk '{print tolower($0)}'`

SUPPORTED_DISTROS=(
    "centos"
    "rocky"
    "fedora"
    "redhat"
    "ubuntu"
)

if [[ ! ${SUPPORTED_DISTROS[@]} =~ (^| )${DISTRO_LCASE}($| ) ]]; then
    >&2 echo "ERROR: ${DISTRO} is an unsupported Linux distribution."
    exit 1
fi

ORIGINAL_HOSTNAME=$(hostname)

if [[ ${DISTRO_LCASE} = "ubuntu" ]]; then
    sed -i -e "s/\(preserve_hostname: \)false/\1true/" /etc/cloud/cloud.cfg && echo "${HOSTNAME}" > /etc/hostname && hostname ${HOSTNAME}
elif [[ ${DISTRO_LCASE} = "redhat" || ${DISTRO_LCASE} = "centos" || ${DISTRO_LCASE} = "rocky" ]]; then
    # Note: We also want to make sure /etc/hostname file matches
    sed -i -e "s/\(HOSTNAME=\).*/\1${HOSTNAME}/" /etc/sysconfig/network && echo "${HOSTNAME}" > /etc/hostname && hostname ${HOSTNAME}
    hostnamectl set-hostname --static ${HOSTNAME}
    # Make sure the hostname is preserved between the reboots
    echo "preserve_hostname: true" > /etc/cloud/cloud.cfg.d/99_hostname.cfg
elif [[ ${DISTRO_LCASE} = "fedora" ]]; then
    echo -e "HOSTNAME=${HOSTNAME}" >> /etc/sysconfig/network && echo "${HOSTNAME}" > /etc/hostname && hostname ${HOSTNAME}
fi

# For just in case (for scenarios where hostname is not correctly set and preserved during reboots,
# also add original hostname to /etc/hosts)
#sed -i "/127\.0\.0\.1/ s/$/ ${ORIGINAL_HOSTNAME}/" /etc/hosts

# Add new hostname to /etc/hosts
sed -i "/127\.0\.0\.1/ s/$/ ${HOSTNAME}/" /etc/hosts

echo "Original hostname: ${ORIGINAL_HOSTNAME}"
echo "New hostname: ${HOSTNAME}"
