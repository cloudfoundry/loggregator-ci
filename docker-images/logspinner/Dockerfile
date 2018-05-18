FROM golang:latest as builder

COPY / /go/

ENV CGO_ENABLED=0 \
    GOOS=linux \
    GOARCH=amd64

RUN go build \
    -a \
    -installsuffix nocgo \
    -o /logspinner \
    code.cloudfoundry.org/loggregator-tools/logspinner

FROM alpine:latest

ENV PORT=8080

COPY --from=builder /logspinner /srv/
WORKDIR /srv
CMD [ "/srv/logspinner" ]
