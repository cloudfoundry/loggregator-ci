#!/bin/bash

fly --target=loggr expose-pipeline --pipeline=products
fly --target=loggr expose-pipeline --pipeline=loggregator
fly --target=loggr expose-pipeline --pipeline=cf-syslog-drain
fly --target=loggr expose-pipeline --pipeline=go-packages
