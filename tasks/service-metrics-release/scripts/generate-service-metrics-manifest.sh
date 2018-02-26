#!/usr/bin/env bash
set -euo pipefail

export manifest_path=service-metrics-release/manifests/manifest.yml

bosh int $manifest_path --vars-file=${VARS_FILE} >> manifest/manifest.yml
