#!/bin/bash

function set_globals {
    pipeline=$1
}

function validate {
    if [ "$pipeline" = "-h" ] || [ "$pipeline" = "--help" ] || [ -z "$pipeline" ]; then
        print_usage
        exit 1
    fi
}

function set_pipeline {
    echo setting pipeline for "$1"
    fly -t loggregator set-pipeline -p "$1" \
        -c "pipelines/$1.yml" \
        -l ~/workspace/deployments-loggregator/shared-secrets.yml \
        -l ~/workspace/loggregator-ci/scripts.yml
}

function sync_fly {
    fly -t loggregator sync
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
