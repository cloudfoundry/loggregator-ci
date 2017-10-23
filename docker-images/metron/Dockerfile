FROM ubuntu:latest

ENV PATH="/srv/metron/bin:${PATH}"
RUN mkdir -p /srv/metron/bin

COPY metron /srv/metron/bin/metron

CMD [ "/srv/metron/bin/metron" ]
