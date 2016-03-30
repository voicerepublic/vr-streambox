#!/bin/sh

set -x
DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Copy keys..."
mkdir -p /root/.ssh
cp $DIR/id_rsa* /root/.ssh

echo "Updating..."
git pull origin master

echo "Setting up..."
sudo apt-get update
sudo apt-get -y install git ruby ruby-dev darkice
sudo gem install bundler --no-ri --no-rdoc
echo "Running bundler..."
(cd $DIR && bundle install)

echo "Starting..."
(cd $DIR && ./bin/streambox)
