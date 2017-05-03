#!/bin/bash

sudo apt-get install -y \
     opam m4 libtag1-dev libogg-dev libvorbis-dev \
     libmad0-dev libmp3lame-dev libpcre3-dev libasound2-dev

opam init --yes

# speed up by placing precompiled opam folder
wget http://voicerepublic.com/releases/opam.tar.gz
tar xfvz opam.tar.gz
rm opam.tar.gz

opam install --yes taglib mad lame vorbis cry alsa liquidsoap

# see https://github.com/savonet/liquidsoap-daemon
# liquidsoap-daemon

# CHECK this might need a reboot
sudo usermod -aG audio pi

sudo ln -s /home/pi/.opam/system/bin/liquidsoap /usr/local/bin/liquidsoap

echo 'Installation of liquidsoap complete.'
