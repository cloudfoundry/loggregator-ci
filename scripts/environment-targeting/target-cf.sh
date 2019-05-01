#!/usr/bin/env bash
set -e

function target-cf() {
    if [[ -d "bbl-state" ]]; then
        pushd "bbl-state/${BBL_STATE_DIR}"
            eval "$(bbl print-env)"
        popd

        PASSWORD=$(credhub find -j -n cf_admin_password | jq -r .credentials[].name | xargs credhub get -j -n | jq -r .value)
    fi

    if [ "$USE_CLIENT_AUTH" == "false" ]; then
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
    else
        cf api "$CF_API"
        if [ "$SKIP_CERT_VERIFY" == "true" ]; then
            cf auth "$USERNAME" "$PASSWORD" --client-credentials --skip-ssl-validation
        else
            cf auth "$USERNAME" "$PASSWORD" --client-credentials
        fi
        cf target -o "$ORG" -s "$SPACE"
    fi
}

target-cf