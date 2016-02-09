#!/usr/bin/env bash

# Upgrade version (e.g. 1.3.0)
UPGRADE_VERSION=$1

# Upgrade revision (e.g. 10)
UPGRADE_REVISION=$2

if [ $# -ne 2 ]; then
    echo "Usage $0 <upgrade version> <upgrade revision>"
    echo "For example: $0 1.3.0 10"
    exit 1
fi

PACKAGES=(st2actionrunner st2api st2auth st2client st2common st2debug st2reactor)

function verify_debian_package_version_is_installed() {
    # Function which verifies that the specified version of Debian package is installed
    package=$1
    version=$2

    # 1. Verify package is installed
    output=$(dpkg -s ${package} 2>&1)
    exit_code=$?

    if [ $exit_code -ne 0 ]; then
        echo "Package ${package} is not installed"
        echo "${output}"
        exit 1
    fi

    # 2. Verify installed version
    installed_version=`dpkg -s ${package} | grep Version | awk -F: '{print $2}' | sed -e 's/^[ \t]*//'`

    if [ ${installed_version} != ${version} ]; then
        echo "Expected version \"${version}\", but version \"${installed_version}\" of package \"${package}\" is installed"
        exit 2
    fi

    echo "Package ${package} is at the correct version"
}

# 1. Verify that st2* packages have been upgraded
echo "Checking package versions..."

UPGRADE_VERSION_REVISION="${UPGRADE_VERSION}-${UPGRADE_REVISION}"

for package in "${PACKAGES[@]}"; do
    verify_debian_package_version_is_installed ${package} ${UPGRADE_VERSION_REVISION}
done

echo ""

# 2. Verify st2client has been upgraded
echo "Checking st2client version..."

UPGRADE_VERSION_REVISION="${UPGRADE_VERSION}.${UPGRADE_REVISION}"

# 2.1 Verify st2client is installed and available in path
OUTPUT=$(st2 2>&1)
EXIT_CODE=$?

if [ ${EXIT_CODE} -ne 0 ]; then
    echo "st2client is not installed or not available in PATH"
    echo "${OUTPUT}"
    exit 3
fi

INSTALLED_ST2CLIENT_VERSION_REVISION=$(st2 --version 2>&1 | awk -F \' '{print $2}')

if [ ${INSTALLED_ST2CLIENT_VERSION_REVISION} != ${UPGRADE_VERSION_REVISION} ]; then
    echo "Expected version ${UPGRADE_VERSION_REVISION} of st2client, but got ${INSTALLED_ST2CLIENT_VERSION_REVISION}"
    exit 4
fi

echo "All the upgrade checks have successfuly completed!"
exit 0
