#!/bin/bash

set -e -x

# target api
cf login \
    -a "$CF_API" \
    -u "$USERNAME" \
    -p "$PASSWORD" \
    -s "$SPACE" \
    -o "$ORG" \
    --skip-ssl-validation # TODO: pass this in as a param

# build recent logs measure tool
mkdir /tmp/gopath
export GOPATH=/tmp/gopath
export PATH=$PATH:$GOPATH/bin
go get github.com/cloudfoundry/loggregator-ci/tools/container_metrics

echo $LOGGREGATOR_ADDR
export APP_GUID=$(cf app $APP_NAME --guid)
export CF_ACCESS_TOKEN=$(cf oauth-token | grep bearer)

results_name=/tmp/recent_logs.results

recent_logs > $results_name
cat $results_name
latency=$(cat $results_name | grep "Latency" | cut -d ' ' -f2)

currenttime=$(date +%s)
curl  -X POST -H "Content-type: application/json" \
-d "{ \"series\" :
         [{\"metric\":\"smoke_test.loggregator.container_metric_roundtrip_latency\",
          \"points\":[[${currenttime}, ${latency}]],
          \"type\":\"gauge\",
          \"host\":\"${CF_API}\",
          \"tags\":[\"${APP_NAME}\"]}
        ]
    }" \
'https://app.datadoghq.com/api/v1/series?api_key='"$DATADOG_API_KEY"
