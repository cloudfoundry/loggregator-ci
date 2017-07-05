#!/bin/bash

set -e

function set_globals {
    env=$1
    pipeline=$2
}

function validate {
    echo $env env
    echo $pipeline pipeline
    if [ -z "$env" ] || [ -z "$pipeline" ]; then
        echo "usage: $0 <environment> <pipeline | all>"
        exit 1
    fi
}

function loggregator_set_pipeline {
    local pipeline_name="$1"
    echo setting pipeline for "$pipeline_name"
    fly -t loggregator set-pipeline -p "$pipeline_name" \
        -c "pipelines/loggregator/$pipeline_name.yml" \
        -l ~/workspace/loggregator-credentials/shared-secrets.yml \
        -l ~/workspace/loggregator-ci/scripts.yml
}

function lakitu_set_pipeline {
    local pipeline_name="$1"
    echo setting pipeline for "$pipeline_name"
    fly -t lakitu set-pipeline -p "$pipeline_name" \
        -c "pipelines/lakitu/$pipeline_name.yml" \
        -l ~/workspace/secrets-prod/ci/ci_bosh_secrets.yml \
        -l ~/workspace/secrets-prod/ci/ci_github_resources.yml
}

function sync_fly {
    fly -t "$env" sync
}

function set_pipelines {
    if [ "$pipeline" = all ]; then
        for pipeline_file in $(ls "pipelines/$env"); do
            "${env}_set_pipeline" "${pipeline_file%.yml}"
        done
        exit 0
    fi

    "${env}_set_pipeline" "$pipeline"
}

function main {
    set_globals $1 $2
    validate
    sync_fly
    set_pipelines
}
main $1 $2
