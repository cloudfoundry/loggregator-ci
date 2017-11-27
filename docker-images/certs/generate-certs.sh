#!/bin/bash

set -e

csr_template='
{
  "CN": "CN_PLACEHOLDER",
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

function create_ca {
    echo "$csr_template" | \
        sed 's/CN_PLACEHOLDER/loggregatorCA/' | \
        cfssl gencert -initca - | \
        cfssljson -bare ca
    mv ca.pem ca.crt
    mv ca-key.pem ca.key
    rm ca.csr
}

function create_keypair {
    echo "$csr_template" | \
        sed "s/CN_PLACEHOLDER/$2/" | \
        cfssl gencert \
            -ca=ca.crt \
            -ca-key=ca.key \
            -config=<(echo "$ca_config") \
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
    pushd "$1" > /dev/null
        create_ca
        create_keypair router doppler
        create_keypair rlp reverselogproxy
        create_keypair agent metron
    popd > /dev/null
}
main $@
