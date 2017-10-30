FROM alpine:latest

ENV ROUTER_CA_FILE="/srv/trafficcontroller/certs/ca.crt"
ENV ROUTER_CERT_FILE="/srv/trafficcontroller/certs/trafficcontroller.crt"
ENV ROUTER_KEY_FILE="/srv/trafficcontroller/certs/trafficcontroller.key"
ENV TRAFFIC_CONTROLLER_IP="trafficcontroller.local"
ENV TRAFFIC_CONTROLLER_OUTGOING_DROPSONDE_PORT="8081"
ENV TRAFFIC_CONTROLLER_PPROF_PORT="0"
ENV TRAFFIC_CONTROLLER_HEALTH_ADDR="127.0.0.1:14825"
ENV TRAFFIC_CONTROLLER_API_HOST="127.0.0.1"
ENV TRAFFIC_CONTROLLER_SYSTEM_DOMAIN="127.0.0.1"
ENV TRAFFIC_CONTROLLER_METRIC_EMITTER_INTERVAL="1m"
ENV TRAFFIC_CONTROLLER_DISABLE_ACCESS_CONTROL="true"

# A container must configure the following addresses.
ENV AGENT_UDP_ADDRESS=""
ENV AGENT_GRPC_ADDRESS=""
ENV ROUTER_ADDRS=""

WORKDIR /srv/trafficcontroller/
RUN mkdir -p /srv/trafficcontroller/bin && \
    mkdir -p /srv/trafficcontroller/certs
COPY trafficcontroller /srv/trafficcontroller/bin/trafficcontroller
COPY trafficcontroller.crt /srv/trafficcontroller/certs/trafficcontroller.crt
COPY trafficcontroller.key /srv/trafficcontroller/certs/trafficcontroller.key
COPY ca.crt /srv/trafficcontroller/certs/ca.crt

CMD [ "/srv/trafficcontroller/bin/trafficcontroller" ]
