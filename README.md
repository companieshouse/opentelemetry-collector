# opentelemetry-collector
A tool for building a custom OpenTelemetry collector image, and deploying the Collector service.

## Building new image
A new version of the collector image can be configured in `resources/builder-config.yaml`

Inside that file, you can add new components like exporters, processors, receivers and extensions.

These components are defined and maintained as part of the [OpenTelemetry Collector Contrib](https://github.com/open-telemetry/opentelemetry-collector-contrib).

To deploy the new image to ECR, merge changes into the `main` branch and deploy via the concourse pipeline.

## Updating Collector config
The Collector config is defined in `terraform/groups/ecs-service/gateway-otel-collector-config.yaml`.

## Infrastructure
The terraform in `terraform/groups/infrastructure` is responsible for provisioning the ECS cluster and ALB for the Collector service.

The terraform in `terraform/groups/ecs-service` is responsible for provisioning the Collector service itself.


## local-test
The `local-test` directory allows to try the gateway config (`terraform/groups/ecs-service/gateway-otel-collector-config.yaml`) locally, without deploying to AWS. Docker is required.

### run.sh
Generates `local-test/generated-config.yaml` from the real gateway config with these local-only changes:
- the `awsxray` and `awsemf` exporters are replaced by `debug` (no AWS credentials needed);
- tail sampling is set to 100% with a `decision_wait` of 2s, so every trace shows up quickly.

It then validates the config or runs the collector in Docker, exposing ports `4318` (OTLP/HTTP) and `13133` (health check).

```bash
./local-test/run.sh            # run the collector (Ctrl+C to stop)
./local-test/run.sh validate   # only validate the config
```
> **_NOTE 1:_**
The script modifies the configuration as it is known at the time of writing. If this configuration is changed in the future without updating `run.sh`, any subsequent errors can be resolved by comparing the new version of the configuration against the reference version provided [here](https://github.com/companieshouse/opentelemetry-collector/blob/c9b5b262d71c19e147952de349c86498241ef85c/terraform/groups/ecs-service/gateway-otel-collector-config.yaml).

> **_NOTE 2:_**
`otel/opentelemetry-collector-contrib:0.128.0` image is used instead of building an image locally from the Dockerfile. This is because the Dockerfile is designed to build an image for the `amd64` architecture (AWS) rather than `arm64` (Mac). At the time of writing, although an `arm64` version of [ci-base-build](https://github.com/companieshouse/ci-golang-build/blob/2a974a3f7b2044b6ace0891fb08607423bfe89ac/Dockerfile#L1) exists, the `ci-golang-build` Dockerfile is explicitly tailored for AWS ([see here](https://github.com/companieshouse/ci-golang-build/blob/2a974a3f7b2044b6ace0891fb08607423bfe89ac/Dockerfile#L14-L15)). Consequently, to build a local base image for this repository, you must first generate the appropriate local images. Once that is done, you can proceed by referencing the locally built image (e.g., `otelcol-local`) and running the local collector using it: `IMAGE=otelcol-local ./local-test/run.sh`

#### Example
```bash
./local-test/run.sh validate
config OK
```

### send-spans.sh
Posts a set of test spans to the running collector (`http://localhost:4318/v1/traces`) and then calls `http://localhost:13133/health`. Run it in a second terminal while `run.sh` is running:

```bash
./local-test/send-spans.sh
```

The spans cover the following cases; check the collector's `debug` output (after ~2s) against them:

| Span | Expected |
|------|----------|
| `normal-http` | kept |
| `hc-url.path`, `hc-http.target`, `hc-http.route`, `hc-http.url`, `hc-uri`, `GET /healthcheck` (healthcheck in the attribute / span name) | dropped |
| `kafka-consumer` (kind CONSUMER, with `peer.service`) | kept, `peer.service` removed |
| `kafka-producer` (kind PRODUCER, with `peer.service`) | kept, `peer.service` retained |

The real `awsxray` / `awsemf` exporters are not exercised by these tests.

#### Example
```bash
./local-test/send-spans.sh
HTTP/1.1 200 OK
Content-Type: application/json
Date: Mon, 26 Oct 2026 10:32:07 GMT
Content-Length: 21

{"partialSuccess":{}}
Health:
UP
```

<details>

<summary>expected collector's log</summary>

```bash
2026-10-26T10:32:09.694Z	info	Traces	{"resource": {"service.instance.id": "342ab128-73a9-4123-aaf1-7bb159ddae35", "service.name": "otelcol-contrib", "service.version": "0.128.0"}, "otelcol.component.id": "debug", "otelcol.component.kind": "exporter", "otelcol.signal": "traces", "resource spans": 3, "spans": 3}
2026-10-26T10:32:09.695Z	info	ResourceSpans #0
Resource SchemaURL:
Resource attributes:
     -> service.name: Str(my-service)
ScopeSpans #0
ScopeSpans SchemaURL:
InstrumentationScope
Span #0
    Trace ID       : 011e4b3e34daac2d4772c9aeb56c46b7
    Parent ID      :
    ID             : 22c1c442258be290
    Name           : normal-http
    Kind           : Server
    Start time     : 2026-10-26 10:32:06 +0000 UTC
    End time       : 2026-10-26 10:32:06.001 +0000 UTC
    Status code    : Unset
    Status message :
Attributes:
     -> url.path: Str(/api/users)
ResourceSpans #1
Resource SchemaURL:
Resource attributes:
     -> service.name: Str(my-service)
ScopeSpans #0
ScopeSpans SchemaURL:
InstrumentationScope
Span #0
    Trace ID       : 2275ddb20b3de4262b7866a0d32f1c2a
    Parent ID      :
    ID             : e792a109a7453861
    Name           : kafka-consumer
    Kind           : Consumer
    Start time     : 2026-10-26 10:32:06 +0000 UTC
    End time       : 2026-10-26 10:32:06.001 +0000 UTC
    Status code    : Unset
    Status message :
Attributes:
     -> messaging.kafka.consumer.group: Str(g1)
ResourceSpans #2
Resource SchemaURL:
Resource attributes:
     -> service.name: Str(my-service)
ScopeSpans #0
ScopeSpans SchemaURL:
InstrumentationScope
Span #0
    Trace ID       : d39bfce5cc8387664af6409038526a3d
    Parent ID      :
    ID             : ea58c6620d82b8a3
    Name           : kafka-producer
    Kind           : Producer
    Start time     : 2026-10-26 10:32:06 +0000 UTC
    End time       : 2026-10-26 10:32:06.001 +0000 UTC
    Status code    : Unset
    Status message :
Attributes:
     -> peer.service: Str(Apache Kafka: cluster1)
	{"resource": {"service.instance.id": "342ab128-73a9-4123-aaf1-7bb159ddae35", "service.name": "otelcol-contrib", "service.version": "0.128.0"}, "otelcol.component.id": "debug", "otelcol.component.kind": "exporter", "otelcol.signal": "traces"}
```
</details>

