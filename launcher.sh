#!/bin/sh

DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Initial launch..."

while :
do
    (cd $DIR && ./start.sh)

    echo "Exited. Restarting in 5."
	  sleep 5
done
