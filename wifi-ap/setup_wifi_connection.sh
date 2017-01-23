echo "No Ethernet connected. Trying to connect to Wireless Access Point"

#sed -i'' "/$DHCPCD/d" /etc/dhcpcd.conf

sed -i'' -e 's:DAEMON_CONF="/etc/hostapd/hostapd.conf":#DAEMON_CONF="":' /etc/default/hostapd

sed -e "s/SSID_INTERNAL/$SSID_INTERNAL/" -e "s/PASSWORD_INTERNAL/$PASSWORD_INTERNAL/" \
    -e "s/SSID_CUSTOM/$SSID_CUSTOM/" -e "s/PASSWORD_CUSTOM/$PASSWORD_CUSTOM/" \
    $DIR/interfaces/wpa_supplicant.conf.template > /etc/wpa_supplicant/wpa_supplicant.conf

if [ -f "/etc/dnsmasq.conf.bak" ]; then
    mv -f /etc/dnsmasq.conf.bak /etc/dnsmasq.conf
fi

# remove ip forwarding
echo 0 > /proc/sys/net/ipv4/ip_forward

# delete all iptable rules
# if persisted, also call
# rm /etc/iptables.ipv4.nat
# sed -i'' '/iptables-restore/d'

iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
iptables -D FORWARD -i eth0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -D FORWARD -i wlan0 -o eth0 -j ACCEPT

ifup wlan0
wpa_cli scan
