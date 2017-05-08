#!/bin/bash

DIR="$(cd "$(dirname "$0")" && pwd)"

BRANCH=$1

echo "Woot! This is a dev box! Living on the egde..."

mkdir -p /root/.ssh
cp $DIR/id_rsa* /root/.ssh
chmod 600 /root/.ssh/id_rsa*

echo 'Switching to repository...'
rm ~pi/streambox
ln -sf streambox-repo ~pi/streambox

echo "Updating repository, switching to branch $BRANCH..."
(cd $DIR
 git fetch origin $BRANCH
 git reset --hard origin/$BRANCH
 sync
 echo "Complete.")
