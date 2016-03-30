#!/bin/sh

set -x

pwd

sudp apt-get update

sudo apt-get -y install darkice dmidecode launchtool ruby git

sudo gem install bundler

bundle install

# TODO copy id_rsa to ~/.ssh
