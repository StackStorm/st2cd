#!/bin/bash

echo $@

COVER_DIR=$1
BUCKET=$2
BRANCH=$3

if [ ! -d ${COVER_DIR} ]
then
    echo "Coverage dir ${COVER_DIR} doesn't exist."
    exit 1
fi

BUCKET_PATH=${BUCKET}/${BRANCH}

cd ${COVER_DIR}
s3cmd -M put --recursive * s3://${BUCKET_PATH}/

if [ $? == 0 ]
then
    # S3 doesn't detect content type of CSS files correctly. So set
    # CSS file content type to text/css
    s3cmd -m text/css put ${COVER_DIR}/style.css s3://${BUCKET_PATH}/
else
    echo "Failed uploading coverage report to S3."
    # Don't fail action
fi
