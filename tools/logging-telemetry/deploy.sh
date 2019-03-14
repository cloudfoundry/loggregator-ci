#! /usr/bin/env bash

set -ex

if [ "$#" -ne 2 ]; then
    echo "usage: $0 [app name] [datadog api key]"
    exit 1
fi
name=$1
datadog_api_key=$2

if [ ! -f logging-telemetry ]; then
    GOOS=linux go build
fi

cf push "$name-producer" \
    -b binary_buildpack \
    -c ./logging-telemetry \
    -u none \
    -m 32M \
    -k 32M \
    --no-route \
    --no-start

cf push "$name-consumer" \
    -b binary_buildpack \
    -c ./logging-telemetry \
    -m 32M \
    -k 32M \
    --no-start

test_frequency=10s
test_duration=1s
test_cycles=1000

if [ -n "$TEST_FREQUENCY" ]; then
   test_frequency=$TEST_FREQUENCY
fi
if [ -n "$TEST_DURATION" ]; then
   test_duration=$TEST_DURATION
fi
if [ -n "$TEST_CYCLES" ]; then
   test_cycles=$TEST_CYCLES
fi

cf set-env "$name-producer" TEST_FREQUENCY $test_frequency
cf set-env "$name-producer" TEST_DURATION $test_duration
cf set-env "$name-producer" TEST_CYCLES $test_cycles
cf set-env "$name-producer" PRODUCER true

cf set-env "$name-consumer" TEST_FREQUENCY $test_frequency
cf set-env "$name-consumer" TEST_DURATION $test_duration
cf set-env "$name-consumer" TEST_CYCLES $test_cycles
cf set-env "$name-consumer" DATADOG_API_KEY $datadog_api_key

cf start "$name-producer"
cf start "$name-consumer"

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
