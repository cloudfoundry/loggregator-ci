FROM ruby:latest

RUN gem install dogapi
RUN gem install em-eventsource
RUN curl -L "https://cli.run.pivotal.io/stable?release=debian64&source=github" > cf.deb && dpkg -i ./cf.deb
RUN apt-get -y update && apt-get -y upgrade && apt-get -y install jq
