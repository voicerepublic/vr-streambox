#!/bin/sh

if [ "$IFACE" != "wlan0" ]; then
    exit 0
fi

try_connecting_to_wifi(){
    [ "$(iwgetid -r)" ] && return 0
    INTERFACE=$1
    TRIES=0
    until [ "$(iwgetid -r)" ]; do
        sleep $(($TRIES * 2))
        wpa_cli scan
        TRIES="$((($TRIES + 1)))"
        if [ "$TRIES" -ge "5" ]; then
            return 1
        fi
    done
    dhclient "$INTERFACE"
}


case "$MODE" in
    start)
        case "$PHASE" in
            pre-up)
            ;;
            post-up)
                case "$LOGICAL" in
                    ap)
                        service dnsmasq start
                        ;;
                    *)
                        try_connecting_to_wifi $IFACE
                        ;;
                esac
                ;;
        esac
        ;;

    stop)
        case "$PHASE" in
            pre-down)
                service dnsmasq stop
                ;;
            post-down)
                dhclient -r "$IFACE"
                ;;
        esac
        ;;
esac

exit 0
