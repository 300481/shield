FROM alpine:3.11.2

RUN apk --no-cache add \
    tini \
    iptables

COPY configure-firewall.sh /bin

ENV PUBLIC "FALSE"

ENTRYPOINT ["/sbin/tini", "--"]

CMD ["/bin/configure-firewall.sh"]