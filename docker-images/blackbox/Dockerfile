FROM ruby:latest

RUN gem install dogapi
RUN gem install em-eventsource
RUN curl -L "https://cli.run.pivotal.io/stable?release=debian64&source=github" > cf.deb && dpkg -i ./cf.deb
RUN apt-get -y update && apt-get -y upgrade && apt-get -y install jq

ENV credhub_cli_version=2.4.0
RUN curl -OL https://github.com/cloudfoundry-incubator/credhub-cli/releases/download/${credhub_cli_version}/credhub-linux-${credhub_cli_version}.tgz && \
  tar xzvf credhub-linux-${credhub_cli_version}.tgz && \
  mv credhub /usr/local/bin && \
  chmod +x /usr/local/bin/credhub && \
  rm credhub-linux-${credhub_cli_version}.tgz

RUN cd /tmp \
  && wget https://github.com/cloudfoundry/bosh-bootloader/releases/download/v6.6.7/bbl-v6.6.7_linux_x86-64 -O /usr/local/bin/bbl \
  && chmod +x /usr/local/bin/bbl