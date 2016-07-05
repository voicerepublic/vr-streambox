#!/bin/sh
#
# This file's responsibility is to expand the file system on the first run.
#
# This script will be executed once on each box, if the file in $SHOULD_AUTO_EXPAND
# exists. After that, it will not run
#

DIR="$(cd "$(dirname "$0")" && pwd)"

SHOULD_AUTO_EXPAND=/boot/auto_expand
NEED_AUTO_EXPAND="$DIR/../expanded"



. $DIR/util.sh

if [ ! -e $NEED_AUTO_EXPAND ]; then
  if [ -e $SHOULD_AUTO_EXPAND ]; then

    message "Checking if Filesystem needs expanding..."

    SIZE=$(df --output=size,target | grep /$ | sed -e /Size/d | sed 's: /$::g')

    if [ "$SIZE" -lt "2000000" ]; then
      message "Expanding Filesystem..."
      sudo raspi-config --expand-rootfs
      touch $NEED_AUTO_EXPAND
      message "Rebooting..."
      sleep 1
      sudo reboot
    else
      message "Filesystem already bigger than 2GB, assuming expansion already took place and continuing."
      touch $NEED_AUTO_EXPAND
    fi
  else
    message "$SHOULD_AUTO_EXPAND not present, will not automatically expand filesystem!"
  fi
else
  message "Filesystem already marked as expanded, nothing to do here..."
fi
