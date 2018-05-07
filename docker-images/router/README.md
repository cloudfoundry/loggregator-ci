
# Supported tags and respective `Dockerfile` links

- `latest` [(Dockerfile)][latest-dockerfile]

# Usage

- You should publish the gRPC API port 8082.
- You must provide TLS certificates and keys for the router via a volume mount.

For example:

```bash
docker run \
    --detach \
    --publish 8082:8082 \
    --volume "$PWD/loggregator-certs:/srv/certs:ro" \
    loggregator/router
```

[latest-dockerfile]: https://github.com/cloudfoundry/loggregator-ci/blob/master/docker-images/router/Dockerfile
