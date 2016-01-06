#!/bin/bash

FLAVOR=$1
URL=https://downloads.stackstorm.net/deb/pool/trusty_$FLAVOR/main/s/st2api/
# echo URL is $URL
VER=`curl -Ss -q $URL | grep "amd64.deb" | sed -e "s~.*>st2api_\(.*\)-.*<.*~\1~g" | sort --version-sort -r | uniq | head -n 1`
if [[ $? == 0 ]]; then
    echo $VER
    exit 0
fi
echo "Failed getting version from $URL"
exit 1
