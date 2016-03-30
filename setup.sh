#!/bin/sh

sudp apt-get update

sudo apt-get -y install darkice dmidecode launchtool ruby

sudo gem install bundler

bundle install
