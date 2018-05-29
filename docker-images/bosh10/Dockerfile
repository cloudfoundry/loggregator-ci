FROM ubuntu:latest

RUN apt-get --yes update && \
    apt-get --yes install software-properties-common && \
    apt-add-repository ppa:brightbox/ruby-ng && \
    apt-get --yes update && \
    apt-get --yes install \
        build-essential \
        curl \
        git \
        ruby2.5 \
        ruby2.5-dev \
        unzip \
        wget &&\
    gem update --system && \
    gem install bosh_cli bundler --no-ri --no-rdoc

RUN wget https://github.com/cloudfoundry-incubator/spiff/releases/download/v1.0.8/spiff_linux_amd64.zip && \
    unzip spiff*.zip && \
    mv spiff /usr/local/bin/
