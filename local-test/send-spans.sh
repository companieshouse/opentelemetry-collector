#!/usr/bin/env bash
# Sends test spans to the local collector. Expected in `debug` output (after ~2s):
#   KEPT    "normal-http"        (no healthcheck)
#   DROPPED "hc-url.path", "hc-http.target", "hc-http.route", "hc-http.url", "hc-uri", "GET /healthcheck" (name)
#   KEPT    "kafka-consumer"     WITHOUT peer.service
#   KEPT    "kafka-producer"     WITH peer.service (only CONSUMER is stripped)
set -euo pipefail

NOW=$(( $(date +%s) * 1000000000 ))
END=$(( NOW + 1000000 ))

span() { # name kind attrs-json
  local id; id=$(openssl rand -hex 8)
  cat <<EOF
{"traceId":"$(openssl rand -hex 16)","spanId":"$id","name":"$1","kind":$2,
 "startTimeUnixNano":"$NOW","endTimeUnixNano":"$END","attributes":[$3]}
EOF
}
s() { echo "{\"key\":\"$1\",\"value\":{\"stringValue\":\"$2\"}}"; }

SPANS=$(cat <<EOF
$(span normal-http 2 "$(s url.path /api/users)"),
$(span hc-url.path 2 "$(s url.path /healthcheck)"),
$(span hc-http.target 2 "$(s http.target /healthcheck)"),
$(span hc-http.route 2 "$(s http.route /healthcheck)"),
$(span hc-http.url 2 "$(s http.url http://x/healthcheck)"),
$(span hc-uri 2 "$(s uri /healthcheck)"),
$(span "GET /healthcheck" 2 ""),
$(span kafka-consumer 5 "$(s peer.service 'Apache Kafka: cluster1'),$(s messaging.kafka.consumer.group g1)"),
$(span kafka-producer 4 "$(s peer.service 'Apache Kafka: cluster1')")
EOF
)

curl -sS -i -X POST http://localhost:4318/v1/traces -H 'Content-Type: application/json' -d "{
 \"resourceSpans\":[{\"resource\":{\"attributes\":[$(s service.name my-service)]},
 \"scopeSpans\":[{\"spans\":[$SPANS]}]}]}"
echo
echo "Health:"; curl -sS http://localhost:13133/health; echo
