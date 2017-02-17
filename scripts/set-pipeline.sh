#!/bin/bash

pipeline_name=$1

if [ -z "$pipeline_name" ]; then
    echo "usage: $0 <pipeline_name>"
    exit 1
fi

if [ ! -e ~/workspace/loggregator-credentials/$pipeline_name.yml ]; then
    fly -t loggregator set-pipeline -p "$pipeline_name" \
        -c pipelines/"$pipeline_name".yml \
        -l ~/workspace/loggregator-credentials/shared-secrets.yml \
        -l ~/workspace/loggregator-ci/scripts.yml
else
    fly -t loggregator set-pipeline -p "$pipeline_name" \
        -c pipelines/"$pipeline_name".yml \
        -l ~/workspace/loggregator-credentials/shared-secrets.yml \
        -l ~/workspace/loggregator-credentials/$pipeline_name.yml \
        -l ~/workspace/loggregator-ci/scripts.yml
fi
