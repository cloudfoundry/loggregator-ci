#!/bin/bash -eu
set -o pipefail

# This script expects to be ran at the concourse base directory
BASE_DIR="$( cd service-metrics-release && pwd )"

pushd "${BASE_DIR}" > /dev/null
  export GOPATH=$PWD
  export PATH=$GOPATH/bin:$PATH

  pushd src/github.com/cloudfoundry/service-metrics > /dev/null
    ./scripts/run-tests.sh
  popd > /dev/null
popd > /dev/null
