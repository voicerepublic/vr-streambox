#!/bin/bash

DIR="$(cd "$(dirname "$0")" && pwd)"

. $DIR/util.sh

BRANCH=$1

message "Woot! This is a dev box! Living on the egde..."

mkdir -p /root/.ssh
cp $DIR/id_rsa* /root/.ssh
chmod 600 /root/.ssh/id_rsa*

message 'Switching to repository...'
rm ~pi/streambox
ln -sf streambox-repo ~pi/streambox

message "Updating repository..."
(cd $DIR
 git fetch origin $BRANCH
 git reset --hard origin/$BRANCH
 sync
 message "Complete.")
