#!/bin/sh
#
# This file's responsibility is to setup the required environment for
# running the ruby application, i.e. installing dependencies.
#
# This script will be executed once on each box if it changes. But be
# aware that boxes might skip versions of this file.

DIR="$(cd "$(dirname "$0")" && pwd)"

. ./util.sh

message "Checking if Filesystem needs expanding..."

if get_can_expand; then
  message "Expanding Filesystem..."
  raspi-config --expand-rootfs
  message "Rebooting"
  sudo reboot
else
  message "Filesystem already expanded or not expandable, carrying on..."
fi


message 'Installing base dependencies...'
sudo apt-get update
sudo apt-get -y install ruby ruby-dev darkice figlet libssl-dev
sudo gem install bundler --force --no-ri --no-rdoc


message 'Trigger reinstalling some dependencies...'
sudo gem uninstall -I eventmachine


message 'Running bundler (installing main dependencies)...'
(cd $DIR && bundle install)
