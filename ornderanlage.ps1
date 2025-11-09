# Projektwurzel
$PROJECT_ROOT = (Get-Location).Path

# Funktion für Ordneranlage
function MkdirSafe($p) { if (-not (Test-Path $p)) { New-Item -ItemType Directory -Path $p | Out-Null } }

# Hauptordner
MkdirSafe "$PROJECT_ROOT\data"
MkdirSafe "$PROJECT_ROOT\workflows"
MkdirSafe "$PROJECT_ROOT\shared"
MkdirSafe "$PROJECT_ROOT\observability"
MkdirSafe "$PROJECT_ROOT\web"
MkdirSafe "$PROJECT_ROOT\web\certs"

# n8n
MkdirSafe "$PROJECT_ROOT\data\n8n"
MkdirSafe "$PROJECT_ROOT\observability\n8n-logs"

# Docling
MkdirSafe "$PROJECT_ROOT\data\docling\cache"
MkdirSafe "$PROJECT_ROOT\data\docling\ocr_cache"

# Qdrant
MkdirSafe "$PROJECT_ROOT\data\qdrant\storage"
MkdirSafe "$PROJECT_ROOT\data\qdrant\snapshots"
MkdirSafe "$PROJECT_ROOT\observability\qdrant-logs"

# Ollama
MkdirSafe "$PROJECT_ROOT\data\ollama"

# Observability
MkdirSafe "$PROJECT_ROOT\observability\prometheus"
MkdirSafe "$PROJECT_ROOT\observability\prometheus-data"
MkdirSafe "$PROJECT_ROOT\observability\grafana"
MkdirSafe "$PROJECT_ROOT\observability\grafana-provisioning"
MkdirSafe "$PROJECT_ROOT\observability\loki\data"
MkdirSafe "$PROJECT_ROOT\observability\promtail"
MkdirSafe "$PROJECT_ROOT\observability\tempo"
MkdirSafe "$PROJECT_ROOT\observability\elasticsearch"

# Webserver
MkdirSafe "$PROJECT_ROOT\web\html"
if (-not (Test-Path "$PROJECT_ROOT\web\nginx.conf")) { New-Item -ItemType File -Path "$PROJECT_ROOT\web\nginx.conf" | Out-Null }

# Platzhalter für Observability-Configs
if (-not (Test-Path "$PROJECT_ROOT\observability\prometheus\prometheus.yml")) { New-Item -ItemType File -Path "$PROJECT_ROOT\observability\prometheus\prometheus.yml" | Out-Null }
if (-not (Test-Path "$PROJECT_ROOT\observability\loki\config.yaml")) { New-Item -ItemType File -Path "$PROJECT_ROOT\observability\loki\config.yaml" | Out-Null }
if (-not (Test-Path "$PROJECT_ROOT\observability\promtail\config.yaml")) { New-Item -ItemType File -Path "$PROJECT_ROOT\observability\promtail\config.yaml" | Out-Null }

# .env Beispiel
@"
N8N_USER=admin
N8N_PASSWORD=admin
GRAFANA_USER=admin
GRAFANA_PASSWORD=admin
"@ | Set-Content -Path "$PROJECT_ROOT\.env" -Encoding UTF8
