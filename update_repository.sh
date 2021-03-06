#!/bin/sh

echo -n "Updating repository..."

DIR="$(cd "$(dirname "$0")" && pwd)"

BRANCH=`(cd $DIR && git rev-parse --abbrev-ref HEAD)`

(cd $DIR && git fetch origin $BRANCH && git reset --hard origin/$BRANCH)

sync

echo "complete."
