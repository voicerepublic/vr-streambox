#!/bin/sh

cd ~pi/streambox

mkdir -p ../recordings

/usr/bin/watch -t -n 3 \
  "uptime; \
   test -e /boot/dev_box && echo 'DEV BOX'; \
   echo -n 'version         : '; cat VERSION; \
   echo -n 'subtype         : '; cat ../subtype; echo; \
   grep Serial /proc/cpuinfo; \
   echo -n 'eth0            : '; cat /sys/class/net/eth0/address; \
   echo -n 'wlan0           : '; cat /sys/class/net/wlan0/address; \
   echo -n 'private ip      : '; hostname -I | cut -d ' ' -f 1; \
   cat /proc/meminfo | head -3; \
   vcgencmd measure_temp; \
   ps aux | grep sox | grep -v grep; \
   ps aux | grep darkice | grep -v grep; \
   df -h; \
   ls -lA ../recordings"
