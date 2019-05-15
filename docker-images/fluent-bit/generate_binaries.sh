#!/usr/bin/env bash
set -ex

docker build . -t fluentbit-loggr-plugin
docker run -v /tmp:/tmp \
    fluentbit-loggr-plugin:latest \
    /bin/cp -- /fluent-bit/bin/fluent-bit /tmp

echo "Copied fluent-bit binary to /tmp"