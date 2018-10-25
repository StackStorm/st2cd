#!/bin/bash

set -e

ORG=$1
IMAGE=$2
VERSION=$3

if [[ -z "${ORG}" || -z "${IMAGE}" || -z "${VERSION}" ]]; then
	echo "ERROR: Missing required parameter"
	echo "Usage: $0 ORG PROJECT VERSION"
	exit 1
fi

function docker_tag_exists() {
    URI="https://hub.docker.com/v2/repositories/$1/tags"
    curl --silent --fail -lSL ${URI} | grep \"${VERSION}\" >/dev/null
}

while ! docker_tag_exists "${ORG}/${IMAGE}" $VERSION;
do
	echo "Polling every 60s until the ${ORG}/${IMAGE}:${VERSION} image exists."
	sleep 60
done
