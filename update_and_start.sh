#!/bin/sh

set -x

pwd

# TODO replace with path of the script
cd streambox

pwd

echo "Updating..."

git pull origin master

echo "Setting up..."

./setup.sh

echo "Starting..."

./bin/streambox run
