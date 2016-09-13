#!/bin/sh

set -e

VERSION=`cat VERSION`

git tag v$VERSION
git push

# test if avail
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
