#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-mimir}"
RELEASE="${RELEASE:-mimir}"
CHART_VERSION="${CHART_VERSION:-6.0.6}"
KAFKA_ADDRESS="${KAFKA_ADDRESS:-192.168.0.151:9092}"
KAFKA_TOPIC="${KAFKA_TOPIC:-mimir-ingest}"
MINIO_NAMESPACE="${MINIO_NAMESPACE:-minio}"
MINIO_SECRET_NAME="${MINIO_SECRET_NAME:-minio}"
MINIO_ENDPOINT="${MINIO_ENDPOINT:-minio.minio.svc.cluster.local:9000}"
BLOCKS_BUCKET="${BLOCKS_BUCKET:-mimir-blocks}"
STORAGE_CLASS="${STORAGE_CLASS:-longhorn}"
MC_IMAGE="${MC_IMAGE:-minio/mc:RELEASE.2025-08-13T08-35-41Z}"

kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

MINIO_USER="$(kubectl get secret -n "${MINIO_NAMESPACE}" "${MINIO_SECRET_NAME}" -o jsonpath='{.data.rootUser}' | base64 -d)"
MINIO_PASSWORD="$(kubectl get secret -n "${MINIO_NAMESPACE}" "${MINIO_SECRET_NAME}" -o jsonpath='{.data.rootPassword}' | base64 -d)"

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: mimir-minio-env
  namespace: ${NAMESPACE}
type: Opaque
stringData:
  MINIO_USER: "${MINIO_USER}"
  MINIO_PASSWORD: "${MINIO_PASSWORD}"
EOF

kubectl -n "${NAMESPACE}" delete pod mimir-mc --ignore-not-found=true >/dev/null 2>&1 || true
kubectl run mimir-mc \
  -n "${NAMESPACE}" \
  --image="${MC_IMAGE}" \
  --restart=Never \
  --env="MC_HOST_mimir=http://${MINIO_USER}:${MINIO_PASSWORD}@${MINIO_ENDPOINT}" \
  --command -- sh -c "mc mb --ignore-existing mimir/${BLOCKS_BUCKET}"
kubectl wait --for=jsonpath='{.status.phase}'=Succeeded pod/mimir-mc -n "${NAMESPACE}" --timeout=180s
kubectl -n "${NAMESPACE}" delete pod mimir-mc --ignore-not-found=true >/dev/null 2>&1 || true

VALUES_FILE="$(mktemp)"
trap 'rm -f "${VALUES_FILE}"' EXIT

cat > "${VALUES_FILE}" <<EOF
global:
  extraEnv:
    - name: POD_IP
      valueFrom:
        fieldRef:
          fieldPath: status.podIP

minio:
  enabled: false

kafka:
  enabled: false

rollout_operator:
  enabled: false

alertmanager:
  enabled: false

ruler:
  enabled: false

overrides_exporter:
  enabled: false

gateway:
  replicas: 1

distributor:
  replicas: 1

ingester:
  replicas: 1
  zoneAwareReplication:
    enabled: false
  persistentVolume:
    enabled: true
    size: 10Gi
    storageClass: ${STORAGE_CLASS}

querier:
  replicas: 1

query_frontend:
  replicas: 1

query_scheduler:
  enabled: true
  replicas: 1

store_gateway:
  replicas: 1
  zoneAwareReplication:
    enabled: false
  persistentVolume:
    enabled: true
    size: 10Gi
    storageClass: ${STORAGE_CLASS}

compactor:
  replicas: 1
  persistentVolume:
    enabled: true
    size: 10Gi
    storageClass: ${STORAGE_CLASS}

mimir:
  structuredConfig:
    limits:
      max_label_names_per_series: 60
    memberlist:
      advertise_addr: \${POD_IP}
    blocks_storage:
      backend: s3
      s3:
        endpoint: ${MINIO_ENDPOINT}
        bucket_name: ${BLOCKS_BUCKET}
        access_key_id: ${MINIO_USER}
        secret_access_key: ${MINIO_PASSWORD}
        insecure: true
    distributor:
      remote_timeout: 10s
    ingest_storage:
      enabled: true
      kafka:
        address: ${KAFKA_ADDRESS}
        topic: ${KAFKA_TOPIC}
        auto_create_topic_enabled: true
        auto_create_topic_default_partitions: 1
EOF

helm repo add grafana https://grafana.github.io/helm-charts >/dev/null 2>&1 || true
helm repo update

helm upgrade --install "${RELEASE}" grafana/mimir-distributed \
  --namespace "${NAMESPACE}" \
  --version "${CHART_VERSION}" \
  --values "${VALUES_FILE}" \
  --wait \
  --timeout 20m

kubectl get pods -n "${NAMESPACE}" -o wide
