#!/bin/sh

set -x
DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Updating..."
git pull origin master

echo "Setting up..."
sudo apt-get update
sudo apt-get -y install darkice dmidecode ruby git
sudo gem install bundler --no-ri --no-rdoc
echo "Running bundler..."
(cd $DIR && bundle install)
# TODO copy id_rsa to ~/.ssh

echo "Starting..."
(cd $DIR && ./bin/streambox)
