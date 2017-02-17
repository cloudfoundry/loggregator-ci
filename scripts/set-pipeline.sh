#!/bin/bash

pipeline_name=$1

if [ -z "$pipeline_name" ]; then
    echo "usage: $0 <pipeline_name>"
    exit 1
fi

fly -t loggregator set-pipeline -p "$pipeline_name" \
    -c pipelines/"$pipeline_name".yml \
    -l ~/workspace/loggregator-credentials/shared-secrets.yml \
    -l ~/workspace/loggregator-ci/scripts.yml
