#!/bin/sh
CGO_ENABLED=0 \
GOOS=linux \
GOARCH=amd64 \
    go build \
    -a \
    -installsuffix nocgo \
    -o ./router \
    code.cloudfoundry.org/loggregator/router
