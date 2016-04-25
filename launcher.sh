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
# This file facilitates the auto update of the VR Streambox.  If you
# break it, all boxes will stop updating.  This would be both:
# IRREVERSIBLE and VERY BAD.  So don't break it. It's that simple!

DIR="$(cd "$(dirname "$0")" && pwd)"


COLOR='\033[0;34m'
NC='\033[0m' # No Color

echo "${COLOR}Initial launch...${NC}"

while :
do
    echo "${COLOR}Provisioning keys...${NC}"
    mkdir -p /root/.ssh
    cp $DIR/id_rsa* /root/.ssh
    chmod 600 /root/.ssh/id_rsa*


    echo "${COLOR}Checking network connectiviy...${NC}"
    ping -c 1 voicerepublic.com
    while  [ $? -ne 0 ]
    do
        sleep 2
        ping -c 1 voicerepublic.com
    done


    echo "${COLOR}Updating...${NC}"
    (cd $DIR && git pull origin master)


    (cd $DIR && ./start.sh)


    echo "${COLOR}Exited. Restarting in 5.${NC}"
	  sleep 5
done
