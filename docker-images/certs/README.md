
# Supported tags and respective `Dockerfile` links

- `latest` [(Dockerfile)][latest-dockerfile]

# Usage

In order to generate certificates and keys you must volume mount the directory
where the certificates and keys will be writen:

```bash
docker run -v "$PWD/output:/output" loggregator/certs
```

[latest-dockerfile]: https://github.com/cloudfoundry/loggregator-ci/blob/master/docker-images/certs/Dockerfile
