#!/bin/sh

set -e

csr_template='
{
  "CN": "CN_PLACEHOLDER",
  "hosts": [
      "CN_PLACEHOLDER"
      ADDITIONAL_HOST_PLACEHOLDER
  ],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "ST": "California",
      "L": "San Francisco",
      "O": "Cloud Foundry Foundation",
      "OU": "Loggregator"
    }
  ]
}
'

ca_config='
{
  "signing": {
    "default": {
      "expiry": "8760h"
    },
    "profiles": {
      "loggregator": {
        "usages": ["server auth", "client auth"],
        "expiry": "8760h"
      }
    }
  }
}
'

function json_join {
    for var in "$@"; do
        printf ',"'$var'"';
    done;
}

function render_csr {
    local cn
    cn=$1
    shift
    echo "$csr_template" | \
        sed "s/CN_PLACEHOLDER/$cn/" | \
        sed "s/ADDITIONAL_HOST_PLACEHOLDER/$(json_join $@)/"
}

function create_ca {
    render_csr loggregatorCA | \
        cfssl gencert -initca - | \
        cfssljson -bare ca
    mv ca.pem ca.crt
    mv ca-key.pem ca.key
    rm ca.csr
}

function create_keypair {
    echo "$ca_config" > /tmp/ca_config
    render_csr "$@" | \
        cfssl gencert \
            -ca=ca.crt \
            -ca-key=ca.key \
            -config=/tmp/ca_config \
            -profile=loggregator \
            - | \
        cfssljson -bare "$1"
    mv "$1.pem" "$1.crt"
    mv "$1-key.pem" "$1.key"
    rm "$1.csr"
}

function validate {
    if ! which cfssl > /dev/null || ! which cfssljson > /dev/null ; then
        echo cfssl is not installed
        echo see: https://github.com/cloudflare/cfssl#installation
        exit 1
    fi
    if [ "$1" = "" ] ; then
        echo "usage: $0 <target_dir>"
        exit 1
    fi
}

function main {
    validate $1
    mkdir -p "$1"
    cd "$1"
    create_ca
    create_keypair router doppler
    create_keypair rlp reverselogproxy
    create_keypair agent metron localhost ip6-localhost 127.0.0.1 ::1
}
main $@
