# Projektwurzel
PROJECT_ROOT="$(pwd)"  # ggf. anpassen

# Hauptordner
mkdir -p "$PROJECT_ROOT"/{data,workflows,shared,observability,web}

# n8n
mkdir -p "$PROJECT_ROOT"/data/n8n
mkdir -p "$PROJECT_ROOT"/observability/n8n-logs

# Docling
mkdir -p "$PROJECT_ROOT"/data/docling/{cache,ocr_cache}

# Qdrant
mkdir -p "$PROJECT_ROOT"/data/qdrant/{storage,snapshots}
mkdir -p "$PROJECT_ROOT"/observability/qdrant-logs

# Ollama
mkdir -p "$PROJECT_ROOT"/data/ollama

# Observability: Prometheus, Grafana, Loki, Promtail, Tempo, Elasticsearch
mkdir -p "$PROJECT_ROOT"/observability/prometheus
mkdir -p "$PROJECT_ROOT"/observability/prometheus-data
mkdir -p "$PROJECT_ROOT"/observability/grafana
mkdir -p "$PROJECT_ROOT"/observability/grafana-provisioning
mkdir -p "$PROJECT_ROOT"/observability/loki/{data}
mkdir -p "$PROJECT_ROOT"/observability/promtail
mkdir -p "$PROJECT_ROOT"/observability/tempo
mkdir -p "$PROJECT_ROOT"/observability/elasticsearch

# Webserver (Nginx)
mkdir -p "$PROJECT_ROOT"/web
mkdir -p "$PROJECT_ROOT"/web/certs
mkdir -p "$PROJECT_ROOT"/web/html
# Beispiel-Konfig-Dateiplatzhalter (wird später befüllt)
touch "$PROJECT_ROOT"/web/nginx.conf

# Beispiel-Config-Platzhalter für Observability
touch "$PROJECT_ROOT"/observability/prometheus/prometheus.yml
touch "$PROJECT_ROOT"/observability/loki/config.yaml
touch "$PROJECT_ROOT"/observability/promtail/config.yaml

# Rechte (optional; passe UID/GID an, falls notwendig)
chmod -R 755 "$PROJECT_ROOT"/web/html
chmod -R 750 "$PROJECT_ROOT"/observability
chmod -R 750 "$PROJECT_ROOT"/data

# .env-Beispiel (optional)
cat > "$PROJECT_ROOT"/.env << 'EOF'
N8N_USER=admin
N8N_PASSWORD=admin
GRAFANA_USER=admin
GRAFANA_PASSWORD=admin
EOF
