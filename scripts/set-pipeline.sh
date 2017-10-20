#!/bin/bash

function set_globals {
    pipeline=$1
}

function validate {
    echo $pipeline pipeline
    if [ -z "$pipeline" ]; then
        echo "usage: $0 <pipeline | all>"
        exit 1
    fi
}

function set_pipeline {
    echo setting pipeline for "$pipeline"
    fly -t loggregator set-pipeline -p "$pipeline" \
        -c "pipelines/$pipeline.yml" \
        -l ~/workspace/deployments-loggregator/shared-secrets.yml \
        -l ~/workspace/loggregator-ci/scripts.yml
}

function sync_fly {
    fly -t loggregator sync
}

function set_pipelines {
    if [ "$pipeline" = all ]; then
        for pipeline_file in $(ls "pipelines/"); do
            "${env}_set_pipeline" "${pipeline_file%.yml}"
        done
        exit 0
    fi

    set_pipeline "$pipeline"
}

function main {
    set_globals $1
    validate
    sync_fly
    set_pipelines
}
main $1 $2
