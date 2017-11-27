
# Usage

In order to generate certificates and keys you must volume mount the directory
where the certificates and keys will be writen:

```bash
mkdir output
docker run -v "$PWD/output:/output" loggregator/certs
```
