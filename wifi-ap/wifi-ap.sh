#!/bin/sh


#ifplugd -b -f -u 5 -d 5 -r /home/pi/streambox/wifi-ap/wifi-ap.sh

DIR="$(cd "$(dirname "$0")" && pwd)"

IFUPDOWN_BASE="/etc/network"
IFUPDOWN_DIRS="if-up.d if-down.d if-post-down.d if-post-up.d if-pre-up.d if-pre-down.d"

SSID_INTERNAL="VR Streaming"
PASSWORD_INTERNAL="streamsdocometrue"

SSID_AP=$SSID_INTERNAL
PASSWORD_AP=$PASSWORD_INTERNAL

SSID_CUSTOM="VR Hotspot"
PASSWORD_CUSTOM=$(cat /proc/cpuinfo | grep Serial | cut -d ' ' -f 2 | sed s/^0*//)

main(){

    cp $DIR/interfaces /etc/network/interfaces
    for directory in $IFUPDOWN_DIRS; do
        mkdir -p "$IFUPDOWN_BASE/$directory"
        ln -sf $DIR/z_streambox-ifupdown.sh "$IFUPDOWN_BASE/$directory/zstreambox"
    done

    if [ "$1" == "init" ]; then
        exit 0
    fi

    ifdown wlan0

    if interface_connected eth0 https://voicerepublic.com; then
        setup_access_point
    else
        setup_wifi_connection
    fi
}

interface_connected() {
    INTERFACE=$1
    URL=$2
    OPERSTATE=$(cat /sys/class/net/$INTERFACE/operstate)
    OPTIONS="--interface $INTERFACE --head --silent $URL"
    PATTERN="(2|3)0[0-9] (OK|Found)"
    if [ "$OPERSTATE" = "up" ]
    then
        while [ -z "$(ifconfig $INTERFACE | egrep 'inet addr:([0-9]{1,3}\.){3}[0-9]{1,3}')" ]
        do
            sleep 1
        done
        if curl $OPTIONS | egrep "$PATTERN" > /dev/null
           then
               return 0
        fi
    fi
    return 1
}

setup_access_point() {

    echo "Ethernet cable connected. Setting up Wireless Access Point"

    sed -e "s/SSID/$SSID_AP/" -e "s/PASSWORD/$PASSWORD_AP/" \
        $DIR/hostapd.conf.template > /etc/hostapd/hostapd.conf

    #sed -i'' -e 's:#DAEMON_CONF="":DAEMON_CONF="/etc/hostapd/hostapd.conf":' /etc/default/hostapd

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

    ifup wlan0=ap
}

setup_wifi_connection(){

    echo "No Ethernet connected. Trying to connect to Wireless Access Point"

    #sed -i'' -e 's:DAEMON_CONF="/etc/hostapd/hostapd.conf":#DAEMON_CONF="":' /etc/default/hostapd

    sed -e "s/SSID_INTERNAL/$SSID_INTERNAL/" -e "s/PASSWORD_INTERNAL/$PASSWORD_INTERNAL/" \
        -e "s/SSID_CUSTOM/$SSID_CUSTOM/" -e "s/PASSWORD_CUSTOM/$PASSWORD_CUSTOM/" \
        $DIR/wpa_supplicant.conf.template > /etc/wpa_supplicant/wpa_supplicant.conf

    if [ -f "/etc/dnsmasq.conf.bak" ]; then
        mv -f /etc/dnsmasq.conf.bak /etc/dnsmasq.conf
    fi

    # remove ip forwarding
    echo 0 > /proc/sys/net/ipv4/ip_forward

    # delete all iptable rules
    # if persisted, also call
    # rm /etc/iptables.ipv4.nat
    # sed -i'' '/iptables-restore/d' /etc/rc.local

    iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE >/dev/null 2>&1
    iptables -D FORWARD -i eth0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT >/dev/null 2>&1
    iptables -D FORWARD -i wlan0 -o eth0 -j ACCEPT >/dev/null 2>&1

    ifup wlan0
}

stop_services(){
    ifdown wlan0
}

main "$@"