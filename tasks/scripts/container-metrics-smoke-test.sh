#!/bin/bash

set -e -x

if [ "$USE_CLIENT_AUTH" == "false" ]; then
    cf login \
      -a "$CF_API" \
      -u "$USERNAME" \
      -p "$PASSWORD" \
      -s "$SPACE" \
      -o "$ORG"
else
    cf api "$CF_API"
    cf auth "$USERNAME" "$PASSWORD" --client-credentials
    cf target -o "$ORG" -s "$SPACE"
fi

mkdir /tmp/gopath
export GOPATH=/tmp/gopath
export PATH=$PATH:$GOPATH/bin
go get github.com/cloudfoundry/loggregator-ci/tools/container_metrics

echo $LOGGREGATOR_ADDR
export APP_GUID=$(cf app $APP_NAME --guid)
export CF_ACCESS_TOKEN=$(cf oauth-token | grep bearer)

results_name=/tmp/container_metrics.results

container_metrics > $results_name
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
