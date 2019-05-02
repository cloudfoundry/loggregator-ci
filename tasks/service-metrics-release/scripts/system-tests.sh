#!/bin/bash -eu

set -o pipefail

# This script expects to be ran at the concourse base directory
BASE_DIR="$( cd service-metrics-release && pwd )"

pushd "${BASE_DIR}" > /dev/null
  export GOPATH=$PWD
  export PATH=$GOPATH/bin:$PATH

  source loggregator-ci/scripts/environment-targeting/target-cf.sh
  export PASSWORD=$(cf-password-from-credhub)

  git submodule init && git submodule update --recursive

  go get github.com/cloudfoundry/noaa/samples/firehose

  bundle install
  bundle exec rake spec
popd > /dev/null
