#!/bin/bash
set -eo pipefail

function set_globals {
    TARGET="${TARGET:-denver}"
    TEAM="${TEAM:-loggregator}"
}

function set_pipeline {
    echo setting pipeline for "pas-deploy"

    config_file=<(erb pipelines/pas-deploy.yml.erb)

    fly -t ${TARGET} set-pipeline -p "pas-deploy" \
        -c ${config_file} \
        -l <(lpass show 'Shared-Loggregator (Pivotal Only)/pipeline-secrets.yml' --notes) \
        -l <(lpass show 'Shared-Pivotal Common/pas-releng-fetch-releases' --notes) \
        -l pipelines/config/pas-deploy.yml \
        --var "toolsmiths-api-key=$(lpass show 'Shared-Loggregator (Pivotal Only)/toolsmiths-api-token' --notes)" \
        --var "pivnet-refresh-token=$(lpass show 'Shared-Loggregator (Pivotal Only)/pivnet-api-token' --notes)"
}

function sync_fly {
    fly -t ${TARGET} sync
    fly -t ${TARGET} status 2>/dev/null || fly -t ${TARGET} login -b -n ${TEAM} -c https://concourse.cf-denver.com
}

function main {
    set_globals
    sync_fly
    set_pipeline
}

lpass ls 1>/dev/null
main
