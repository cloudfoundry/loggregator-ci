#!/bin/bash
set -eo pipefail

function set_globals {
    pipeline=$1
    TARGET="${TARGET:-loggregator}"
    FLY_URL="https://loggregator.ci.cf-app.com"
}

function validate {
    if [[ "$pipeline" = "-h" ]] || [[ "$pipeline" = "--help" ]] || [[ -z "$pipeline" ]]; then
        print_usage
        exit 1
    fi
}

function set_pipeline {
    pipeline_name=$1
    pipeline_file="pipelines/$(ls pipelines | grep ^${pipeline_name})"

    if [[ ${pipeline_file} = *.erb ]]; then
      erb ${pipeline_file} > /dev/null # this way if the erb fails the script bails
      pipeline_file=<(erb ${pipeline_file})
    fi

    echo setting pipeline for "$pipeline_name"

    fly -t ${TARGET} set-pipeline -p "$pipeline_name" \
        -c "$pipeline_file" \
        -l <(lpass show 'Shared-Loggregator (Pivotal Only)/pipeline-secrets.yml' --notes) \
        -l <(lpass show 'Shared-CF- Log Cache (Pivotal ONLY)/release-credentials.yml' --notes) \
        -l pipelines/config/acceptance-environment.yml \
        -l pipelines/config/development-environment.yml \
        -l pipelines/config/cats-testing.yml
}

function sync_fly {
    if ! fly -t ${TARGET} status; then
      fly -t ${TARGET} login -b -c ${FLY_URL}
    fi
    fly -t ${TARGET} sync
}

function set_pipelines {
    if [[ "$pipeline" = all ]]; then
        for pipeline_path in $(find pipelines -maxdepth 1 -type f); do
          pipeline_file=$(basename ${pipeline_path})
          set_pipeline "${pipeline_file%%.*}"
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

lpass ls 1>/dev/null
main $1 $2
