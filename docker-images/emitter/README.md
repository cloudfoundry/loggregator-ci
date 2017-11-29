
# Supported tags and respective `Dockerfile` links

- `latest` [(Dockerfile)][latest-dockerfile]

# Usage

- You must provide TLS certificates and keys for the emitter via a volume mount.

For example:

```bash
docker run \
    --volume "$PWD/loggregator-certs:/srv/emitter/certs:ro" \
    loggregator/emitter
```

[latest-dockerfile]: https://github.com/cloudfoundry/loggregator-ci/blob/master/docker-images/emitter/Dockerfile
