FROM golang:1.8

RUN go version

RUN apt-get update; apt-get install -y unzip

# get v3 protoc from github, it was in beta at the time of writing
RUN cd /tmp \
 && wget https://github.com/google/protobuf/releases/download/v3.0.0-beta-2/protoc-3.0.0-beta-2-linux-x86_64.zip \
 && unzip *.zip \
 && cp ./protoc /usr/local/bin/
