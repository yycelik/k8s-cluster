#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-otel}"
CHART_VERSION="${CHART_VERSION:-0.150.0}"
KAFKA_BROKERS="${KAFKA_BROKERS:-192.168.0.151:9092}"
KAFKA_TOPIC="${KAFKA_TOPIC:-otel-metrics}"
MIMIR_REMOTE_WRITE_ENDPOINT="${MIMIR_REMOTE_WRITE_ENDPOINT:-http://mimir-gateway.mimir.svc.cluster.local/api/v1/push}"

kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

SCRAPER_VALUES="$(mktemp)"
CONSUMER_VALUES="$(mktemp)"
trap 'rm -f "${SCRAPER_VALUES}" "${CONSUMER_VALUES}"' EXIT

cat > "${SCRAPER_VALUES}" <<EOF
mode: deployment

service:
  enabled: false

image:
  repository: otel/opentelemetry-collector-contrib

replicaCount: 1

ports:
  otlp:
    enabled: false
  otlp-http:
    enabled: false
  jaeger-compact:
    enabled: false
  jaeger-thrift:
    enabled: false
  jaeger-grpc:
    enabled: false
  zipkin:
    enabled: false

config:
  receivers:
    prometheus:
      config:
        global:
          scrape_interval: 15s
          scrape_timeout: 10s
        scrape_configs:
          - job_name: prometheus
            scrape_interval: 5s
            scrape_timeout: 5s
            static_configs:
              - targets: ["192.168.0.151:9090"]
          - job_name: node
            static_configs:
              - targets: ["192.168.0.151:9100"]
          - job_name: proxmox-pve
            metrics_path: /pve
            params:
              target: ["192.168.0.114"]
              cluster: ["1"]
              node: ["1"]
              module: ["default"]
            static_configs:
              - targets: ["192.168.0.240:32221"]
          - job_name: k8s-kube-state-metrics
            static_configs:
              - targets: ["192.168.0.240:32080"]
          - job_name: k8s-cadvisor
            static_configs:
              - targets:
                  - "192.168.0.241:31180"
                  - "192.168.0.242:31180"
                  - "192.168.0.243:31180"
                  - "192.168.0.244:31180"
                  - "192.168.0.245:31180"
                  - "192.168.0.246:31180"
          - job_name: mailu-exporter
            static_configs:
              - targets: ["192.168.0.240:32305"]
  processors:
    batch: {}
  exporters:
    kafka:
      brokers: ["${KAFKA_BROKERS}"]
      protocol_version: 2.0.0
      metrics:
        topic: ${KAFKA_TOPIC}
        encoding: otlp_proto
  extensions:
    health_check: {}
  service:
    extensions: [health_check]
    pipelines:
      metrics:
        receivers: [prometheus]
        processors: [batch]
        exporters: [kafka]
EOF

cat > "${CONSUMER_VALUES}" <<EOF
mode: deployment

service:
  enabled: false

image:
  repository: otel/opentelemetry-collector-contrib

replicaCount: 1

ports:
  otlp:
    enabled: false
  otlp-http:
    enabled: false
  jaeger-compact:
    enabled: false
  jaeger-thrift:
    enabled: false
  jaeger-grpc:
    enabled: false
  zipkin:
    enabled: false

config:
  receivers:
    kafka:
      brokers: ["${KAFKA_BROKERS}"]
      protocol_version: 2.0.0
      group_id: otel-mimir-consumer
      metrics:
        topics: ["${KAFKA_TOPIC}"]
        encoding: otlp_proto
  processors:
    batch: {}
  exporters:
    prometheusremotewrite:
      endpoint: ${MIMIR_REMOTE_WRITE_ENDPOINT}
      headers:
        X-Scope-OrgID: anonymous
      tls:
        insecure: true
  extensions:
    health_check: {}
  service:
    extensions: [health_check]
    pipelines:
      metrics:
        receivers: [kafka]
        processors: [batch]
        exporters: [prometheusremotewrite]
EOF

helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts >/dev/null 2>&1 || true
helm repo update

helm upgrade --install otel-scraper open-telemetry/opentelemetry-collector \
  --namespace "${NAMESPACE}" \
  --version "${CHART_VERSION}" \
  --values "${SCRAPER_VALUES}" \
  --wait \
  --timeout 15m

helm upgrade --install otel-consumer open-telemetry/opentelemetry-collector \
  --namespace "${NAMESPACE}" \
  --version "${CHART_VERSION}" \
  --values "${CONSUMER_VALUES}" \
  --wait \
  --timeout 15m

kubectl get pods -n "${NAMESPACE}" -o wide
