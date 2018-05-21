FROM golang:latest as builder

COPY / /go/

ENV CGO_ENABLED=0 \
    GOOS=linux \
    GOARCH=amd64

RUN go build \
    -a \
    -installsuffix nocgo \
    -o /router \
    code.cloudfoundry.org/loggregator/router

FROM alpine:latest

ENV ROUTER_CERT_FILE="/srv/certs/router.crt" \
    ROUTER_KEY_FILE="/srv/certs/router.key" \
    ROUTER_CA_FILE="/srv/certs/ca.crt" \
    ROUTER_MAX_RETAINED_LOG_MESSAGES="10000" \
    ROUTER_CONTAINER_METRIC_TTL_SECONDS="120" \
    ROUTER_SINK_INACTIVITY_TIMEOUT_SECONDS="3600" \
    ROUTER_PORT="8082" \
    ROUTER_PPROF_PORT="6060" \
    ROUTER_HEALTH_ADDR=":6061" \
    AGENT_UDP_ADDRESS="localhost:3457" \
    AGENT_GRPC_ADDRESS="localhost:3458"

EXPOSE 8082 \
       6060 \
       6061

COPY --from=builder /router /srv/
WORKDIR /srv
CMD [ "/srv/router" ]
