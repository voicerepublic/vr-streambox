#!/bin/sh


DIR="$(cd "$(dirname "$0")" && pwd)"


DHCPCD="denyinterfaces wlan0"

SSID="VR Streaming"
PASSWORD="streamsdocometrue"

sed -i'.bak' '/^.*wlan0$/,/^$/ d' /etc/network/interfaces

#Extract speed info from ethtool. If speed is 10 Mb/s, no cable is connected. If it is 100 Mb/s, there is a cable present.
SPEED=`ethtool eth0 | grep -i "Speed" | awk '{print $2}' | grep -o '[0-9]*'`
if [ "$SPEED" -eq 100 ]; then
    echo "Ethernet cable connected. Setting up Wireless Access Point"

    if ! grep -q "$DHCPCD" /etc/dhcpcd.conf; then
        echo $DHCPCD >> /etc/dhcpcd.conf
    fi

    cp -f $DIR/interfaces/wlan0_access-point /etc/network/interfaces.d/wlan0

    sed -e "s/SSID/vr-streamboxx/" -e "s/PASSWORD/some-password-tbd/" $DIR/hostapd.conf.template > /etc/hostapd/hostapd.conf
    sed -i'' 's:#DAEMON_CONF="":DAEMON_CONF="/etc/hostapd/hostapd.conf":' /etc/default/hostapd

    if [ ! -f "/etc/dnsmasq.conf.bak" ]; then
        mv /etc/dnsmasq.conf /etc/dnsmasq.conf.bak
    fi
    cp $DIR/dnsmasq.conf /etc/dnsmasq.conf

    # enable ip-forwarding
    # can be done permanently by setting net.ipv4.ip_forward=1 in /etc/sysctl.conf
    # but since this script will run on every boot, that is not necessary
    echo 1 > /proc/sys/net/ipv4/ip_forward

    # add forwarding rules to iptables
    # also can be persisted:
    # iptables-save > /etc/iptables.ipv4.nat
    # sed -i'' '/exit 0/iiptables-restore < /etc/iptables.ipv4.nat' /etc/rc.local

    iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
    iptables -A FORWARD -i eth0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT
    iptables -A FORWARD -i wlan0 -o eth0 -j ACCEPT

else
    echo "No Ethernet connected. Trying to connect to Wireless Access Point"

    sed -i'' "/$DHCPCD/d" /etc/dhcpcd.conf

    cp -f $DIR/interfaces/wlan0 /etc/network/interfaces.d/wlan0

    sed -e "s/SSID/$SSID/" -e "s/PASSWORD/$PASSWORD/" $DIR/interfaces/wpa_supplicant.conf.template > /etc/wpa_supplicant/wpa_supplicant.conf

    if [ -f "/etc/dnsmasq.conf.bak" ]; then
        mv -f /etc/dnsmasq.conf.bak /etc/dnsmasq.conf
    fi

    # remove ip forwarding
    echo 0 > /proc/sys/net/ipv4/ip_forward

    # delete all iptable rules
    # if persisted, also call
    # rm /etc/iptables.ipv4.nat
    # sed -i'' '/iptables-restore/d'

    iptables -F

fi

# restart all affected services
service dhcpcd restart
ifdown wlan0
ifup wlan0
service hostapd restart
service dnsmasq restart
systemctl daemon-reload
