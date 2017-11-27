FROM alpine:latest

ENV AGENT_CERT_FILE="/srv/agent/certs/agent.crt" \
    AGENT_KEY_FILE="/srv/agent/certs/agent.key" \
    AGENT_CA_FILE="/srv/agent/certs/ca.crt" \
    AGENT_PORT="3458" \
    AGENT_INCOMING_UDP_PORT="3457" \
    AGENT_PPROF_PORT="6060" \
    AGENT_HEALTH_ENDPOINT_PORT="6061" \
    AGENT_DEPLOYMENT="docker-deployment" \
    AGENT_JOB="docker-job" \
    AGENT_INDEX="0" \
    AGENT_IP="agent.local"

EXPOSE 3458 \
       3457/UDP \
       6060 \
       6061

RUN mkdir -p /srv/agent/bin
COPY agent /srv/agent/bin/agent
WORKDIR /srv/agent/
CMD [ "/srv/agent/bin/agent" ]
