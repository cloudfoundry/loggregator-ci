#!/bin/bash

function report_to_datadog {
    echo "$msg_count"

    currenttime=$(date +%s)
    curl  -X POST -H "Content-type: application/json" \
    -d "{ \"series\" :
             [{\"metric\":\"smoke_test.loggregator.msg_count\",
              \"points\":[[${currenttime}, ${msg_count}]],
              \"type\":\"gauge\",
              \"host\":\"${CF_API}\",
              \"tags\":[\"${APP_NAME}\"]}
            ]
        }" \
    'https://app.datadoghq.com/api/v1/series?api_key='"$DATADOG_API_KEY"

    curl  -X POST -H "Content-type: application/json" \
    -d "{ \"series\" :
             [{\"metric\":\"smoke_test.loggregator.delay\",
              \"points\":[[${currenttime}, $DELAY]],
              \"type\":\"gauge\",
              \"host\":\"${CF_API}\",
              \"tags\":[\"${APP_NAME}\"]}
            ]
        }" \
    'https://app.datadoghq.com/api/v1/series?api_key='"$DATADOG_API_KEY"

    curl  -X POST -H "Content-type: application/json" \
    -d "{ \"series\" :
             [{\"metric\":\"smoke_test.loggregator.cycles\",
              \"points\":[[${currenttime}, ${CYCLES}]],
              \"type\":\"gauge\",
              \"host\":\"${CF_API}\",
              \"tags\":[\"${APP_NAME}\"]}
            ]
        }" \
    'https://app.datadoghq.com/api/v1/series?api_key='"$DATADOG_API_KEY"
}

set -e -x

msg_count=0

trap report_to_datadog EXIT

# target api
cf login \
    -a "$CF_API" \
    -u "$USERNAME" \
    -p "$PASSWORD" \
    -s "$SPACE" \
    -o "$ORG" \
    --skip-ssl-validation # TODO: pass this in as a param

# cf logs to a file
rm -f output.txt
echo "Collecting logs for $APP_NAME"
cf logs "$APP_NAME" > output.txt 2>&1 &
sleep 30 # wait 30 seconds to establish connection

# curl my logspinner
echo "Triggering $APP_NAME"
curl "$APP_DOMAIN?cycles=$CYCLES&delay=$DELAY$DELAY_UNIT&text=$MESSAGE"

sleep "$WAIT" # wait for a bit to collect logs

msg_count=$(grep APP output.txt | grep -c "$MESSAGE")

# Trap will send metrics to datadog
