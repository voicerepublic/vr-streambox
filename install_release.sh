#!/bin/sh

#VERSION=`curl -s -L https://voicerepublic.com/versions/streamboxx`
VERSION=$1

echo "Installing release $VERSION..."

SOURCE="https://voicerepublic.com/releases/streambox-v$VERSION.tar.gz"

curl -s -L "$SOURCE" > ../archive.tar.gz

(cd ..; tar xfz archive.tar.gz; rm archive.tar.gz)

RECENT=`ls -dArt ../streambox-v* | tail -n 1`

sync

echo "Activating new release..."
ln -nsf `basename $RECENT` ../streambox

sync

echo "Install complete."
