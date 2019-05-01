#!/bin/bash

# REQUIRED environment variables:
# * WEBSOCKET_CLIENT_CA_BUNDLE
#   - Should be set to:
#     /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem
#     for RHEL7 systems
#   - Unnecessary for systems with Python 2.7.9+ (eg: Ubuntu 16.04 and later)
# * SLACK_USER_USERNAME
#   - the Slack username for the Python script impersonating a user
#   - this should be set to the same username as the SLACK_USER Slackbot, below
# * SLACK_USER_API_TOKEN
#   - the Slack API token for the Python script that impersonates a user
#   - THIS MUST BE DIFFERENT THAN SLACK_BOT_API_TOKEN

. venv/bin/activate && python chatops/test_e2e_with_slack.py
