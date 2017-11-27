FROM alpine:latest

ENV RLP_CERT_FILE="/srv/rlp/certs/rlp.crt" \
    RLP_KEY_FILE="/srv/rlp/certs/rlp.key" \
    RLP_CA_FILE="/srv/rlp/certs/ca.crt" \
    RLP_METRIC_EMITTER_INTERVAL="1m" \
    RLP_PORT="8082" \
    RLP_PPROF_PORT="6060" \
    RLP_HEALTH_ADDR=":6061" \
    AGENT_ADDR="localhost:3458"

EXPOSE 8082 \
       6060 \
       6061

RUN mkdir -p /srv/rlp/bin
COPY rlp /srv/rlp/bin/rlp
WORKDIR /srv/rlp/
CMD [ "/srv/rlp/bin/rlp" ]
