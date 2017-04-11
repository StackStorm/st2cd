#!/usr/bin/env bash

RBAC_ASSIGNMENTS_DIR="/opt/stackstorm/rbac/assignments"

function role_assignment_exists() {
    username=$1
    role=$2
    assignment_file_path="${RBAC_ASSIGNMENTS_DIR}/${username}.yaml"

    # Verify assignment file exists
    if [ ! -f ${assignment_file_path} ]; then
        echo "RBAC role assignment file '${assignment_file_path}' for user '${username}' doesn't exist"
        exit 1
    fi

    # Verify assignment file contains "admin" role assignment
    cat ${assignment_file_path} | grep -q "\- \"${role}\""
    exit_code=$?

    if [ ${exit_code} -ne 0 ]; then
        echo "RBAC role assignment file '${assignment_file_path}' for user '${username}' is missing '${role}' role assignment"
        exit 1
    fi
}

role_assignment_exists "st2admin" "system_admin"
role_assignment_exists "stanley" "admin"

echo "All role assignmet files exist"
exit 0
