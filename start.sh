#!/bin/sh
#
# Run setup if required and start the ruby application.

DIR="$(cd "$(dirname "$0")" && pwd)"

. ./util.sh


message 'Syncing clock...'
sudo ntpd -q -g


message 'Checking setup...'
diff -N $DIR/setup.sh $DIR/setup.sh.old
if [ $? -ne 0 ]; then
  message 'Setting up...'
  $DIR/setup.sh
  cp $DIR/setup.sh $DIR/setup.sh.old
fi


message 'Starting...'
(cd $DIR && ./bin/streambox)
