#! /usr/bin/env bash

set -ex

function create_app {
  set -e
  local appname=$1
  local droplet_guid=$2

  cf v3-create-app ${appname}
  new_droplet_guid=$(cf curl /v3/droplets?source_guid=${droplet_guid} -d '{
  "relationships": {
    "app": {
      "data": {
        "guid": "'$(cf app ${appname} --guid)'"
      }
    }
  }' | jq -r .guid)

  wait_for_droplet ${appname} ${new_droplet_guid}

  cf v3-set-droplet ${appname} -d ${new_droplet_guid} 2>/dev/null

  process_guid=$(cf curl /v3/apps/$(cf app ${appname} --guid)/processes | jq -r .resources[0].guid)
  cf curl /v3/processes/${process_guid} -X PATCH -d '{"command": "./logging-telemetry"}'
  cf curl /v3/processes/${process_guid}/actions/scale -X POST -d '{"memory_in_mb": 32, "disk_in_mb": 32}'
  configure_and_start ${appname}
}

function configure_and_start {
    appname=$1

    cf set-env ${appname} TEST_FREQUENCY $test_frequency
    cf set-env ${appname} TEST_DURATION $test_duration
    cf set-env ${appname} TEST_CYCLES $test_cycles
    if [[ "$appname" =~ "producer" ]]; then
        cf set-env ${appname} PRODUCER true
        cf set-health-check ${appname} process
    else
        cf map-route ${appname} ${system_domain} --hostname ${appname}
        cf set-env ${appname} DATADOG_API_KEY $datadog_api_key
    fi

    cf start ${appname}
}

function wait_for_droplet {
  local appname=$1
  local droplet_guid=$2

  set +x
    while ! cf v3-droplets "${appname}" 2>/dev/null | grep "${droplet_guid}" | grep staged; do
      sleep .1s
    done
  set -x
}

if [ "$#" -ne 4 ]; then
    echo "usage: $0 <app name> <system domain> <datadog api key> <droplet guid>"
    exit 1
fi

name=$1
system_domain=$2
datadog_api_key=$3
droplet_guid=$4

test_frequency=10s
test_duration=1s
test_cycles=1000

create_app  "${name}-producer" $droplet_guid
create_app  "${name}-consumer" $droplet_guid

if [ -n "$TEST_FREQUENCY" ]; then
	test_frequency=$TEST_FREQUENCY
fi
if [ -n "$TEST_DURATION" ]; then
	test_duration=$TEST_DURATION
fi
if [ -n "$TEST_CYCLES" ]; then
	test_cycles=$TEST_CYCLES
fi

for drain in $(cf drains | grep $name-producer | awk '{print $2}'); do
    cf delete-drain --force $drain
done

consumer_app_route=$(cf app "$name-consumer" | grep routes | awk '{print $2}')

if [ -z "$DRAIN_COUNT" ]; then
    cf drain "$name-producer" \
        "https$SCHEME_SUFFIX://$consumer_app_route?drain_num=1" \
        --type logs
else
    for i in $(seq $DRAIN_COUNT); do
        cf drain "$name-producer" \
            "https$SCHEME_SUFFIX://$consumer_app_route?drain_num=$i" \
            --type logs
    done
fi
