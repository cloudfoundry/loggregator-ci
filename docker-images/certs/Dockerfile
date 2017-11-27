FROM alpine:latest

COPY ["cfssl", "cfssljson", "generate-certs.sh", "/usr/local/bin/"]

CMD ["generate-certs.sh", "/output"]
