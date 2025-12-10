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

