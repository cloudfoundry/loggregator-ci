#!/bin/bash -eu
set -o pipefail

# This script expects to be ran at the concourse base directory
BASE_DIR="$( cd service-metrics-release && pwd )"

pushd "${BASE_DIR}" > /dev/null
  export GOPATH=$PWD
  export PATH=$GOPATH/bin:$PATH

  pushd src/github.com/pivotal-cf/service-metrics > /dev/null
    go get github.com/tools/godep
    godep restore ./...

    go get github.com/onsi/ginkgo/ginkgo

    ./scripts/run-tests.sh
  popd > /dev/null

  bats --tap $(find . -name *.bats)
popd > /dev/null
