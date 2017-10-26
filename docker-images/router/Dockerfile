FROM alpine:latest

ENV foo=bar

WORKDIR /srv/router/bin
RUN mkdir -p /srv/router/bin/config
COPY router /srv/router/bin/router

CMD [ "/srv/router/bin/router" ]
