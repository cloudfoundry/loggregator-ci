FROM alpine:latest

ENV CERT="/srv/emitter/certs/agent.crt" \
    KEY="/srv/emitter/certs/agent.key" \
    CA="/srv/emitter/certs/ca.crt" \
    TARGET="localhost:3458" \
    RATE="1s"

RUN mkdir -p /srv/emitter/bin
COPY emitter /srv/emitter/bin/emitter
WORKDIR /srv/emitter/
CMD [ "/srv/emitter/bin/emitter" ]
