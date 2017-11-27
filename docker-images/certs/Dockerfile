FROM cfssl/cfssl:latest

COPY generate-certs.sh /generate-certs.sh

ENTRYPOINT ["/generate-certs.sh"]
CMD ["/output"]
