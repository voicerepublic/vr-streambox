#!/bin/sh

set -x
DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Initial launch..."

while :
do
    echo "Updating..."
    git pull origin master

    echo "Setting up..."
    sudp apt-get update
    sudo apt-get -y install darkice dmidecode ruby git
    sudo gem install bundler
    (cd $DIR && bundle install)
    # TODO copy id_rsa to ~/.ssh

    echo "Starting..."
    (cd $DIR && ./bin/streambox)

    echo "Exited. Restarting in 5."
	  sleep 5
done
