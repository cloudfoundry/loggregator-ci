FROM ubuntu:16.04

# Fluent Bit version
ENV FLB_VERSION 1.0.6
ENV GOLANG_VERSION 1.12.4

ENV DEBIAN_FRONTEND noninteractive

ENV FLB_TARBALL http://github.com/fluent/fluent-bit/archive/v$FLB_VERSION.zip
RUN mkdir -p /fluent-bit/bin /fluent-bit/etc /fluent-bit/log /tmp/fluent-bit-master/

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      build-essential \
      cmake \
      make \
      wget \
      unzip \
      libssl-dev \
      libasl-dev \
      libsasl2-dev \
      pkg-config \
      libsystemd-dev \
      zlib1g-dev \
      ca-certificates \
      git \
    && wget -O "/tmp/fluent-bit-${FLB_VERSION}.zip" ${FLB_TARBALL} \
    && cd /tmp && unzip "fluent-bit-$FLB_VERSION.zip" \
    && cd "fluent-bit-$FLB_VERSION"/build/ \
    && rm -rf /tmp/fluent-bit-$FLB_VERSION/build/*

WORKDIR /tmp/fluent-bit-$FLB_VERSION/build/
RUN cmake -DFLB_DEBUG=On \
          -DFLB_TRACE=Off \
          -DFLB_JEMALLOC=On \
          -DFLB_TLS=On \
          -DFLB_SHARED_LIB=Off \
          -DFLB_EXAMPLES=Off \
          -DFLB_HTTP_SERVER=On \
          -DFLB_IN_SYSTEMD=On \
          -DFLB_OUT_KAFKA=On ..

RUN make -j $(getconf _NPROCESSORS_ONLN)

RUN wget https://dl.google.com/go/go${GOLANG_VERSION}.linux-amd64.tar.gz
RUN tar -xvf go${GOLANG_VERSION}.linux-amd64.tar.gz && mv go /usr/local

ENV GOROOT /usr/local/go
ENV GOPATH /go
ENV PATH $GOPATH/bin:$GOROOT/bin:$PATH
RUN install bin/fluent-bit /fluent-bit/bin/
