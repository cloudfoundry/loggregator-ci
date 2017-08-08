#!/bin/bash

fly --target=loggregator expose-pipeline --pipeline=loggregator
fly --target=loggregator expose-pipeline --pipeline=go-loggregator
fly --target=loggregator expose-pipeline --pipeline=statsd-injector
fly --target=loggregator expose-pipeline --pipeline=scalable-syslog
fly --target=loggregator expose-pipeline --pipeline=bosh-hm-forwarder
