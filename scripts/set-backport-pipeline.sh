#!/bin/bash

function set_globals {
    product=$1
    backport="$1-$2"
    TARGET="${TARGET:-loggregator}"
}

function validate {
    if [ "$product" = "-h" ] || [ "$product" = "--help" ] || [ -z "$product" ]; then
        print_usage
        exit 1
    fi
}

function set_pipeline {
    echo setting pipeline for $backport
    fly -t $TARGET set-pipeline -p $backport \
        -c <(bosh int "pipelines/$product.yml" -o "pipelines/backport-ops/$backport.yml" -o "pipelines/backport-ops/env.yml")\
        -l ~/workspace/deployments-loggregator/shared-secrets.yml \
        -l ~/workspace/loggregator-ci/scripts.yml
}

function sync_fly {
    fly -t $TARGET sync
}

function print_usage {
    echo "usage: $0 <product> <version>"
}

function main {
    set_globals $1 $2
    validate
    sync_fly
    set_pipeline
}
main $1 $2
