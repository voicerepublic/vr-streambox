#!/bin/sh

# this script takes the following env vars
#
# - AWS_ACCESS_KEY_ID
# - AWS_SECRET_ACCESS_KEY
# - BUCKET
# - IDENTIFIER
# - REGION

aws s3 sync ../recordings s3://$BUCKET/$IDENTIFIER --region $REGION --quiet && \
    (cd ../recordings; ls -1tp | tail -n +2 | xargs -I {} rm -- {})
