#!/bin/sh

cd ~pi/streambox

mkdir -p ../recordings

/usr/bin/watch -n 3 \
  "uptime; \
   test -e /boot/dev_box && echo 'DEV BOX'; \
   cat VERSION; \
   cat ../subtype; \
   grep Serial /proc/cpuinfo; \
   echo -n 'eth0       '; cat /sys/class/net/eth0/address; \
   echo -n 'wlan0      '; cat /sys/class/net/wlan0/address; \
   echo -n 'private ip '; hostname -I | cut -d ' ' -f 1; \
   vcgencmd measure_temp; \
   cat /proc/meminfo | head -3; \
   ps aux | grep sox | grep -v grep; \
   ps aux | grep darkice | grep -v grep; \
   df -h; \
   ls -lA ../recordings"
