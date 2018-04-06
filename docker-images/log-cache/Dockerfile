FROM golang:latest as builder

COPY / /go/

ENV CGO_ENABLED=0 \
    GOOS=linux \
    GOARCH=amd64

RUN go build \
    -a \
    -installsuffix nocgo \
    -o /logcache \
    code.cloudfoundry.org/log-cache/cmd/logcache

FROM alpine:latest

ENV ADDR=:8080 \
    CA_PATH="/srv/log-cache/certs/ca.crt" \
    CERT_PATH="/srv/log-cache/certs/log-cache.crt" \
    KEY_PATH="/srv/log-cache/certs/log-cache.key"

EXPOSE 8080

RUN mkdir -p /srv/log-cache/bin
COPY --from=builder /logcache /srv/log-cache/bin/logcache
WORKDIR /srv/log-cache/
CMD [ "/srv/log-cache/bin/logcache" ]
