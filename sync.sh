#!/bin/sh

# this script takes the following env vars
#
# - AWS_ACCESS_KEY_ID
# - AWS_SECRET_ACCESS_KEY
# - BUCKET
# - IDENTIFIER
# - REGION

(
    cd ../recordings

    rm -f sync.log

    aws s3 sync . s3://$BUCKET/$IDENTIFIER --region $REGION \
        >../streambox/sync.log 2>&1 && \
        (ls -1tp | tail -n +2 | xargs -I {} rm -- {})
)
