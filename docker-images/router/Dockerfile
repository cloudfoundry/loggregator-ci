FROM alpine:latest

ENV ROUTER_CERT_FILE="/srv/router/certs/router.crt" \
    ROUTER_KEY_FILE="/srv/router/certs/router.key" \
    ROUTER_CA_FILE="/srv/router/certs/ca.crt" \
    ROUTER_MAX_RETAINED_LOG_MESSAGES="10000" \
    ROUTER_CONTAINER_METRIC_TTL_SECONDS="120" \
    ROUTER_SINK_INACTIVITY_TIMEOUT_SECONDS="3600" \
    ROUTER_PORT="8082" \
    ROUTER_PPROF_PORT="6060" \
    ROUTER_HEALTH_ADDR=":6061" \
    AGENT_UDP_ADDRESS="3457" \
    AGENT_GRPC_ADDRESS="3458"

EXPOSE 8082 \
       6060 \
       6061

RUN mkdir -p /srv/router/bin
COPY router /srv/router/bin/router
WORKDIR /srv/router/
CMD [ "/srv/router/bin/router" ]
