FROM loggregator/ubuntu-base

ENV GOPATH=/go \
    PATH=/usr/local/go/bin:/go/bin:$PATH

ADD go*.tar.gz /usr/local

RUN go get github.com/onsi/ginkgo/ginkgo
