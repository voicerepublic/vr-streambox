#!/bin/sh

echo -n "Installing release $VERSION..."

BASE="https://gitlab.com/voicerepublic/streambox/repository/archive.tar.gz"

SOURCE="$BASE?ref=v$VERSION&private_token=$TOKEN"

curl -s -L "$SOURCE" > ../archive.tar.gz

(cd ..; tar xfz archive.tar.gz)

RECENT=`ls -dArt ../streambox-master-* | tail -n 1`

sync

ln -sf `basename $RECENT` ../streambox

sync

echo "complete."
