FROM golang:1.23.5 AS build
ARG COREDNS_VERSION=1.8.6
ARG K8S_GATEWAY_VERSION=0.2.0

WORKDIR /go/src

# get coredns source
RUN curl -L https://github.com/coredns/coredns/archive/refs/tags/v${COREDNS_VERSION}.tar.gz | tar -xz --strip-components 1 && go install

# add k8s_gateway
RUN sed -i '/^k8s_external:k8s_external/a \
k8s_gateway:github.com/ori-edge/k8s_gateway\
' plugin.cfg && go get github.com/ori-edge/k8s_gateway@v${K8S_GATEWAY_VERSION}

# build coredns
RUN make gen && make && ./coredns -plugins

# add stage with the latest certs
FROM debian:stable-slim AS certs

RUN apt-get update && apt-get -uy upgrade
RUN apt-get -y install ca-certificates && update-ca-certificates

# start from a scratch base
FROM scratch

# copy the latest certs from the certs stage
COPY --from=certs /etc/ssl/certs /etc/ssl/certs

# copy the custom build of coredns
COPY --from=build /go/src/coredns /coredns

EXPOSE 53 53/udp
ENTRYPOINT ["/coredns"]
