FROM golang:latest as builder

COPY / /go/

ENV CGO_ENABLED=0 \
    GOOS=linux \
    GOARCH=amd64

RUN go build \
    -a \
    -installsuffix nocgo \
    -o /log-cache-emitter \
    code.cloudfoundry.org/loggregator-tools/log-cache-emitter

FROM alpine:latest

ENV LOG_CACHE_ADDR=log-cache:8080 \
    CA_PATH="/srv/log-cache-emitter/certs/ca.crt" \
    CERT_PATH="/srv/log-cache-emitter/certs/log-cache.crt" \
    KEY_PATH="/srv/log-cache-emitter/certs/log-cache.key"

RUN mkdir -p /srv/log-cache-emitter/bin
COPY --from=builder /log-cache-emitter /srv/log-cache-emitter/bin/log-cache-emitter
WORKDIR /srv/log-cache-emitter/
CMD [ "/srv/log-cache-emitter/bin/log-cache-emitter" ]
