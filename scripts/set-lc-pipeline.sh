#!/bin/bash

function set_globals {
    pipeline=$1
    TARGET="${TARGET:-loggregator}"
}

function validate {
    if [ "$pipeline" = "-h" ] || [ "$pipeline" = "--help" ] || [ -z "$pipeline" ]; then
        print_usage
        exit 1
    fi
}

function set_pipeline {
    # TODO - this is an obviously nasty way of parsing and injecting
    # credentials. Replace by modifying task yamls to accept deployment
    # vars files directly ASAP.
    CF_ADMIN_PASSWORD=`yq r ~/workspace/deployments-loggregator/gcp/lime/deployment-vars.yml cf_admin_password`
    BLACKBOX_SECRET=`yq r ~/workspace/deployments-loggregator/gcp/lime/deployment-vars.yml blackbox_client_secret`
    LCATS_SECRET=`yq r ~/workspace/deployments-loggregator/gcp/lime/deployment-vars.yml lcats_client_secret`
    DATADOG_FORWARDER_SECRET=`yq r ~/workspace/deployments-loggregator/gcp/lime/deployment-vars.yml datadog_forwarder_client_secret`

    echo setting pipeline for "$1"
    fly -t $TARGET set-pipeline -p "$1" \
        -c "pipelines/$1.yml" \
        -l ~/workspace/deployments-loggregator/shared-secrets.yml \
        -v "cf_admin_password=$CF_ADMIN_PASSWORD" \
        -v "blackbox_client_secret=$BLACKBOX_SECRET" \
        -v "lcats_client_secret=$LCATS_SECRET" \
        -v "datadog_forwarder_client_secret=$DATADOG_FORWARDER_SECRET" \
        -l ~/workspace/loggregator-ci/scripts.yml
}

function sync_fly {
    fly -t $TARGET sync
}

function set_pipelines {
    if [ "$pipeline" = all ]; then
        for pipeline_file in $(ls "pipelines/"); do
            set_pipeline "${pipeline_file%.yml}"
        done
        exit 0
    fi

    set_pipeline "$pipeline"
}

function print_usage {
    echo "usage: $0 <pipeline | all>"
}

function main {
    set_globals $1
    validate
    sync_fly
    set_pipelines
}
main $1 $2
