#!/bin/bash

fly --target=loggregator expose-pipeline --pipeline=products
fly --target=loggregator expose-pipeline --pipeline=go-packages
fly --target=loggregator expose-pipeline --pipeline=bosh-hm-forwarder
fly --target=loggregator expose-pipeline --pipeline=regression
