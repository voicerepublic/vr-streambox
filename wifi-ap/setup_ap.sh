echo "Ethernet cable connected. Setting up Wireless Access Point"

#if ! grep -q "$DHCPCD" /etc/dhcpcd.conf; then
#    echo $DHCPCD >> /etc/dhcpcd.conf
#fi

sed -e "s/SSID/$SSID_AP/" -e "s/PASSWORD/$PASSWORD_AP/" \
    $DIR/hostapd.conf.template > /etc/hostapd/hostapd.conf

sed -i'' -e 's:#DAEMON_CONF="":DAEMON_CONF="/etc/hostapd/hostapd.conf":' /etc/default/hostapd

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

ifup wlan0
service hostapd start
service dnsmasq start
