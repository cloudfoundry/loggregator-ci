#! /usr/bin/env bash

set -o errexit
set -o pipefail

pipeline_name=$1
job_name=$2

get_auth_token() {
    local token=$(cat /Users/pivotal/.flyrc | grep value | awk '{print $2}')
    echo ${token//\"}
}

get_plan() {
    local auth_header="Authorization: Bearer $token"
    local build_id=$(curl -s "https://loggregator.ci.cf-app.com/api/v1/teams/main/pipelines/$pipeline_name/jobs/$job_name/builds?limit=1&since=999999999" -H "$auth_header" | jq .[0].id)
    echo $(curl -s "https://loggregator.ci.cf-app.com/api/v1/builds/$build_id/plan" -H "$auth_header" | jq .plan)
}

get_gets() {
    local plan=$1
    echo $(jq '.. | .get? // empty | select(.type=="git") | select(.version !=null)' $plan)
}

token=$(get_auth_token)
if [[ -z "$token" ]]
then
    echo 'You need to fly login first'
    exit 1
fi

echo $(get_plan | get_gets | jq -s . | jq 'INDEX(.name)') | jq
