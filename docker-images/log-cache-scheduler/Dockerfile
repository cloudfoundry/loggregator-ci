FROM golang:latest as builder

COPY / /go/

ENV CGO_ENABLED=0 \
    GOOS=linux \
    GOARCH=amd64

RUN go build \
    -a \
    -installsuffix nocgo \
    -o /log-cache-scheduler \
    code.cloudfoundry.org/log-cache/cmd/scheduler

FROM alpine:latest

ENV NODE_ADDRS=log-cache:8080 \
    GROUP_READER_NODE_ADDRS=log-cache:8080 \
    CA_PATH="/srv/log-cache-scheduler/certs/ca.crt" \
    CERT_PATH="/srv/log-cache-scheduler/certs/log-cache.crt" \
    KEY_PATH="/srv/log-cache-scheduler/certs/log-cache.key"

RUN mkdir -p /srv/log-cache-scheduler/bin
COPY --from=builder /log-cache-scheduler /srv/log-cache-scheduler/bin/log-cache-scheduler
WORKDIR /srv/log-cache-scheduler/
CMD [ "/srv/log-cache-scheduler/bin/log-cache-scheduler" ]
