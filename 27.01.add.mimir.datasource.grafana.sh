#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# Grafana'ya Mimir datasource ekle (Prometheus-compatible)
# Mimir gateway üzerinden query yapılır.
###############################################################################

GRAFANA_URL="${GRAFANA_URL:-https://grafana.s3t.co}"
GRAFANA_USER="${GRAFANA_USER:-admin}"
GRAFANA_PASS="${GRAFANA_PASS:-ChangeMe123!}"
MIMIR_URL="${MIMIR_URL:-http://mimir-gateway.mimir.svc.cluster.local/prometheus}"

echo "=== Mimir datasource'u Grafana'ya ekleniyor ==="

# Yöntem 1: Grafana API ile (dışarıdan erişim)
curl -sk -X POST "${GRAFANA_URL}/api/datasources" \
  -u "${GRAFANA_USER}:${GRAFANA_PASS}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Mimir",
    "type": "prometheus",
    "access": "proxy",
    "url": "'"${MIMIR_URL}"'",
    "isDefault": false,
    "editable": true,
    "jsonData": {
      "httpHeaderName1": "X-Scope-OrgID",
      "timeInterval": "15s",
      "httpMethod": "POST"
    },
    "secureJsonData": {
      "httpHeaderValue1": "anonymous"
    }
  }'

echo ""
echo "=== Mimir datasource eklendi ==="
echo ""
echo "Alternatif: Helm values dosyasına şunu ekleyip upgrade yapabilirsiniz:"
cat <<'HINT'

# grafana-values.yaml içine ekle:
datasources:
  datasources.yaml:
    apiVersion: 1
    datasources:
      - name: Prometheus
        type: prometheus
        access: proxy
        isDefault: true
        url: http://prometheus-server.prometheus.svc.cluster.local
        editable: true
      - name: Mimir
        type: prometheus
        access: proxy
        isDefault: false
        url: http://mimir-gateway.mimir.svc.cluster.local/prometheus
        editable: true
        jsonData:
          httpHeaderName1: X-Scope-OrgID
          timeInterval: 15s
          httpMethod: POST
        secureJsonData:
          httpHeaderValue1: anonymous

# Sonra:
# helm upgrade grafana grafana/grafana -n grafana -f grafana-values.yaml
HINT
