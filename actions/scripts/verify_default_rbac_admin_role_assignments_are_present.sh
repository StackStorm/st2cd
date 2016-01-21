#!/usr/bin/env bash

RBAC_ASSIGNMENTS_DIR="/opt/stackstorm/rbac/assignments"

function admin_role_assignment_exists() {
    username=$1
    assignment_file_path="${RBAC_ASSIGNMENTS_DIR}/${username}.yaml"

    # Verify assignment file exists
    if [ ! -f ${assignment_file_path} ]; then
        echo "RBAC role assignment file '${assignment_file_path}' for user '${username}' doesn't exist"
        exit 1
    fi

    # Verify assignment file contains "admin" role assignment
    cat ${assignment_file_path} | grep '\- "admin"'
    exit_code=$?

    if [ ${exit_code} -ne 0 ]; then
        echo "RBAC role assignment file '${assignment_file_path}' for user '${username}' is missing 'admin' role assignment"
        exit 1
    fi
}

admin_role_assignment_exists "root_cli"
admin_role_assignment_exists "stanley"
admin_role_assignment_exists "admin"
admin_role_assignment_exists "chatops_bot"

echo "All role assignmet files exist"
exit 0
