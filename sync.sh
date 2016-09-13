#!/bin/sh

# this script takes the following env vars
#
# - AWS_ACCESS_KEY_ID
# - AWS_SECRET_ACCESS_KEY
# - BUCKET
# - IDENTIFIER
# - REGION

#find ./recordings -type f -empty -delete

# 2) sync the rest
aws s3 sync recordings s3://$BUCKET/$IDENTIFIER --region $REGION && \
    (cd recordings; ls -1tp | tail -n +2 | xargs -I {} rm -- {})
