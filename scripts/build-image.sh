#!/bin/bash

set -e

image=$1

if [ "$image" = "" ]; then
  echo "usage: build-image.sh <image>" 1>&2
  exit 1
fi

cd docker-images/$image

docker build --no-cache -t loggregator/$image .
