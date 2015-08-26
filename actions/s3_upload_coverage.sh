#!/bin/bash

echo $@

COVER_DIR=$1
BUCKET=$2

if [ ! -d ${COVER_DIR} ]
then
    echo "Coverage dir ${COVER_DIR} doesn't exist."
    exit 1
fi

cd ${COVER_DIR}
s3cmd put --recursive * s3://${BUCKET}/
