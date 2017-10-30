FROM alpine:latest

ENV AGENT_CERT_FILE="/srv/agent/certs/agent.crt"
ENV AGENT_KEY_FILE="/srv/agent/certs/agent.key"
ENV AGENT_CA_FILE="/srv/agent/certs/ca.crt"
ENV AGENT_PORT="3458"
ENV AGENT_INCOMING_UDP_PORT="3457"
ENV AGENT_HEALTH_ENDPOINT_PORT="14824"
ENV AGENT_PPROF_PORT="0"
ENV AGENT_DEPLOYMENT="docker-deployment"
ENV AGENT_JOB="docker-job"
ENV AGENT_INDEX="0"
ENV AGENT_IP="agent.local"

# A container must configure an address of the router.
ENV ROUTER_ADDR=""

WORKDIR /srv/agent/
RUN mkdir -p /srv/agent/bin && \
    mkdir -p /srv/agent/certs
COPY agent /srv/agent/bin/agent
COPY agent.crt /srv/agent/certs/agent.crt
COPY agent.key /srv/agent/certs/agent.key
COPY ca.crt /srv/agent/certs/ca.crt

CMD [ "/srv/metron/bin/metron" ]
