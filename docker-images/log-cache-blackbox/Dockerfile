FROM golang:latest as builder

COPY / /go/

ENV CGO_ENABLED=0 \
    GOOS=linux \
    GOARCH=amd64

RUN go build \
    -a \
    -installsuffix nocgo \
    -o /log-cache-blackbox \
    code.cloudfoundry.org/loggregator-tools/log-cache-blackbox

FROM alpine:latest

COPY --from=builder /log-cache-blackbox /srv/
WORKDIR /srv
CMD [ "/srv/log-cache-blackbox" ]
