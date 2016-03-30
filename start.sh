#!/bin/sh
#
# Run setup if required and start the ruby application.

DIR="$(cd "$(dirname "$0")" && pwd)"


# check if setup changed
diff $DIR/setup.sh $DIR/setup.sh.old
if [ $? -ne 0 ]; then
  echo "Setting up..."
  $DIR/setup.sh
  cp $DIR/setup.sh $DIR/setup.sh.old
fi


echo "Starting..."
(cd $DIR && ./bin/streambox)
