#!/usr/bin/env bash
function credhub-get() (
  set -e
  var_name=$1
  key_name=${2:-""}

  eval "$(bbl print-env --metadata-file bbl-state/metadata)"

  key=""
  if [[ -n "${key_name}" ]]; then
    key=".${key_name}"
  fi
  credhub_find_results=$(credhub find -j -n ${var_name})
  echo ${credhub_find_results} | jq -r .credentials[].name | xargs credhub get -j -n | jq -r ".value${key}"
)

function cf-password-from-credhub() (
    set -e
    credhub-get cf_admin_password
)

function create-org-space-and-target() {
  cf create-org "$ORG"
  cf target -o "$ORG"

  cf create-space "$SPACE"
  cf target -s "$SPACE"
}

function target-cf() (
  set -e

  skip_ssl=""
  if [[ "$SKIP_CERT_VERIFY" == "true" ]]; then
    skip_ssl="--skip-ssl-validation"
  fi

  cf api "$CF_API" ${skip_ssl}

  client_credentials=""
  if [[ -n ${USE_CLIENT_AUTH} && "$USE_CLIENT_AUTH" == "true" ]]; then
    client_credentials="--client-credentials"
  fi

  if [[ -d "bbl-state" ]]; then
    PASSWORD=$(cf-password-from-credhub)
  fi

  cf auth "$USERNAME" "$PASSWORD" ${client_credentials}

  if [[ -n ${ORG} && -n ${SPACE} ]]; then
    create-org-space-and-target
  fi
)
