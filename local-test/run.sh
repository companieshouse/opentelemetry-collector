#!/usr/bin/env bash
# Runs the real gateway config locally with AWS exporters replaced by `debug`
# and tail sampling forced to 100% / short decision_wait.
# Usage: ./local-test/run.sh [validate]
# IMAGE defaults to the contrib distro (has every component); set IMAGE=otelcol-local to use your own build.
set -euo pipefail
cd "$(dirname "$0")/.."

SRC=terraform/groups/ecs-service/gateway-otel-collector-config.yaml
OUT=local-test/generated-config.yaml
IMAGE=${IMAGE:-otel/opentelemetry-collector-contrib:0.128.0}

sed -e 's/\[debug,awsxray\]/[debug]/' \
    -e 's/exporters: \[awsemf\(\/collector\)\{0,1\}\]/exporters: [debug]/' \
    -e 's/sampling_percentage: [0-9]* /sampling_percentage: 100 /' \
    -e 's/^  tail_sampling:/  tail_sampling:\n    decision_wait: 2s/' \
    "$SRC" > "$OUT"

if [ "${1:-}" = "validate" ]; then
  docker run --rm -v "$PWD/$OUT:/cfg.yaml:ro" "$IMAGE" validate --config /cfg.yaml && echo "config OK"
  exit
fi

docker run --rm -p 4318:4318 -p 13133:13133 -v "$PWD/$OUT:/cfg.yaml:ro" "$IMAGE" --config /cfg.yaml
