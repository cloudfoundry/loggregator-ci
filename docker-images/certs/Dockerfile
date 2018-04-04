FROM ubuntu as builder

RUN apt-get update --yes && \
    apt-get install --yes wget git build-essential && \
    mkdir /goroot && \
    cd /goroot && \
    wget https://redirector.gvt1.com/edgedl/go/go1.9.2.linux-amd64.tar.gz && \
    tar xf go1.9.2.linux-amd64.tar.gz

ENV PATH=$PATH:/goroot/go/bin \
    GOPATH=/go

RUN go get -d -u github.com/cloudflare/cfssl/cmd/cfssl/... && \
    go get -d -u github.com/cloudflare/cfssl/cmd/cfssljson/... && \
    GOOS=linux GOARCH=amd64 go build -a -installsuffix nocgo -o ./cfssl github.com/cloudflare/cfssl/cmd/cfssl && \
    GOOS=linux GOARCH=amd64 go build -a -installsuffix nocgo -o ./cfssljson github.com/cloudflare/cfssl/cmd/cfssljson && \
    mkdir /output && \
    mv cfssl* /output/

FROM ubuntu:latest

COPY --from=builder ["/output/cfssl", "/output/cfssljson", "/usr/local/bin/"]
COPY ["generate-certs.sh", "/usr/local/bin/"]

CMD ["generate-certs.sh", "/output"]
