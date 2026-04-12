#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# Grafana'ya OTel Collector ve Mimir izleme dashboardlarını import et
#
# Gereksinimler:
#   - Grafana API erişimi
#   - "Mimir" adında Prometheus-type datasource (27.01 script'i ile eklenir)
#
# Kullanılan dashboardlar:
#   - OpenTelemetry Collector    : Grafana Labs ID 15983
#   - Mimir / Writes             : Grafana Labs ID 16026
#   - Mimir / Reads              : Grafana Labs ID 16016
#   - Mimir / Overview resources : Grafana Labs ID 17606
#   - Mimir / Overview networking: Grafana Labs ID 17605
###############################################################################

GRAFANA_URL="${GRAFANA_URL:-https://grafana.s3t.co}"
GRAFANA_USER="${GRAFANA_USER:-admin}"
GRAFANA_PASS="${GRAFANA_PASS:-ChangeMe123!}"
DATASOURCE_NAME="${DATASOURCE_NAME:-Mimir}"

# --- Yardımcı fonksiyon: dashboard'u Grafana.com'dan indir ve import et ------
import_dashboard() {
  local DASH_ID="$1"
  local DASH_TITLE="$2"
  local DS_NAME="$3"

  echo ">>> [${DASH_ID}] ${DASH_TITLE} import ediliyor..."

  # Grafana.com API'sinden dashboard JSON'u çek
  local JSON
  JSON=$(curl -sk "https://grafana.com/api/dashboards/${DASH_ID}/revisions/latest/download")

  if [ -z "$JSON" ] || echo "$JSON" | grep -q '"status":"not-found"'; then
    echo "    HATA: Dashboard ${DASH_ID} indirilemedi, atlaniyor."
    return 1
  fi

  # datasource UID'sini al
  local DS_UID
  DS_UID=$(curl -sk -u "${GRAFANA_USER}:${GRAFANA_PASS}" \
    "${GRAFANA_URL}/api/datasources/name/${DS_NAME}" | \
    python3 -c "import sys,json; print(json.load(sys.stdin).get('uid',''))" 2>/dev/null || true)

  if [ -z "$DS_UID" ]; then
    echo "    UYARI: '${DS_NAME}' datasource bulunamiyor, default kullanilacak."
    DS_UID=""
  fi

  # Import payload oluştur
  local PAYLOAD
  PAYLOAD=$(python3 -c "
import json, sys

dashboard = json.loads('''${JSON}'''.replace(\"'''\", \"\\\\'''\"))

# Dashboard ID'yi kaldır (yeni oluşturulsun)
dashboard.pop('id', None)

payload = {
    'dashboard': dashboard,
    'overwrite': True,
    'inputs': [
        {
            'name': 'DS_PROMETHEUS',
            'type': 'datasource',
            'pluginId': 'prometheus',
            'value': '${DS_UID}'
        },
        {
            'name': 'DS_MIMIR',
            'type': 'datasource',
            'pluginId': 'prometheus',
            'value': '${DS_UID}'
        }
    ],
    'folderId': 0
}

print(json.dumps(payload))
" 2>/dev/null)

  if [ -z "$PAYLOAD" ]; then
    # python3 başarısız olduysa basit yöntem
    PAYLOAD=$(cat <<ENDJSON
{
  "dashboard": ${JSON},
  "overwrite": true,
  "inputs": [
    {"name":"DS_PROMETHEUS","type":"datasource","pluginId":"prometheus","value":"${DS_UID}"},
    {"name":"DS_MIMIR","type":"datasource","pluginId":"prometheus","value":"${DS_UID}"}
  ],
  "folderId": 0
}
ENDJSON
)
  fi

  # Import et
  local RESULT
  RESULT=$(curl -sk -X POST "${GRAFANA_URL}/api/dashboards/import" \
    -u "${GRAFANA_USER}:${GRAFANA_PASS}" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD")

  if echo "$RESULT" | grep -q '"imported"'; then
    echo "    OK: ${DASH_TITLE} basariyla import edildi."
  elif echo "$RESULT" | grep -q '"slug"'; then
    echo "    OK: ${DASH_TITLE} import edildi."
  else
    echo "    SONUC: $RESULT"
  fi
}

echo "============================================================"
echo " Grafana Dashboard Import — OTel & Mimir Monitoring"
echo "============================================================"
echo ""

# ---------- OTel Collector Dashboard ----------
import_dashboard 15983 "OpenTelemetry Collector" "${DATASOURCE_NAME}"

# ---------- Mimir Dashboards ----------
import_dashboard 16026 "Mimir / Writes"              "${DATASOURCE_NAME}"
import_dashboard 16016 "Mimir / Reads"               "${DATASOURCE_NAME}"
import_dashboard 17606 "Mimir / Overview resources"   "${DATASOURCE_NAME}"
import_dashboard 17605 "Mimir / Overview networking"  "${DATASOURCE_NAME}"

echo ""
echo "============================================================"
echo " Tamamlandı! Grafana'da şu dashboardları kontrol edin:  "
echo "   • OpenTelemetry Collector                              "
echo "   • Mimir / Writes                                       "
echo "   • Mimir / Reads                                        "
echo "   • Mimir / Overview resources                           "
echo "   • Mimir / Overview networking                          "
echo "============================================================"
echo ""
echo "NOT: Dashboardlar ds_name olarak Mimir kullanir."
echo "     Eger farkli isim verdiyseniz DATASOURCE_NAME env'ini degistirin."
echo ""
echo "--- Manuel import icin ---"
echo "Grafana UI > Dashboards > Import > ID girin:"
echo "  15983 = OpenTelemetry Collector"
echo "  16026 = Mimir / Writes"
echo "  16016 = Mimir / Reads"
echo "  17606 = Mimir / Overview resources"
echo "  17605 = Mimir / Overview networking"
