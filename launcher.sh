#!/bin/sh

set -x

DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Initial launch..."

while :
do
  $DIR/update_and_start.sh
	sleep 5
done

# /usr/bin/launchtool -t streambox -u root -g root -Lnvc $DIR/update_and_start.sh
