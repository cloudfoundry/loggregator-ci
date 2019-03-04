#!/usr/bin/env bash

pipeline=$1
snapshot=$2
snapshot_dir=snapshots/$snapshot
resource_files=$snapshot_dir/resources/*.json

function check_resources() {
    cat ${resource_files} \
        | jq 'to_entries | .[] | [ .key, .value.ref|tostring ] | join(" -f ref:")' \
        | xargs -n 1 -I {} sh -c "fly -t loggregator check-resource --resource $snapshot/{}"
}

function set_globals {
    TARGET="${TARGET:-loggregator}"
}

function validate {
    if [ "$pipeline" = "-h" ] || [ "$pipeline" = "--help" ] || [ -z "$snapshot" ]; then
        print_usage
        exit 1
    fi
}

function set_pipeline {
    echo setting pipeline for "$snapshot"
    fly -t $TARGET set-pipeline -p "$snapshot" \
        -c "$snapshot_dir/pipeline.yml" \
        -l <(lpass show 'Shared-Loggregator (Pivotal Only)/pipeline-secrets.yml' --notes) \
        -l ~/workspace/loggregator-ci/scripts.yml
}

function sync_fly {
    fly -t $TARGET sync
}

function print_usage {
    echo "usage: $0 <pipeline> <snapshot_name>"
}

function main {
    set_globals
    validate
    sync_fly
    set_pipeline
    check_resources
}
main