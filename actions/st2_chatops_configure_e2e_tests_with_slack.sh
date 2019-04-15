#!/bin/bash

# REQUIRED environment variables:
# * SLACK_BOT_API_TOKEN
#   - the Slack API token for the ST2 instance that is under test
#   - this will be the token put into /opt/stackstorm/chatops/st2chatops.env
#   - THIS MUST BE DIFFERENT THAN SLACK_USER_API_TOKEN

# Install the Slack API token and backup the file to st2chatops.env.orig
sed -i'.orig' "s/^# export HUBOT_ADAPTER=slack/export HUBOT_ADAPTER=slack/; s/^# export HUBOT_SLACK_TOKEN=xoxb-CHANGE-ME-PLEASE/export HUBOT_SLACK_TOKEN=$SLACK_BOT_API_TOKEN/" /opt/stackstorm/chatops/st2chatops.env

st2ctl restart-component st2chatops
