#!/usr/bin/env bash
function credhub-get() (
  set -e
  var_name=$1
  key_name=${2:-""}

  pushd "bbl-state/${BBL_STATE_DIR}" > /dev/null
    eval "$(bbl print-env)"
  popd > /dev/null

  key=""
  if [[ -n "${key_name}" ]]; then
    key=".${key_name}"
  fi
  credhub_find_reulsts=$(credhub find -j -n ${var_name})
  echo ${credhub_find_reulsts} | jq -r .credentials[].name | xargs credhub get -j -n | jq -r ".value${key}"
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

  cf_flags=""
  if [[ "$SKIP_CERT_VERIFY" == "true" ]]; then
    cf_flags="${cf_flags} --skip-ssl-validation"
  fi

  cf api "$CF_API" ${cf_flags}

  if [[ -n ${USE_CLIENT_AUTH} && "$USE_CLIENT_AUTH" == "true" ]]; then
    cf_flags="${cf_flags} --client-credentials"
  fi

  if [[ -d "bbl-state" ]]; then
    PASSWORD=$(cf-password-from-credhub)
  fi

  cf auth "$USERNAME" "$PASSWORD" ${cf_flags}

  if [[ -n ${ORG} && -n ${SPACE} ]]; then
    create-org-space-and-target
  fi
)
