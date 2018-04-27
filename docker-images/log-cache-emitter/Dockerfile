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
    CA_PATH="/srv/certs/ca.crt" \
    CERT_PATH="/srv/certs/log-cache.crt" \
    KEY_PATH="/srv/certs/log-cache.key"

RUN mkdir -p /srv
COPY --from=builder /log-cache-emitter /srv/log-cache-emitter
WORKDIR /srv
CMD [ "/srv/log-cache-emitter" ]
