#!/bin/sh

set -e

VERSION=$((`cat VERSION`+1))

echo $VERSION > VERSION

git commit -m "bump version to $VERSION and rollout release" VERSION

git tag v$VERSION

git push origin --tags

git push || git pull && git push

BASE="https://gitlab.com/voicerepublic/streambox/repository/archive.tar.gz"
SOURCE="$BASE?ref=v$VERSION"
curl -s -H "PRIVATE-TOKEN: $GITLAB_TOKEN" -L "$SOURCE" > archive.tar.gz
scp archive.tar.gz vrl:app/shared/public/releases/streambox-v$VERSION.tar.gz

curl -I -L https://voicerepublic.com/releases/streambox-v$VERSION.tar.gz

rm archive.tar.gz

# update
scp -o ClearAllForwardings=yes VERSION vrl:app/shared/public/versions/streamboxx

# confirm
echo
echo '==============='
echo -n 'Released v'
curl https://voicerepublic.com/versions/streamboxx
echo '==============='
echo

TEXT="Streamboxx Release v$VERSION is now LIVE."
JSON='{"channel":"#streamboxx","text":"'$TEXT'","icon_emoji":":star2:","username":"streambox"}'
curl -X POST -H 'Content-type: application/json' --data "$JSON" \
     https://hooks.slack.com/services/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
echo
