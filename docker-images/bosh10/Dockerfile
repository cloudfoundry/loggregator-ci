FROM loggregator/go17

RUN apt-get --yes update && \
    apt-get --yes install ruby && \
    gem install bosh_cli --no-ri --no-rdoc

RUN wget https://github.com/cloudfoundry-incubator/spiff/releases/download/v1.0.8/spiff_linux_amd64.zip && \
    unzip spiff*.zip && \
    mv spiff /usr/local/bin/
