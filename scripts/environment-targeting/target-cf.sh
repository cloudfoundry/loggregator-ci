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

function target-cf() (
    set -e
    if [[ -n $USE_CLIENT_AUTH && "$USE_CLIENT_AUTH" == "true" ]]; then
        cf api "$CF_API"
        if [ "$SKIP_CERT_VERIFY" == "true" ]; then
            cf auth "$USERNAME" "$PASSWORD" --client-credentials --skip-ssl-validation
        else
            cf auth "$USERNAME" "$PASSWORD" --client-credentials
        fi
        cf target -o "$ORG" -s "$SPACE"
    else
        if [[ -d "bbl-state" ]]; then
            PASSWORD=$(cf-password-from-credhub)
        fi
        if [ "$SKIP_CERT_VERIFY" == "true" ]; then
            cf login \
            -a "$CF_API" \
            -u "$USERNAME" \
            -p "$PASSWORD" \
            -s "$SPACE" \
            -o "$ORG" \
            --skip-ssl-validation
        else
            cf login \
            -a "$CF_API" \
            -u "$USERNAME" \
            -p "$PASSWORD" \
            -s "$SPACE" \
            -o "$ORG"
        fi

    fi
)
