#!/bin/bash

function retry() {
  local num_retries=$1
  shift

  for i in $(seq 1 ${num_retries}); do
    echo "'$@' (attempt ${i} of ${num_retries})" >&2
    if "$@"; then
      return 0
    fi
  done

  return 1
}
