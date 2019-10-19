#!/bin/sh

# https://github.com/vitobotta/docker-firewall
# https://www.lammertbies.nl/comm/info/iptables.html
# https://medium.com/@ebuschini/iptables-and-docker-95e2496f0b45

PUBLIC=${PUBLIC:-FALSE}

cleanup() {
    echo "Remove chains..."
    for CHAIN in Icmp_Limit Enemies Bogus ; do
        for MAIN_CHAIN in INPUT FORWARD ; do
            while true ; do
                iptables -t filter -D ${MAIN_CHAIN} -j ${CHAIN} || break
            done
        done
        iptables -t filter -F ${CHAIN}
        iptables -t filter -X ${CHAIN}
    done
    echo "OK"
    exit 0
}
trap 'cleanup' 0 1 2 3 9 15

create_chains() {
    echo "Create chains..."
    for CHAIN in Icmp_Limit Enemies Bogus ; do
        # create them for the filter table
        iptables -N ${CHAIN}
        for MAIN_CHAIN in INPUT FORWARD ; do
            iptables -t filter -I ${MAIN_CHAIN} -j ${CHAIN}
        done
    done
    echo "OK"
}

configure_bogus() {
    for TABLE in filter ; do    
        iptables -t ${TABLE} -A Bogus -p tcp -m tcp --tcp-flags SYN,FIN SYN,FIN -j DROP
        iptables -t ${TABLE} -A Bogus -p tcp -m tcp --tcp-flags SYN,RST SYN,RST -j DROP
        iptables -t ${TABLE} -A Bogus -p tcp ! --syn -m state --state NEW -j DROP
        iptables -t ${TABLE} -A Bogus -p tcp --tcp-flags ALL ALL -j DROP
        iptables -t ${TABLE} -A Bogus -p tcp --tcp-flags ALL NONE -j DROP
        if [[ ${PUBLIC} == "TRUE" ]] ; then
            iptables -t ${TABLE} -A Bogus -s 169.254.0.0/16 -j DROP
            iptables -t ${TABLE} -A Bogus -s 172.16.0.0/12 -j DROP
            iptables -t ${TABLE} -A Bogus -s 192.0.2.0/24 -j DROP
            iptables -t ${TABLE} -A Bogus -s 192.168.0.0/16 -j DROP
            iptables -t ${TABLE} -A Bogus -s 224.0.0.0/3 -j DROP            
            iptables -t ${TABLE} -A Bogus -s 10.0.0.0/8 -j DROP
            iptables -t ${TABLE} -A Bogus -s 0.0.0.0/8 -j DROP
            iptables -t ${TABLE} -A Bogus -s 127.0.0.0/8 ! -i lo -j DROP
        fi
    done
}

configure_enemies() {
    for TABLE in filter ; do
        iptables -t ${TABLE} -A Enemies  -m recent --name psc --update --seconds 60 -j DROP
        iptables -t ${TABLE} -A Enemies ! -i lo -m tcp -p tcp --dport 1433  -m recent --name psc --set -j DROP
        iptables -t ${TABLE} -A Enemies ! -i lo -m tcp -p tcp --dport 3306  -m recent --name psc --set -j DROP
        iptables -t ${TABLE} -A Enemies ! -i lo -m tcp -p tcp --dport 8086  -m recent --name psc --set -j DROP
        iptables -t ${TABLE} -A Enemies ! -i lo -m tcp -p tcp --dport 10000 -m recent --name psc --set -j DROP
    done
}

configure_icmp_limit() {
    for TABLE in filter ; do
        iptables -t ${TABLE} -A Icmp_Limit -p icmp --icmp-type any -m limit --limit 2/second -j RETURN
        iptables -t ${TABLE} -A Icmp_Limit -p icmp --icmp-type any -j DROP
    done
}

keep_running() {
    while true ; do
        sleep 1 &
        wait $!
    done
}

main() {
    create_chains
    configure_bogus
    configure_enemies
    configure_icmp_limit
    keep_running
}

main
exit 0