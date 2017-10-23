FROM alpine:latest

ENV PATH="/srv/rlp/bin:${PATH}"
RUN mkdir -p /srv/rlp/bin

COPY rlp /srv/rlp/bin/rlp

CMD [ "/srv/rlp/bin/rlp" ]
