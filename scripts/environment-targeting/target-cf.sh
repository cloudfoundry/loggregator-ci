#!/usr/bin/env bash
function credhub-get() {
    var_name=$1
    pushd "bbl-state/${BBL_STATE_DIR}" > /dev/null
        eval "$(bbl print-env)"
    popd > /dev/null

    credhub find -j -n ${var_name} | jq -r .credentials[].name | xargs credhub get -j -n | jq -r .value
}

function cf-password-from-credhub() {
    credhub-get cf_admin_password
}

function target-cf() {
    if [ "$USE_CLIENT_AUTH" == "true" ]; then
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
}
