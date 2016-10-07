#!/bin/sh

mkdir -p ../recordings

/usr/bin/watch -n 3 \
  "uptime; \
   cat VERSION; \
   cat ../subtype; \
   test -e /boot/dev_box && echo 'DEV BOX'; \
   grep Serial /proc/cpuinfo; \
   cat /sys/class/net/eth0/address; \
   cat /sys/class/net/wlan0/address; \
   hostname -I | cut -d ' ' -f 1; \
   vcgencmd measure_temp; \
   ps aux | grep sox; \
   ps aux | grep darkice; \
   df -h; \
   ls -lA ../recordings"
