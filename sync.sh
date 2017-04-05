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

    # TODO purge empty files before sync
    # ACTIVE_PATH=`lsof -c sox | grep recordings | tr -s ' ' | cut -d ' ' -f 9`
    # ACTIVE_FILE=`basename $ACTIVE_PATH`
    # find -empty | grep -v $ACTIVE_FILE | xargs -I {} rm -- {}

    aws s3 sync . s3://$BUCKET/$IDENTIFIER --region $REGION \
        >>../streambox/sync.log 2>&1

    if [ $? -eq 0 ]; then
        # find the file which is currently being written to and delete all others
        ACTIVE_PATH=`lsof -c sox | grep recordings | tr -s ' ' | cut -d ' ' -f 9`
        if [ -n "$ACTIVE_PATH" ]; then
            ACTIVE_FILE=`basename $ACTIVE_PATH`
            ls -1 | grep -v $ACTIVE_FILE | xargs -I {} rm -- {}
        else
            ls -1 | xargs -I {} rm -- {}
        fi
        echo "Cleanup after sync complete." >>../streambox/sync.log
    else
        echo "Sync failed, skipping cleanup." >>../streambox/sync.log
    fi
)
