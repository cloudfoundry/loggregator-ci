FROM ubuntu:latest

RUN apt-get update \
 && apt-get install -y software-properties-common \
 && add-apt-repository -y ppa:mercurial-ppa/releases \
 && apt-get update \
 && apt-get install -y bundler patch make git wget mercurial bzr libmysqlclient-dev libpq-dev libsqlite3-dev curl iptables host libdigest-hmac-perl zip jq vim \
 && git config --global user.email "cf-loggregator@pivotal.io" && git config --global user.name "Loggregator CI"
