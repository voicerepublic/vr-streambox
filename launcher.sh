#!/bin/sh
#
#---------------------------------------------------------------#
#  ____ ___ ____  __        ___    ____  _   _ ___ _   _  ____  #
# | __ )_ _/ ___| \ \      / / \  |  _ \| \ | |_ _| \ | |/ ___| #
# |  _ \| | |  _   \ \ /\ / / _ \ | |_) |  \| || ||  \| | |  _  #
# | |_) | | |_| |   \ V  V / ___ \|  _ <| |\  || || |\  | |_| | #
# |____/___\____|    \_/\_/_/   \_\_| \_\_| \_|___|_| \_|\____| #
#                                                               #
#---------------------------------------------------------------#
#
# This file facilitates the auto update of the VR Streambox. If you
# break it, all boxes will stop updating. This would be both:
# IRREVERSIBLE and VERY BAD. So don't break it. It's that simple!

DIR="$(cd "$(dirname "$0")" && pwd)"

. $DIR/util.sh

message "Initial launch..."

$DIR/expand.sh

message 'Removing stale pid files...'
rm -f ~pi/*.pid

message 'Wait 3s for network device to settle...'
sleep 3

# just for debugging
SERIAL=`cat /proc/cpuinfo | grep Serial | cut -d ' ' -f 2`
PRIVATE_IP=`hostname -I | cut -d ' ' -f 1`
BRANCH=`(cd $DIR && git rev-parse --abbrev-ref HEAD)`
TEXT="Streamboxx $SERIAL ($BRANCH) on $PRIVATE_IP starting..."
JSON='{"channel":"#streamboxx","text":"'$TEXT'","icon_emoji":":satellite:","username":"streamboxx"}'
curl -X POST -H 'Content-type: application/json' --data "$JSON" \
     https://hooks.slack.com/services/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
echo

# set the dev box flag
if [ "$BRANCH" != "" -a "$BRANCH" != "master" ]; then
    message "Woot! This is a dev box! Living on the egde..."
    touch /boot/dev_box
fi

if [ "$SERIAL" = "00000000130b3a89" ]; then
    echo "Yeah! It's phil's dev box."
    rm /boot/dev_box
fi

#if [ -d ~pi/streambox ]; then
#    mv ~pi/streambox ~pi/streambox-repo
#    ln -sf ~pi/streambox-repo ~pi/streambox
#    reboot
#fi

message "Entering restart loop..."

while :
do

    #if [ -e /boot/dev_box ]; then
    message 'Provisioning keys...'
    mkdir -p /root/.ssh
    cp $DIR/id_rsa* /root/.ssh
    chmod 600 /root/.ssh/id_rsa*

    message 'Updating via GIT...'
    ln -sf ~pi/streambox-repo ~pi/streambox
    ./update_repository.sh
    #fi

    (cd $DIR && ./start.sh)

    message 'Exited. Restarting in 5s...'
    sleep 5

    TEXT="Streamboxx $SERIAL ($BRANCH) on $PRIVATE_IP restarting..."
    JSON='{"channel":"#streamboxx","text":"'$TEXT'","icon_emoji":":satellite:","username":"streamboxx"}'
    curl -X POST -H 'Content-type: application/json' --data "$JSON" \
         https://hooks.slack.com/services/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
    echo

done
