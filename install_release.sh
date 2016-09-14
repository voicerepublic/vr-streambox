#!/bin/sh

echo -n "Installing release $VERSION..."

BASE="https://gitlab.com/voicerepublic/streambox/repository/archive.tar.gz"

SOURCE="$BASE?ref=v$VERSION&private_token=$TOKEN"

echo $SOURCE

curl -s -L "$SOURCE" > ../archive.tar.gz

ls -la ../archive.tar.gz
file ../archive.tar.gz

(cd ..; tar xfz archive.tar.gz)

RECENT=`ls -dArt ../streambox-v* | tail -n 1`

sync

echo ln -sf `basename $RECENT` ../streambox

sync

echo "complete."
