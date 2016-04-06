#!/bin/sh
#
# Run setup if required and start the ruby application.

DIR="$(cd "$(dirname "$0")" && pwd)"

# maybe move into launcher
echo "Waiting for network connectiviy..."
ping -c 1 voicerepublic.com
while  [ $? -ne 0 ]
do
    sleep 2
    ping -c 1 voicerepublic.com
done


echo "Syncing clock..."
sudo ntpd -q -g


# check if setup changed
diff -N $DIR/setup.sh $DIR/setup.sh.old
if [ $? -ne 0 ]; then
  echo "Setting up..."
  $DIR/setup.sh
  cp $DIR/setup.sh $DIR/setup.sh.old
fi


echo "Starting..."
(cd $DIR && ./bin/streambox)
