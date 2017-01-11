FROM loggregator/ubuntu-base

ENV GOPATH=/go \
    PATH=/usr/local/go/bin:/go/bin:$PATH

RUN wget https://storage.googleapis.com/golang/go1.7.4.linux-amd64.tar.gz \
 && tar -xzf go1.7.4.linux-amd64.tar.gz -C /usr/local \
 && go get github.com/onsi/ginkgo/ginkgo
