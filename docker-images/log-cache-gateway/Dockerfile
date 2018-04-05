FROM golang:latest as builder

COPY / /go/

ENV CGO_ENABLED=0 \
    GOOS=linux \
    GOARCH=amd64

RUN go build \
    -a \
    -installsuffix nocgo \
    -o /log-cache-gateway \
    code.cloudfoundry.org/log-cache/cmd/gateway

FROM alpine:latest

ENV ADDR=localhost:8081 \
    LOG_CACHE_ADDR=log-cache:8080 \
    GROUP_READER_ADDR=log-cache-group-reader:8080 \
    CA_PATH="/srv/log-cache-gateway/certs/ca.crt" \
    CERT_PATH="/srv/log-cache-gateway/certs/log-cache.crt" \
    KEY_PATH="/srv/log-cache-gateway/certs/log-cache.key"

EXPOSE 8081

RUN mkdir -p /srv/log-cache-gateway/bin
COPY --from=builder /log-cache-gateway /srv/log-cache-gateway/bin/log-cache-gateway
WORKDIR /srv/log-cache-gateway/
CMD [ "/srv/log-cache-gateway/bin/log-cache-gateway" ]
