#!/bin/bash

set -e

image=$1

if [ "$image" = "" ]; then
  echo "usage: push-image.sh <image>" 1>&2
  exit 1
fi

docker push loggregator/$image
