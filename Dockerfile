FROM alpine:3.19 AS root

RUN apk update && apk upgrade \
    && apk add --no-cache ca-certificates bash openssl curl \
    && update-ca-certificates || true

RUN openssl s_client -connect storage.googleapis.com:443 -servername storage.googleapis.com </dev/null | openssl x509 -out /etc/ssl/certs/storage.googleapis.com.crt

FROM 416670754337.dkr.ecr.eu-west-2.amazonaws.com/ci-golang-build-1.23 AS build-stage

ENV GO111MODULE=on \
    CGO_ENABLED=1

COPY --from=root /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=root /etc/ssl/certs/storage.googleapis.com.crt /etc/ssl/certs/storage.googleapis.com.crt

WORKDIR /build

COPY ./resources/builder-config.yaml builder-config.yaml

RUN --mount=type=cache,target=/root/.cache/go-build GO111MODULE=on go install go.opentelemetry.io/collector/cmd/builder@v0.150.0

ENV PATH="$PATH:/root/go/bin"
RUN --mount=type=cache,target=/root/.cache/go-build builder --config builder-config.yaml

FROM gcr.io/distroless/base:latest

# sh
COPY --from=busybox:1.37.0-uclibc /bin/sh /bin/sh

# curl
COPY --from=root /usr/bin/curl /usr/bin/curl
COPY --from=root /lib/ /lib/
COPY --from=root /usr/lib/ /usr/lib/

ARG USER_UID=10001
USER ${USER_UID}

COPY ./resources/collector-config.yaml /otelcol/collector-config.yaml

COPY --from=root /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=root /etc/ssl/certs/storage.googleapis.com.crt /etc/ssl/certs/storage.googleapis.com.crt

COPY --chmod=755 --from=build-stage /build/opentelemetry-collector /otelcol

ENTRYPOINT ["/otelcol/opentelemetry-collector"]
CMD ["--config", "/otelcol/collector-config.yaml"]

EXPOSE 4317 4318 13133
