FROM alpine:latest

ENV PATH="/srv/trafficcontroller/bin:${PATH}"
RUN mkdir -p /srv/trafficcontroller/bin

COPY trafficcontroller /srv/trafficcontroller/bin/trafficcontroller

CMD [ "/srv/trafficcontroller/bin/trafficcontroller" ]
