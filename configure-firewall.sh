#!/bin/bash

# https://github.com/vitobotta/docker-firewall
# https://www.lammertbies.nl/comm/info/ipt.html
# https://medium.com/@ebuschini/ipt-and-docker-95e2496f0b45
# https://www.rackaid.com/blog/how-to-block-ssh-brute-force-attacks/
# https://www.linux-magazin.de/ausgaben/2007/04/hausverbot/
# https://www.thegeekstuff.com/2011/06/ipt-rules-examples/
# http://go2linux.garron.me/linux/2010/04/stop-brute-force-attacks-these-ipt-examples-732/
# https://netfilter.org/documentation/HOWTO/de/packet-filtering-HOWTO-7.html
# https://www.cyberciti.biz/tips/linux-ipt-10-how-to-block-common-attack.html

: ${PORTSCAN:=21,22,23,135,389,636,1433,3306,5432,8086,10000,25565}
: ${SSH_PORT:=65000}
: ${INTERFACE:=eth0}

trap cleanup 1 2 3 9 15
cleanup() {
    echo -n "Remove chains..."
    for CHAIN in LIMITS PORTSCAN BOGUS LOGDROP ; do
        for MAIN_CHAIN in INPUT FORWARD ; do
            [[ ${CHAIN} != "LOGDROP" ]] && ipt -D ${MAIN_CHAIN} -j ${CHAIN}
        done
        ipt -F ${CHAIN}
        ipt -X ${CHAIN}
    done
    echo "OK"
    exit 0
}

public() {
    # get IP address of default route interface
    IP=$(ip route get 8.8.8.8 | head -1 | awk '{print $7}')

    # return 1 if IP address is in private range
    if echo ${IP} | grep -Eq '^10\.' ;                       then return 1 ; fi
    if echo ${IP} | grep -Eq '^127\.' ;                      then return 1 ; fi
    if echo ${IP} | grep -Eq '^169\.254' ;                   then return 1 ; fi
    if echo ${IP} | grep -Eq '^172\.(1[6-9]|2[0-9]|3[01])' ; then return 1 ; fi
    if echo ${IP} | grep -Eq '^192\.168' ;                   then return 1 ; fi
    if echo ${IP} | grep -Eq '^192\.0\.2\.' ;                then return 1 ; fi

    # return 0 (true) if not in private range --> public IP
    return 0
}

ipt() {
    iptables $@
    ip6tables $@
}

create_chains() {
    echo -n "Create chains..."
    for CHAIN in LIMITS PORTSCAN BOGUS LOGDROP ; do
        # create them for the filter table
        ipt -N ${CHAIN}
        for MAIN_CHAIN in INPUT FORWARD ; do
            [[ ${CHAIN} != "LOGDROP" ]] && ipt -I ${MAIN_CHAIN} -j ${CHAIN}
        done
    done
    echo "OK"
}

configure_LOGDROP() {
    ipt -A LOGDROP -i ${INTERFACE} -m limit --limit 12/min -j LOG --log-prefix "IPTables Packet Dropped: " --log-level 7
    ipt -A LOGDROP -i ${INTERFACE} -j DROP
}

configure_BOGUS() {
    # drop bogus packets
    ipt -A BOGUS -i ${INTERFACE} -p tcp -m tcp --tcp-flags SYN,FIN SYN,FIN -j LOGDROP
    ipt -A BOGUS -i ${INTERFACE} -p tcp -m tcp --tcp-flags SYN,RST SYN,RST -j LOGDROP
    ipt -A BOGUS -i ${INTERFACE} -p tcp ! --syn -m state --state NEW -j LOGDROP
    # drop XMAS
    ipt -A BOGUS -i ${INTERFACE} -p tcp --tcp-flags ALL ALL -j LOGDROP
    ipt -A BOGUS -i ${INTERFACE} -p tcp --tcp-flags ALL NONE -j LOGDROP
    # drop fragments
    ipt -A BOGUS -f -j LOGDROP
    # drop private source IPs on public interface
#    if public ; then
#        ipt -A BOGUS -s 169.254.0.0/16 -j LOGDROP
#        ipt -A BOGUS -s 172.16.0.0/12 -j LOGDROP
#        ipt -A BOGUS -s 192.0.2.0/24 -j LOGDROP
#        ipt -A BOGUS -s 192.168.0.0/16 -j LOGDROP
#        ipt -A BOGUS -s 10.0.0.0/8 -j LOGDROP
#        ipt -A BOGUS -s 127.0.0.0/8 ! -i lo -j LOGDROP
#    fi
}

configure_PORTSCAN() {
    # block port scanners
    ipt -A PORTSCAN -i ${INTERFACE} -m recent --name psc --update --seconds 300 -j LOGDROP

    # copy ports to ALL_PORTS
    ALL_PORTS=${PORTSCAN}
    
    # get number of ports given
    IFS=',' read -r -a PORTCOUNT <<< $ALL_PORTS
    PORTCOUNT=${#PORTCOUNT[@]}

    # get number of port slices (ipt support only 15 for multiport)
    PORTCOUNT=$((PORTCOUNT + 14))
    PORTSLICES=$((PORTCOUNT / 15))

    # iterate over the port slices and add iptable rules
    for i in $(seq 1 ${PORTSLICES}) ; do
        APPLY_PORTS=$(cut -d, -f1-15 <<< $ALL_PORTS)
        ipt -A PORTSCAN -i ${INTERFACE} -m tcp -p tcp -m multiport --dports ${APPLY_PORTS} -m recent --name psc --set -j LOGDROP
        ALL_PORTS=${ALL_PORTS#$APPLY_PORTS,}
    done
}

configure_LIMITS() {
    # limit ping packets
    ipt -A LIMITS -i ${INTERFACE} -p icmp --icmp-type any -m limit --limit 2/second -j RETURN
    ipt -A LIMITS -i ${INTERFACE} -p icmp --icmp-type any -j LOGDROP
    # limit new SSH connections
    ipt -A LIMITS -i ${INTERFACE} -p tcp --dport ${SSH_PORT} -m state --state NEW -m recent --update --seconds 600 --hitcount 10 -j LOGDROP
    ipt -A LIMITS -i ${INTERFACE} -p tcp --dport ${SSH_PORT} -m state --state NEW -m recent --set
    ipt -A LIMITS -i ${INTERFACE} -p tcp --dport ${SSH_PORT} -m state --state NEW -m limit --limit 5/minute -j RETURN
    ipt -A LIMITS -i ${INTERFACE} -p tcp --dport ${SSH_PORT} -m state --state NEW -j LOGDROP
}

keep_running() {
    while true ; do
        sleep 1 &
        wait $!
    done
}

main() {
    create_chains
    configure_LOGDROP
    configure_BOGUS
    configure_PORTSCAN
    configure_LIMITS
    keep_running
}

main
exit 0
