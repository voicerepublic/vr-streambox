#!/bin/sh

DIR="$(cd "$(dirname "$0")" && pwd)"


diff $DIR/setup.sh $DIR/setup.sh.old
if [ $? -ne 0 ]; then
  $DIR/setup.sh
  cp $DIR/setup.sh $DIR/setup.sh.old
fi


echo "Starting..."
(cd $DIR && ./bin/streambox)
