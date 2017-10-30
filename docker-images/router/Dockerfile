FROM alpine:latest

ENV ROUTER_CERT_FILE="/srv/router/certs/router.crt"
ENV ROUTER_KEY_FILE="/srv/router/certs/router.key"
ENV ROUTER_CA_FILE="/srv/router/certs/ca.crt"
ENV ROUTER_MAX_RETAINED_LOG_MESSAGES="10000"
ENV ROUTER_CONTAINER_METRIC_TTL_SECONDS="120"
ENV ROUTER_SINK_INACTIVITY_TIMEOUT_SECONDS="3600"
ENV ROUTER_PPROF_PORT="0"
ENV ROUTER_PORT="8082"

# A container must configure the following addresses.
ENV ROUTER_HEALTH_ADDR=""
ENV AGENT_UDP_ADDRESS=""
ENV AGENT_GRPC_ADDRESS=""

WORKDIR /srv/router/
RUN mkdir -p /srv/router/bin && \
    mkdir -p /srv/router/certs
COPY router /srv/router/bin/router
COPY router.crt /srv/router/certs/router.crt
COPY router.key /srv/router/certs/router.key
COPY ca.crt /srv/router/certs/ca.crt

CMD [ "/srv/router/bin/router" ]
