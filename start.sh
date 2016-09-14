#!/bin/sh
#
# Run setup if required and start the ruby application.

DIR="$(cd "$(dirname "$0")" && pwd)"

. ./util.sh


message 'Configuring ALSA dsnooped device...'
cp $DIR/asound.conf /etc
service alsa-utils restart


message 'Syncing clock...'
sudo ntpd -q -g


message 'Checking setup...'
diff -N $DIR/setup.sh $DIR/../setup.sh.old 2>&1 >/dev/null
if [ $? -ne 0 ]; then
  message 'Setting up...'
  $DIR/setup.sh
  cp $DIR/setup.sh $DIR/../setup.sh.old
fi


message 'Starting...'
(cd $DIR && ./bin/streambox)
