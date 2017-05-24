This docker image currently has go1.8.2

Add the particular go tar ball inside the corresponding docker-image
directory.

```bash
# Build the image
docker build -t loggregator/go18
# List the images
docker images
# Login - Use the loggregatorbot creds in LP
docker login
# Push the image
docker push loggregator/go18
```
