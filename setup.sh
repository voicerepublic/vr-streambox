#!/bin/sh

DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Installing dependencies..."
sudo apt-get update
sudo apt-get -y install git ruby ruby-dev darkice
sudo gem install bundler --no-ri --no-rdoc

echo "Running bundler (installing more dependencies)..."
(cd $DIR && bundle install)
