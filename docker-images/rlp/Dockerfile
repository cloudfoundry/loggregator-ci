FROM golang:latest as builder

COPY / /go/

ENV CGO_ENABLED=0 \
    GOOS=linux \
    GOARCH=amd64

RUN go build \
    -a \
    -installsuffix nocgo \
    -o /rlp \
    code.cloudfoundry.org/loggregator/rlp

FROM alpine:latest

ENV RLP_CERT_FILE="/srv/certs/rlp.crt" \
    RLP_KEY_FILE="/srv/certs/rlp.key" \
    RLP_CA_FILE="/srv/certs/ca.crt" \
    RLP_METRIC_EMITTER_INTERVAL="1m" \
    RLP_PORT="8082" \
    RLP_PPROF_PORT="6060" \
    RLP_HEALTH_ADDR=":6061" \
    AGENT_ADDR="localhost:3458"

EXPOSE 8082 \
       6060 \
       6061

COPY --from=builder /rlp /srv/
WORKDIR /srv
CMD [ "/srv/rlp" ]
