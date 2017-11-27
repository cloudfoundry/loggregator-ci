
# Usage

- You should publish the gRPC API port 8082.
- You must provide TLS certificates and keys for the router via a volume mount.

For example:

```bash
docker run \
    --detach \
    --publish 8082:8082
    --volume "$PWD/loggregator-certs:/srv/router/certs:ro \
    loggregator/router
```
