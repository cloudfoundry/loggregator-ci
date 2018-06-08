FROM golang:latest as builder

COPY / /go/

ENV CGO_ENABLED=0 \
    GOOS=linux \
    GOARCH=amd64

RUN go build \
    -a \
    -installsuffix nocgo \
    -o /syslog-nozzle \
    code.cloudfoundry.org/loggregator-tools/syslog-nozzle

FROM alpine:latest

ENV LOGS_PROVIDER_CERT_FILE_PATH="/srv/certs/rlp.crt" \
    LOGS_PROVIDER_KEY_FILE_PATH="/srv/certs/rlp.key" \
    LOGS_PROVIDER_CA_FILE_PATH="/srv/certs/ca.crt" \
    METRICS_ADDR=":9100"

COPY --from=builder /syslog-nozzle /srv/
WORKDIR /srv
CMD [ "/srv/syslog-nozzle" ]
