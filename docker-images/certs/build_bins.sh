#!/bin/bash
script='
apt-get update --yes
apt-get install --yes wget git
mkdir /goroot
cd /goroot
wget https://redirector.gvt1.com/edgedl/go/go1.9.2.linux-amd64.tar.gz
tar xf go1.9.2.linux-amd64.tar.gz
cd go/bin
export PATH=$PATH:$PWD
cd
mkdir workspace
cd workspace
export GOPATH=$PWD
go get -d -u github.com/cloudflare/cfssl/cmd/cfssl/...
go get -d -u github.com/cloudflare/cfssl/cmd/cfssljson/...
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -a -installsuffix nocgo -o ./cfssl github.com/cloudflare/cfssl/cmd/cfssl
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -a -installsuffix nocgo -o ./cfssljson github.com/cloudflare/cfssl/cmd/cfssljson
mv cfssl* /output/
'
docker run --rm -v $PWD:/output ubuntu /bin/bash -c "$script"
