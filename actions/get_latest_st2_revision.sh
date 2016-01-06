#!/bin/bash

FLAVOR=$1
URL=https://downloads.stackstorm.net/deb/pool/trusty_$FLAVOR/main/s/st2api/
# echo URL is $URL

REV=$(curl -Ss -q $URL | grep "amd64.deb" | grep `curl -Ss -q $URL | grep "amd64.deb" | sed -e "s~.*>st2api_\(.*\)-.*<.*~\1~g" | sort --version-sort -r | uniq | head -n 1` | sed -e "s~.*>st2api_.*-\(.*\)_.*<.*~\1~g" | sort --version-sort -r | uniq | head -n 1)
if [[ $? == 0 ]]; then
    echo $REV
    exit 0
fi
echo "Failed getting version from $URL"
exit 1
