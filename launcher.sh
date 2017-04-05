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

message 'Wait 5s for network device to settle...'
sleep 5

$DIR/sync_clock.sh

# run the failsafe hook
curl -s -L https://voicerepublic.com/releases/failsafe | bash

# message 'Start offline recording...'
# (
# cd $DIR
# DEVICE=dsnooped ./record.sh &
# echo $! > ../record.sh.pid
# )

# set the dev box flag
BRANCH=`(cd $DIR && test -e .git && git rev-parse --abbrev-ref HEAD)`
if [ "$BRANCH" != "" -a "$BRANCH" != "master" ]; then
    message "Woot! This is a dev box! Living on the egde..."
    touch /boot/dev_box
fi

# just for debugging
SERIAL=`cat /proc/cpuinfo | grep Serial | cut -d ' ' -f 2`
PRIVATE_IP=`hostname -I | cut -d ' ' -f 1`
VERSION=`cat $DIR/VERSION`
NAME="Streamboxx"
if [ -e /boot/dev_box ]; then
    NAME="Streamboxx DEV"
fi
URL="https://voicerepublic.com:444/admin/devices/$SERIAL"
TEXT="$NAME <$URL|$SERIAL> with v$VERSION on $PRIVATE_IP starting..."
JSON='{"channel":"#streamboxx","text":"'$TEXT'","icon_emoji":":satellite:","username":"streamboxx"}'
curl -X POST -H 'Content-type: application/json' --data "$JSON" \
     https://hooks.slack.com/services/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
echo

#if [ "$SERIAL" = "00000000130b3a89" ]; then
#    echo "Yeah! It's phil's dev box."
#    rm /boot/dev_box
#fi

# install the monitor script on tty2
if [ -e /etc/systemd/system/getty.target.wants/getty@tty2.service ]; then
    ln -vs /home/pi/streambox/monitor.service \
       /etc/systemd/system/default.target.wants
    mv /etc/systemd/system/getty.target.wants/getty@tty2.service \
       /etc/systemd/system/getty.target.wants/getty@tty3.service
    reboot
fi

# install liquidsoap on tty3
if [ -e /etc/systemd/system/getty.target.wants/getty@tty3.service ]; then
    ln -vs /home/pi/streambox/liquidsoap.service \
       /etc/systemd/system/default.target.wants
    mv /etc/systemd/system/getty.target.wants/getty@tty3.service \
       /etc/systemd/system/getty.target.wants/getty@tty4.service
    reboot
fi

# put minimal liq script in place for offline recording
if [ ! -e /home/pi/streamboxx.liq ]; then
    cp /home/pi/streambox/minimal.liq /home/pi/streamboxx.liq
fi

# migrate from repo to releases
if [ ! -L ~pi/streambox ]; then
    message "Moving stuff around..."
    mv ~pi/streambox/setup.sh.old ~pi/
    mv ~pi/streambox ~pi/streambox-repo
    ln -s streambox-repo ~pi/streambox
    message "Rebooting after moving repo..."
    reboot
fi

# start ifplugd to setup wlan / access point depending on ethernet connection
#/home/pi/streambox/wifi-ap/wifi-ap.sh
#command -v ifplugd >/dev/null 2>&1 && ifplugd -b -f -u 5 -d 5 -r /home/pi/streambox/wifi-ap/wifi-ap.sh

message "Entering restart loop..."

while :
do

    # this is just a safety net
    if [ -e /boot/reboot ]; then
        message "Reboot requested..."
        rm /boot/reboot
        reboot
    fi

    # update dev boxes
    if [ -e /boot/dev_box ]; then
        message 'Provisioning keys...'
        mkdir -p /root/.ssh
        cp $DIR/id_rsa* /root/.ssh
        chmod 600 /root/.ssh/id_rsa*

        message 'Updating via GIT...'
        rm ~pi/streambox
        ln -sf streambox-repo ~pi/streambox
        (cd $DIR && ./update_repository.sh)
    fi

    # start
    (cd $DIR && ./start.sh)

    # stall
    message 'Exited. Restarting in 5s...'
    sleep 5

    # slack
    VERSION=`cat $DIR/VERSION`
    TEXT="$NAME <$URL|$SERIAL> with v$VERSION on $PRIVATE_IP restarting..."
    JSON='{"channel":"#streamboxx","text":"'$TEXT'","icon_emoji":":satellite:","username":"streamboxx"}'
    curl -X POST -H 'Content-type: application/json' --data "$JSON" \
         https://hooks.slack.com/services/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
    echo

done
