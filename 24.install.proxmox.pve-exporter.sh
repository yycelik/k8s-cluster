#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-monitoring}"
PROXMOX_TARGET="${PROXMOX_TARGET:-192.168.0.114}"
PROXMOX_USER="${PROXMOX_USER:-prometheus@pve}"
PROXMOX_TOKEN_NAME="${PROXMOX_TOKEN_NAME:-prometheus-token}"
PROXMOX_TOKEN_VALUE="${PROXMOX_TOKEN_VALUE:-CHANGE_ME}"
PROM_RELEASE_LABEL="${PROM_RELEASE_LABEL:-kube-prometheus-stack}"

if [[ "$PROXMOX_TOKEN_VALUE" == "CHANGE_ME" ]]; then
  echo "Set PROXMOX_TOKEN_VALUE before running this script."
  exit 1
fi

kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

kubectl -n "$NAMESPACE" create secret generic proxmox-pve-exporter-config \
  --from-literal=pve.yml="default:
  user: ${PROXMOX_USER}
  token_name: ${PROXMOX_TOKEN_NAME}
  token_value: ${PROXMOX_TOKEN_VALUE}" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: proxmox-pve-exporter
  namespace: ${NAMESPACE}
  labels:
    app: proxmox-pve-exporter
spec:
  replicas: 1
  selector:
    matchLabels:
      app: proxmox-pve-exporter
  template:
    metadata:
      labels:
        app: proxmox-pve-exporter
    spec:
      containers:
      - name: proxmox-pve-exporter
        image: python:3.11-slim
        imagePullPolicy: IfNotPresent
        command:
        - /bin/sh
        - -c
        args:
        - pip install --no-cache-dir prometheus-pve-exporter && exec pve_exporter --config.file=/etc/prometheus/pve.yml --web.listen-address=:9221
        ports:
        - name: http-metrics
          containerPort: 9221
        volumeMounts:
        - name: config
          mountPath: /etc/prometheus/pve.yml
          subPath: pve.yml
          readOnly: true
      volumes:
      - name: config
        secret:
          secretName: proxmox-pve-exporter-config
---
apiVersion: v1
kind: Service
metadata:
  name: proxmox-pve-exporter
  namespace: ${NAMESPACE}
  labels:
    app: proxmox-pve-exporter
spec:
  selector:
    app: proxmox-pve-exporter
  ports:
  - name: http-metrics
    port: 9221
    targetPort: http-metrics
EOF

if kubectl get crd servicemonitors.monitoring.coreos.com >/dev/null 2>&1; then
  kubectl apply -f - <<EOF
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: proxmox-pve-exporter
  namespace: ${NAMESPACE}
  labels:
    release: ${PROM_RELEASE_LABEL}
spec:
  namespaceSelector:
    matchNames:
    - ${NAMESPACE}
  selector:
    matchLabels:
      app: proxmox-pve-exporter
  endpoints:
  - port: http-metrics
    interval: 30s
    scrapeTimeout: 20s
    path: /pve
    params:
      target:
      - ${PROXMOX_TARGET}
      cluster:
      - "1"
      node:
      - "1"
      module:
      - default
EOF
else
  cat <<EOF
ServiceMonitor CRD bulunamadi. Prometheus scrape_config'a su job'i ekle:

- job_name: proxmox-pve
  metrics_path: /pve
  params:
    target: ['${PROXMOX_TARGET}']
    cluster: ['1']
    node: ['1']
    module: ['default']
  static_configs:
  - targets: ['proxmox-pve-exporter.${NAMESPACE}.svc.cluster.local:9221']
EOF
fi

kubectl get pods,svc -n "$NAMESPACE" -l app=proxmox-pve-exporter
