#!/usr/bin/env bash

pipeline=$1
snapshot_id=$2
snapshot_dir=snapshots/$pipeline/$snapshot_id
resource_files=$snapshot_dir/resources/*.json

snapshot_pipeline_name="$pipeline-$snapshot_id"
function check_resources {
    IFS=$'\n'
    for resource in $(cat ${resource_files} | jq -r 'to_entries | .[] | [ .key, .value.ref|tostring ] | join(" -f ref:")'); do
        local fly_cmd="fly -t loggregator check-resource --resource $snapshot_pipeline_name/$resource"
        echo $fly_cmd
        sh -c $fly_cmd
    done
}

function set_globals {
    TARGET="${TARGET:-loggregator}"
}

function validate {
    if [ "$pipeline" = "-h" ] || [ "$pipeline" = "--help" ] || [ -z "$snapshot_id" ]; then
        print_usage
        exit 1
    fi
}

function set_pipeline {
    echo setting pipeline for "$snapshot_pipeline_name"
    fly -t $TARGET set-pipeline -p "$snapshot_pipeline_name" \
        -c "$snapshot_dir/pipeline.yml" \
        -l <(lpass show 'Shared-Loggregator (Pivotal Only)/pipeline-secrets.yml' --notes) \
        -l ~/workspace/loggregator-ci/scripts.yml
}

function sync_fly {
    fly -t $TARGET sync
}

function print_usage {
    echo "usage: $0 <pipeline> <snapshot_id>"
}

function main {
    set_globals
    validate
    sync_fly
    set_pipeline
    fly -t loggregator unpause-pipeline -p $snapshot_pipeline_name
    check_resources
}
main