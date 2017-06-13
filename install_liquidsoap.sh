#!/bin/bash

sudo apt-get install -y --force-yes \
     opam m4 libtag1-dev libogg-dev libvorbis-dev \
     libmad0-dev libmp3lame-dev libpcre3-dev libasound2-dev pv

if [ ! -d ../.opam ]; then

# speed up by placing precompiled opam folder
( cd ..
  echo
  echo "Fetching prebuilt opam..."
  echo
  wget http://voicerepublic.com/releases/opam.tar.gz
  echo "Unpacking opam..."
  echo
  echo "Since this will take up to 15 minutes, we'll show you a bogus progress bar."
  echo
  pv opam.tar.gz | tar xz
  rm opam.tar.gz )

fi

opam init --yes
opam install --yes taglib mad lame vorbis cry alsa liquidsoap

# see https://github.com/savonet/liquidsoap-daemon
# liquidsoap-daemon

# CHECK this might need a reboot
sudo usermod -aG audio pi

sudo ln -sf /home/pi/.opam/system/bin/liquidsoap /usr/local/bin/liquidsoap

echo 'Installation of liquidsoap complete.'
