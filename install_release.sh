#!/bin/sh

echo "Installing new release..."

VERSION=`curl -s -L https://voicerepublic.com/versions/streamboxx`
SOURCE="https://voicerepublic.com/releases/streambox-v$VERSION.tar.gz"

curl -s -L "$SOURCE" > ../archive.tar.gz

(cd ..; tar xfz archive.tar.gz)

RECENT=`ls -dArt ../streambox-v* | tail -n 1`

sync

echo "Activating new release..."
ln -nsf `basename $RECENT` ../streambox

sync

echo "Install complete."
