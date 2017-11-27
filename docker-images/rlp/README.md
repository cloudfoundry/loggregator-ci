
# Usage

- You should publish the gRPC API port 8082.
- You must tell the agent where to find all the routers via the `ROUTER_ADDRS`
  environment variable.
- You must provide TLS certificates and keys for the rlp via a volume mount.

For example:

```bash
docker run \
    --detach \
    --publish 8082:8082
    --env "ROUTER_ADDRS=router:8082" \
    --volume "$PWD/loggregator-certs:/srv/rlp/certs:ro \
    loggregator/rlp
```
