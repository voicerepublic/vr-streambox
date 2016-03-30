#!/bin/sh

pwd

git pull origin master

./setup.sh

./bin/streambox run
