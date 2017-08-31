#!/bin/bash

fly --target=loggregator expose-pipeline --pipeline=loggregator
fly --target=loggregator expose-pipeline --pipeline=go-loggregator
fly --target=loggregator expose-pipeline --pipeline=statsd-injector
fly --target=loggregator expose-pipeline --pipeline=cf-syslog-drain
fly --target=loggregator expose-pipeline --pipeline=bosh-hm-forwarder
fly --target=loggregator expose-pipeline --pipeline=submodules
