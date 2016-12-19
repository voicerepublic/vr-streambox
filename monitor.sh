#!/bin/sh

#if [-e /boot/dev_box]; then

    cd ~pi/streambox

    mkdir -p ../recordings

    /usr/bin/watch -t -n 3 \
      "uptime; \
       test -e /boot/dev_box && echo 'DEV BOX'; \
       echo -n 'version         : '; cat VERSION; \
       echo -n 'subtype         : '; cat ../subtype; echo; \
       grep Serial /proc/cpuinfo; \
       cat /proc/meminfo | head -3; \
       vcgencmd measure_temp | sed 's/=/            : /'; \
       echo -n 'record pid      : '; cat ../record.sh.pid; echo; \
       test -e ../darkice.pid && (echo -n 'darkice pid     : '; cat ../darkice.pid; echo); \

       ps aux | grep launcher  | grep -v grep; \
       ps aux | grep ruby      | grep -v grep; \
       ps aux | grep record.sh | grep -v grep; \
       ps aux | grep sox       | grep -v grep; \
       ps aux | grep darkice   | grep -v grep; \
       ps aux | grep sync.sh   | grep -v grep; \
       ps aux | grep aws       | grep -v grep; \
       ps aux | grep dnsmasq   | grep -v grep; \
       df -h; \

       ls -lA ../recordings; \

       echo -n 'eth0 mac        : '; cat /sys/class/net/eth0/address; \
       echo -n 'wlan0 mac       : '; cat /sys/class/net/wlan0/address; \
       echo -n 'eth0 state      : '; cat /sys/class/net/eth0/operstate; \
       echo -n 'wlan0 state     : '; cat /sys/class/net/wlan0/operstate; \
       echo -n 'private ip      : '; hostname -I | cut -d ' ' -f 1; \
       echo -n '/etc/resolv.conf: '; cat /etc/resolv.conf | tail -n +2; \
       echo -n 'dnsmasq resolv.c: '; cat /var/run/dnsmasq/resolv.conf | tail -n +2; \
       ifconfig eth0; \
       ifconfig wlan0; \
       iwconfig wlan0; \
       service dnsmasq status"

#else

#    aafire

#fi
