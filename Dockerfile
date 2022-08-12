FROM alpine:3.16.2

RUN apk --no-cache add \
    bash \
    tini \
    iptables \
    ip6tables

COPY configure-firewall.sh /bin

ENV PUBLIC "FALSE"

ENTRYPOINT ["/sbin/tini", "--"]

CMD ["/bin/configure-firewall.sh"]
