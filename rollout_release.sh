#!/bin/sh

# test if avail
VERSION=`cat VERSION`
TOKEN=`cat GITLAB_TOKEN`
BASE="https://gitlab.com/voicerepublic/streambox/repository/archive.tar.gz"
SOURCE="$BASE?ref=v$VERSION&private_token=$TOKEN"
curl -I -s -L "$SOURCE" | grep streambox-v$VERSION- |
    sed 's/Content-Disposition: attachment; filename=//'

# update
scp -o ClearAllForwardings=yes VERSION vrl:app/shared/public/versions/streamboxx

# confirm
echo -n 'Released '
curl https://voicerepublic.com/versions/streamboxx
