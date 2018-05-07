FROM golang:latest as builder

COPY / /go/

ENV CGO_ENABLED=0 \
    GOOS=linux \
    GOARCH=amd64

RUN go build \
    -a \
    -installsuffix nocgo \
    -o /agent \
    code.cloudfoundry.org/loggregator-agent/cmd/agent

FROM alpine:latest

ENV AGENT_CERT_FILE="/srv/certs/agent.crt" \
    AGENT_KEY_FILE="/srv/certs/agent.key" \
    AGENT_CA_FILE="/srv/certs/ca.crt" \
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

COPY --from=builder /agent /srv/
WORKDIR /srv
CMD [ "/srv/agent" ]
