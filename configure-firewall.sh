#!/bin/sh

# https://github.com/vitobotta/docker-firewall
# https://www.lammertbies.nl/comm/info/iptables.html
# https://medium.com/@ebuschini/iptables-and-docker-95e2496f0b45
# https://www.rackaid.com/blog/how-to-block-ssh-brute-force-attacks/
# https://www.linux-magazin.de/ausgaben/2007/04/hausverbot/
# https://www.thegeekstuff.com/2011/06/iptables-rules-examples/
# http://go2linux.garron.me/linux/2010/04/stop-brute-force-attacks-these-iptables-examples-732/
# https://netfilter.org/documentation/HOWTO/de/packet-filtering-HOWTO-7.html
# https://www.cyberciti.biz/tips/linux-iptables-10-how-to-block-common-attack.html

: ${PORTSCAN:=21,22,23,135,389,636,1433,3306,5432,8086,10000,25565}
: ${SSH_PORT:=65000}

trap cleanup 1 2 3 9 15
cleanup() {
    echo -n "Remove chains..."
    for CHAIN in LIMITS PORTSCAN BOGUS LOGDROP ; do
        for MAIN_CHAIN in INPUT FORWARD ; do
            [[ ${CHAIN} != "LOGDROP" ]] && iptables -D ${MAIN_CHAIN} -j ${CHAIN}
        done
        iptables -F ${CHAIN}
        iptables -X ${CHAIN}
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

create_chains() {
    echo -n "Create chains..."
    for CHAIN in LIMITS PORTSCAN BOGUS LOGDROP ; do
        # create them for the filter table
        iptables -N ${CHAIN}
        for MAIN_CHAIN in INPUT FORWARD ; do
            [[ ${CHAIN} != "LOGDROP" ]] && iptables -I ${MAIN_CHAIN} -j ${CHAIN}
        done
    done
    echo "OK"
}

configure_LOGDROP() {
    iptables -A LOGDROP -m limit --limit 12/min -j LOG --log-prefix "IPTables Packet Dropped: " --log-level 7
    iptables -A LOGDROP -j DROP
}

configure_BOGUS() {
    # drop bogus packets
    iptables -A BOGUS -p tcp -m tcp --tcp-flags SYN,FIN SYN,FIN -j LOGDROP
    iptables -A BOGUS -p tcp -m tcp --tcp-flags SYN,RST SYN,RST -j LOGDROP
    iptables -A BOGUS -p tcp ! --syn -m state --state NEW -j LOGDROP
    # drop XMAS
    iptables -A BOGUS -p tcp --tcp-flags ALL ALL -j LOGDROP
    iptables -A BOGUS -p tcp --tcp-flags ALL NONE -j LOGDROP
    # drop fragments
    iptables -A BOGUS -f -j LOGDROP
    # drop private source IPs on public interface
#    if public ; then
#        iptables -A BOGUS -s 169.254.0.0/16 -j LOGDROP
#        iptables -A BOGUS -s 172.16.0.0/12 -j LOGDROP
#        iptables -A BOGUS -s 192.0.2.0/24 -j LOGDROP
#        iptables -A BOGUS -s 192.168.0.0/16 -j LOGDROP
#        iptables -A BOGUS -s 10.0.0.0/8 -j LOGDROP
#        iptables -A BOGUS -s 127.0.0.0/8 ! -i lo -j LOGDROP
#    fi
}

configure_PORTSCAN() {
    # block port scanners
    iptables -A PORTSCAN  -m recent --name psc --update --seconds 300 -j LOGDROP
    iptables -A PORTSCAN ! -i lo -m tcp -p tcp -m multiport --dports ${PORTSCAN} -m recent --name psc --set -j LOGDROP
}

configure_LIMITS() {
    # limit ping packets
    iptables -A LIMITS -p icmp --icmp-type any -m limit --limit 2/second -j RETURN
    iptables -A LIMITS -p icmp --icmp-type any -j LOGDROP
    # limit new SSH connections
    iptables -A LIMITS ! -i lo -p tcp --dport ${SSH_PORT} -m state --state NEW -m recent --update --seconds 600 --hitcount 10 -j LOGDROP
    iptables -A LIMITS ! -i lo -p tcp --dport ${SSH_PORT} -m state --state NEW -m recent --set
    iptables -A LIMITS ! -i lo -p tcp --dport ${SSH_PORT} -m state --state NEW -m limit --limit 5/minute -j RETURN
    iptables -A LIMITS ! -i lo -p tcp --dport ${SSH_PORT} -m state --state NEW -j LOGDROP
}

keep_running() {
    tail -f /dev/null
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