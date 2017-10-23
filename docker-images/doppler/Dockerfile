FROM alpine:latest

ENV PATH="/srv/doppler/bin:${PATH}"
RUN mkdir -p /srv/doppler/bin

COPY doppler /srv/doppler/bin/doppler

CMD [ "/srv/doppler/bin/doppler" ]
