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


# just for debugging
SERIAL=`cat /proc/cpuinfo | grep Serial | cut -d ' ' -f 2`
PRIVATE_IP=`hostname -I | cut -d ' ' -f 1`
TEXT="Started Streamboxx $SERIAL with $PRIVATE_IP"
JSON='{"channel":"#streamboxx","text":"'$TEXT'","icon_emoji":":satellite:","username":"streamboxx"}'
curl -X POST -H 'Content-type: application/json' --data "$JSON" \
     https://hooks.slack.com/services/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
echo


while :
do
    message 'Provisioning keys...'
    mkdir -p /root/.ssh
    cp $DIR/id_rsa* /root/.ssh
    chmod 600 /root/.ssh/id_rsa*


    message 'Checking network connectivity...'
    ping -c 1 voicerepublic.com
    while  [ $? -ne 0 ]
    do
        sleep 2
        ping -c 1 voicerepublic.com
    done


    message 'Updating...'
    (branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null) && cd $DIR && git fetch origin $branch && git reset --hard origin/branch)


    (cd $DIR && ./start.sh)


    message 'Exited. Restarting in 5.'
    sleep 5
done
