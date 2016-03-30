#!/bin/sh

DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Initial launch..."

while :
do
    echo "Copy keys..."
    mkdir -p /root/.ssh
    cp $DIR/id_rsa* /root/.ssh

    echo "Updating..."
    (cd $DIR && git pull origin master)


    (cd $DIR && ./start.sh)


    echo "Exited. Restarting in 5."
	  sleep 5
done
