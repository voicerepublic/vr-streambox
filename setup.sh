#!/bin/sh
#
# This file's responsibility is to setup the required environment for
# running the ruby application, i.e. installing dependencies.
#
# This script will be executed once on each box if it changes. But be
# aware that boxes might skip versions of this file.

DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Installing dependencies..."
sudo apt-get update
sudo apt-get -y install ruby ruby-dev darkice
sudo gem install bundler --force --no-ri --no-rdoc

echo "Running bundler (installing more dependencies)..."
(cd $DIR && bundle install)
