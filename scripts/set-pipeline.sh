#!/bin/bash

pipeline_name=$1

if [ -z "$pipeline_name" ]; then
    echo "usage: $0 <pipeline_name> | all"
    exit 1
fi

function set_pipeline {
    echo setting pipeline for "$1"
    fly -t loggregator set-pipeline -p "$1" \
        -c pipelines/"$1".yml \
        -l ~/workspace/loggregator-credentials/shared-secrets.yml \
        -l ~/workspace/loggregator-ci/scripts.yml
}

if [ "$pipeline_name" = all ]; then
    for pipeline_file in $(ls pipelines); do
        set_pipeline "${pipeline_file%.yml}"
    done
else
    set_pipeline "$pipeline_name"
fi
