#!/bin/sh
CGO_ENABLED=0 \
GOOS=linux \
GOARCH=amd64 \
    go build \
    -a \
    -installsuffix nocgo \
    -o ./rlp \
    code.cloudfoundry.org/loggregator/rlp
