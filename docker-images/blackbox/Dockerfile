FROM ruby:latest

RUN gem install dogapi
RUN curl -L "https://cli.run.pivotal.io/stable?release=debian64&source=github" > cf.deb && dpkg -i ./cf.deb
