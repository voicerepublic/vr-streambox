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
rm -f ~pi/streambox/*.pid

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

# persist the dev box trait on /boot
if [ "$BRANCH" -ne "master" ]; then
    touch /boot/dev_box
fi

# migrate repo somewhere else to make space for symlink
if [ -d ~pi/streambox ]; then
    mv ~pi/streambox ~pi/streambox-repo
    ln -sf ~pi/streambox-repo ~pi/streambox
fi

while :
do

    # make sure dev boxes use the repo
    if [ -e /boot/dev_box ]; then
        message 'Attempt to update before starting...'
        ln -sf ~pi/streambox-repo ~pi/streambox
        ./update_development.sh
    fi

    (cd $DIR && ./start.sh)

    message 'Exited. Restarting in 5s...'
    sleep 5

    TEXT="Streamboxx $SERIAL ($BRANCH) on $PRIVATE_IP restarting..."
    JSON='{"channel":"#streamboxx","text":"'$TEXT'","icon_emoji":":satellite:","username":"streamboxx"}'
    curl -X POST -H 'Content-type: application/json' --data "$JSON" \
         https://hooks.slack.com/services/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
    echo

    message 'Provisioning keys...'
    mkdir -p /root/.ssh
    cp $DIR/id_rsa* /root/.ssh
    chmod 600 /root/.ssh/id_rsa*

    # message 'Checking network connectivity...'
    # ping -n -c 1 voicerepublic.com
    # while  [ $? -ne 0 ]
    # do
    #     sleep 2
    #     ping -n -c 1 voicerepublic.com
    # done

done
