FROM golang:latest as builder

COPY / /go/

ENV CGO_ENABLED=0 \
    GOOS=linux \
    GOARCH=amd64

RUN go build \
    -a \
    -installsuffix nocgo \
    -o /emitter \
    code.cloudfoundry.org/loggregator-tools/emitter

FROM alpine:latest

ENV CERT="/srv/certs/agent.crt" \
    KEY="/srv/certs/agent.key" \
    CA="/srv/certs/ca.crt" \
    TARGET="localhost:3458" \
    RATE="1s"

COPY --from=builder /emitter /srv/
WORKDIR /srv
CMD [ "/srv/emitter" ]
