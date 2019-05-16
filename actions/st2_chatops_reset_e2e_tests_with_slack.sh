#!/bin/bash

# Reset the st2chatops configuration
sed -i'.bak-slack' "s/^export HUBOT_ADAPTER=slack/# export HUBOT_ADAPTER=slack/; s/^export HUBOT_SLACK_TOKEN=/# export HUBOT_SLACK_TOKEN=/" /opt/stackstorm/chatops/st2chatops.env

st2ctl restart-component st2chatops
