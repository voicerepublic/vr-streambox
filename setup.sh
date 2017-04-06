#!/bin/sh
#
# This file's responsibility is to setup the required environment for
# running the ruby application, i.e. installing dependencies.
#
# This script will be executed once on each box if it changes. But be
# aware that boxes might skip versions of this file.

DIR="$(cd "$(dirname "$0")" && pwd)"

. ./util.sh

message 'Update package database...'
sudo apt-get update
if [ $? -eq 0 ]; then
    message 'All good!'
else
    message 'Update failed, attempt to fix...'
    sudo dpkg --configure -a
    sudo apt-get update
fi

message 'Installing base dependencies...'
sudo apt-get -y install ruby ruby-dev toilet libssl-dev python-pip vorbis-tools hostapd dnsmasq sox htpdate lsof time ifplugd

message 'Installing bundler...'
sudo gem install bundler --force --no-ri --no-rdoc

message 'Installing some more dependencies...'
sudo pip install awscli

# # TODO it would be nice to do this only in case EM has been compiled
# # without ssl, otherwise we're just wasting time here
# message 'Trigger reinstalling some dependencies...'
# sudo gem uninstall -I eventmachine

message 'Running bundler (installing main dependencies)...'
(cd $DIR && bundle install)

su -c './install_liquidsoap.sh' pi

# use analog out for alsa
amixer cset numid=3 1

message 'Setup done.'
