#!/bin/sh

pwd

# TODO replace with path of the script
cd streambox

git pull origin master

./setup.sh

./bin/streambox run
