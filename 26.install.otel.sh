#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-otel}"
CHART_VERSION="${CHART_VERSION:-0.150.0}"
KAFKA_BROKERS="${KAFKA_BROKERS:-192.168.0.151:9092}"
KAFKA_TOPIC="${KAFKA_TOPIC:-otel-metrics}"
MIMIR_REMOTE_WRITE_ENDPOINT="${MIMIR_REMOTE_WRITE_ENDPOINT:-http://mimir-gateway.mimir.svc.cluster.local/api/v1/push}"

kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: otel-scraper-metrics
  namespace: ${NAMESPACE}
spec:
  selector:
    app.kubernetes.io/instance: otel-scraper
    app.kubernetes.io/name: opentelemetry-collector
  ports:
    - name: metrics
      port: 8888
      targetPort: 8888
---
apiVersion: v1
kind: Service
metadata:
  name: otel-consumer-metrics
  namespace: ${NAMESPACE}
spec:
  selector:
    app.kubernetes.io/instance: otel-consumer
    app.kubernetes.io/name: opentelemetry-collector
  ports:
    - name: metrics
      port: 8888
      targetPort: 8888
EOF

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
          - job_name: otel-scraper
            static_configs:
              - targets: ["otel-scraper-metrics.${NAMESPACE}.svc.cluster.local:8888"]
          - job_name: otel-consumer
            static_configs:
              - targets: ["otel-consumer-metrics.${NAMESPACE}.svc.cluster.local:8888"]
          - job_name: mimir
            static_configs:
              - targets:
                  - "mimir-compactor.mimir.svc.cluster.local:8080"
                  - "mimir-distributor.mimir.svc.cluster.local:8080"
                  - "mimir-gateway.mimir.svc.cluster.local:8080"
                  - "mimir-ingester.mimir.svc.cluster.local:8080"
                  - "mimir-querier.mimir.svc.cluster.local:8080"
                  - "mimir-query-frontend.mimir.svc.cluster.local:8080"
                  - "mimir-query-scheduler.mimir.svc.cluster.local:8080"
                  - "mimir-store-gateway.mimir.svc.cluster.local:8080"
                labels:
                  cluster: s3t-k8s
                  namespace: mimir
  processors:
    attributes/mimir_labels:
      actions:
        - key: cluster
          value: s3t-k8s
          action: upsert
        - key: namespace
          value: mimir
          action: upsert
      include:
        match_type: regexp
        metric_names:
          - "cortex_.*"
          - "thanos_.*"
    batch:
      send_batch_size: 200
      send_batch_max_size: 200
      timeout: 1s
  exporters:
    kafka:
      brokers: ["${KAFKA_BROKERS}"]
      protocol_version: 2.0.0
      producer:
        max_message_bytes: 10485760
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
        processors: [attributes/mimir_labels, batch]
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
    attributes/drop_excess_metric_labels:
      actions:
        - pattern: ^container_label_.*
          action: delete
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
        processors: [attributes/drop_excess_metric_labels, batch]
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
