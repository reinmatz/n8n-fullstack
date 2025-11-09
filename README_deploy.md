# n8n RAG System - Deployment Guide

**Version:** 1.0
**Datum:** 9. November 2025
**Plattformen:** macOS M1 (Dev), Windows + NVIDIA 4070 Ti (Test), Linux + NVIDIA A6000 (Prod)

---

## Inhaltsverzeichnis

1. [Systemanforderungen](#systemanforderungen)
2. [Schnellstart](#schnellstart)
3. [Schritt-für-Schritt Installation](#schritt-für-schritt-installation)
4. [n8n Workflow Import](#n8n-workflow-import)
5. [End-to-End Test](#end-to-end-test)
6. [Monitoring & Observability](#monitoring--observability)
7. [Troubleshooting](#troubleshooting)
8. [Backup & Recovery](#backup--recovery)
9. [Produktions-Deployment](#produktions-deployment)

---

## Systemanforderungen

### Mindestanforderungen (Dev/Test)
- **CPU:** 4 Cores (Intel/AMD x86-64 oder Apple Silicon ARM64)
- **RAM:** 16 GB (32 GB empfohlen)
- **Disk:** 50 GB freier Speicher (SSD empfohlen)
- **OS:** macOS 12+, Windows 10/11 (WSL2), Ubuntu 20.04+
- **Docker:** Docker Desktop 4.0+ oder Docker CE 20.10+
- **Docker Compose:** v2.0+

### Produktionsanforderungen
- **CPU:** 16+ Cores
- **RAM:** 64 GB+
- **GPU:** NVIDIA A6000 (48GB) oder äquivalent
- **Disk:** 500 GB NVMe SSD
- **Netzwerk:** 1 Gbps+
- **NVIDIA Container Toolkit:** Neueste Version

---

## Schnellstart

```bash
# 1. Repository klonen
git clone https://github.com/reinmatz/n8n-fullstack.git
cd n8n-fullstack

# 2. Verzeichnisstruktur erstellen
./ordneranlage.sh  # macOS/Linux
# ODER
./ornderanlage.ps1  # Windows PowerShell

# 3. Services starten (alle 17 Container)
docker compose up -d

# 4. Services prüfen
docker compose ps  # Alle sollten "Up" sein

# 5. Ollama-Modelle laden (WICHTIG!)
docker compose exec ollama ollama pull bge-m3
docker compose exec ollama ollama pull qwen2.5:3b-instruct

# 6. PostgreSQL-Schema initialisieren
docker compose exec -T postgres psql -U n8n -d n8n_chat_history < init_postgres_schema.sql

# 7. Qdrant-Collection erstellen
curl -X PUT http://localhost:6333/collections/rag_documents \
  -H "Content-Type: application/json" \
  -d '{"vectors":{"size":1024,"distance":"Cosine"},"hnsw_config":{"m":16,"ef_construct":100}}'

# 8. n8n öffnen und Workflows importieren
open http://localhost:5678  # macOS
# ODER
start http://localhost:5678  # Windows

# 9. Test-Upload
curl -X POST http://localhost:5678/webhook/upload \
  -u admin:admin \
  -F "data=@test-data/sample_document.md"
```

**Fertig!** Das System ist jetzt einsatzbereit.

---

## Schritt-für-Schritt Installation

### 1. Verzeichnisstruktur

Das Setup-Script `ordneranlage.sh` erstellt folgende Struktur:

```
n8n-rag/
├── data/
│   ├── n8n/              # n8n workflows, credentials
│   ├── postgres/         # PostgreSQL data
│   ├── qdrant/
│   │   ├── storage/      # Vector collections
│   │   └── snapshots/    # Backups
│   ├── ollama/           # Downloaded models
│   └── docling/
│       ├── cache/        # Parsing cache
│       └── ocr_cache/    # OCR cache
├── observability/
│   ├── prometheus/       # Metrics storage
│   ├── grafana/          # Dashboards
│   ├── loki/             # Log aggregation
│   ├── tempo/            # Distributed tracing
│   ├── elasticsearch/    # Advanced search
│   └── *-logs/           # Service-specific logs
├── workflows/            # n8n workflow JSONs
├── shared/               # Shared volume (n8n, ollama, docling)
└── web/                  # Nginx config (optional)
```

### 2. Docker Compose Services

Das System besteht aus 17 Services:

**Core:**
- `n8n` (Port 5678): Workflow-Engine
- `postgres` (Port 5432): Chat-History + n8n-DB
- `qdrant` (Ports 6333-6334): Vektordatenbank
- `ollama` (Port 11434): LLM/Embedding-Inferenz
- `docling` (Port 5001): Dokument-Parser

**Observability:**
- `prometheus` (Port 9090): Metrics
- `grafana` (Port 3000): Dashboards
- `loki` (Port 3100): Logs
- `promtail`: Log shipper
- `tempo` (Ports 3200, 4317-4318): Traces
- `elasticsearch` (Port 9200): Search/Analytics
- `kibana` (Port 5601): Elasticsearch UI
- `filebeat`: Log shipper
- `cadvisor` (Port 8080): Container metrics
- `postgres-exporter` (Port 9187): PostgreSQL metrics
- `elasticsearch-exporter` (Port 9114): Elasticsearch metrics

### 3. Ollama-Modelle

**WICHTIG:** Keine Modelle sind vorinstalliert!

#### macOS M1/M2/M3 (CPU-only):
```bash
# Embedding-Modell (1.2 GB)
docker compose exec ollama ollama pull bge-m3

# Chat-LLM (1.9 GB, 3B Parameter)
docker compose exec ollama ollama pull qwen2.5:3b-instruct

# Verifizieren
docker compose exec ollama ollama list
```

#### Windows/Linux mit NVIDIA GPU (12GB):
```bash
# Embedding
docker compose exec ollama ollama pull bge-m3

# Größeres LLM (7B Parameter)
docker compose exec ollama ollama pull qwen2.5:7b-instruct
```

#### Linux Produktion (NVIDIA A6000, 48GB):
```bash
# Embedding
docker compose exec ollama ollama pull bge-m3

# Production-Quality LLM (70B Parameter)
docker compose exec ollama ollama pull llama3.1:70b
```

**GPU-Aktivierung (Windows/Linux):**
```yaml
# In docker-compose.yaml, uncomment für ollama service:
deploy:
  resources:
    reservations:
      devices:
        - capabilities: ["gpu"]
          driver: nvidia
          count: "all"
```

---

## n8n Workflow Import

### Credentials erstellen

**1. n8n UI öffnen:** http://localhost:5678 (admin/admin)

**2. BasicAuth Credential:**
- **Settings** → **Credentials** → **Add Credential**
- Typ: `HTTP Basic Auth`
- Name: `n8n BasicAuth`
- Username: `admin`
- Password: `admin` (oder eigener Wert)
- **Save**

**3. PostgreSQL Credential:**
- Typ: `Postgres`
- Name: `PostgreSQL n8n`
- Host: `postgres`
- Port: `5432`
- Database: `n8n_chat_history`
- User: `n8n`
- Password: `n8n_secure_password` (aus `.env`)
- SSL: `disable`
- **Save**

### Workflows importieren

**1. Upload/Ingestion Workflow:**
- Klick auf **"+"** → **Import from File**
- Wähle: `workflows/01_upload_ingest.json`
- **Import**
- **Save** (Strg+S)
- **Activate** (Toggle oben rechts auf grün)

**2. Chat/Retrieval Workflow:**
- Wiederhole für `workflows/02_chat_retrieval.json`
- **Save** und **Activate**

### Webhook-URLs

Nach Aktivierung sind die Endpoints verfügbar:
- **Upload:** `http://localhost:5678/webhook/upload` (POST)
- **Chat:** `http://localhost:5678/webhook/chat` (POST)

Beide erfordern BasicAuth (`admin:admin`).

---

## End-to-End Test

### 1. Test-Dokument hochladen

```bash
# Markdown-Datei hochladen
curl -X POST http://localhost:5678/webhook/upload \
  -u admin:admin \
  -F "data=@test-data/sample_document.md"
```

**Erwartete Response:**
```json
{
  "success": true,
  "document_id": "uuid",
  "filename": "sample_document.md",
  "chunks_imported": 15,
  "snapshot_hint": "Create backup: curl -X POST http://localhost:6333/collections/rag_documents/snapshots",
  "message": "Document successfully ingested"
}
```

### 2. Qdrant-Verifikation

```bash
# Collection-Info abrufen
curl http://localhost:6333/collections/rag_documents | python3 -m json.tool

# Sollte zeigen:
# "points_count": 15  (Anzahl Chunks)
# "indexed_vectors_count": 15
```

### 3. Chat-Query

```bash
curl -X POST http://localhost:5678/webhook/chat \
  -u admin:admin \
  -H "Content-Type: application/json" \
  -d '{
    "query": "Was sind die Hauptkomponenten eines RAG-Systems?",
    "filters": {}
  }'
```

**Erwartete Response:**
```json
{
  "answer": "Ein RAG-System besteht aus folgenden Hauptkomponenten [1]:\n1. Dokumenten-Ingestion...",
  "sources": [
    {
      "citation": 1,
      "filename": "sample_document.md",
      "page_number": null,
      "section": "Architektur",
      "snippet": "Ein vollständiges RAG-System besteht aus..."
    }
  ],
  "session_id": "uuid",
  "metadata": {
    "query": "Was sind die Hauptkomponenten eines RAG-Systems?",
    "expansion_applied": true,
    "retrieval_sources": "vector+bm25",
    "reranked": true,
    "model": "qwen2.5:3b-instruct"
  }
}
```

### 4. Zitations-Prüfung

Die Response sollte:
- ✅ Zitationsmarker enthalten (`[1]`, `[2]`, etc.)
- ✅ `sources`-Array mit Dateiname, Section, Snippet
- ✅ Korrekte Informationen aus dem Dokument

### 5. PostgreSQL Chat-History

```bash
# Chat-Historie anzeigen
docker compose exec postgres psql -U n8n -d n8n_chat_history -c \
  "SELECT session_id, role, LEFT(content, 50) as content_preview, timestamp
   FROM messages
   ORDER BY timestamp DESC
   LIMIT 10;"
```

---

## Monitoring & Observability

### Prometheus (Metriken)

**URL:** http://localhost:9090

**Wichtige Queries:**
```promql
# n8n Workflow-Ausführungen
n8n_workflow_executions_total

# Qdrant Query-Latenz
qdrant_request_duration_seconds{operation="search"}

# PostgreSQL Verbindungen
pg_stat_database_numbackends{datname="n8n_chat_history"}

# Ollama Inference-Dauer
# (Custom metric via n8n logging)
```

### Grafana (Dashboards)

**URL:** http://localhost:3000 (admin/admin)

**Empfohlene Dashboards:**
1. **RAG Pipeline Overview:**
   - Upload-Rate (requests/min)
   - Embedding-Latenz (p50, p95, p99)
   - Chat-Latenz (end-to-end)
   - Error-Rate

2. **Qdrant Performance:**
   - Vector Search-Latenz
   - Index-Größe
   - Memory-Usage

3. **PostgreSQL Metrics:**
   - Connection Pool
   - Query-Latenz
   - Disk I/O

**Dashboard-Import:**
- Suche nach "n8n", "Qdrant", "PostgreSQL" in Grafana Labs

### Loki (Logs)

**URL:** http://localhost:3100

**LogQL-Queries (in Grafana):**
```logql
# n8n Workflow-Logs
{container_name="n8n"}

# Qdrant Fehler
{container_name="qdrant"} |= "error"

# Ollama Inference-Logs
{container_name="ollama"} |= "generate"
```

### Kibana (Elasticsearch)

**URL:** http://localhost:5601

**Use Cases:**
- Full-Text Search über alle Logs
- Custom Dashboards für Chat-Analysen
- Anomaly Detection

---

## Troubleshooting

### Services starten nicht

**Problem:** Service in Restart-Loop
```bash
# Logs prüfen
docker compose logs --tail=50 [service-name]

# Häufige Ursachen:
# 1. Port bereits belegt
sudo lsof -i :5678  # n8n Port

# 2. Volume-Permissions
ls -la data/

# 3. Speicher voll
df -h
```

### Ollama-Modell nicht gefunden

**Fehler:** `Error: model 'bge-m3' not found`

**Lösung:**
```bash
# Modelle prüfen
docker compose exec ollama ollama list

# Modell nachträglich laden
docker compose exec ollama ollama pull bge-m3
```

### Qdrant Collection nicht vorhanden

**Fehler:** `Collection 'rag_documents' not found`

**Lösung:**
```bash
# Collection neu erstellen
curl -X PUT http://localhost:6333/collections/rag_documents \
  -H "Content-Type: application/json" \
  -d '{"vectors":{"size":1024,"distance":"Cosine"},"hnsw_config":{"m":16,"ef_construct":100}}'

# Payload-Indizes erstellen
curl -X PUT http://localhost:6333/collections/rag_documents/index \
  -H "Content-Type: application/json" \
  -d '{"field_name":"filename","field_schema":"keyword"}'
```

### n8n Workflow-Fehler

**Problem:** Webhook gibt 404

**Lösung:**
1. Workflow aktiviert? (Toggle in n8n UI)
2. Credentials konfiguriert?
3. n8n Logs prüfen: `docker compose logs n8n`

**Problem:** "Credential not found"

**Lösung:**
- Credentials **vor** Workflow-Import erstellen
- IDs in Workflow-JSON anpassen falls nötig

### PostgreSQL Connection Fehler

**Fehler:** `Connection refused`

**Lösung:**
```bash
# PostgreSQL Status
docker compose ps postgres

# Logs
docker compose logs postgres

# Manueller Connection-Test
docker compose exec postgres psql -U n8n -d n8n_chat_history -c "SELECT version();"
```

### Docling Parsing-Fehler

**Problem:** PDF-Upload schlägt fehl

**Lösung:**
```bash
# Docling Logs
docker compose logs docling

# Docling Health-Check
curl http://localhost:5001/health

# Docling neu starten
docker compose restart docling
```

### Out of Memory (OOM)

**Symptome:** Container killed, Restart-Loops

**Lösung:**
```bash
# Docker Memory-Limit erhöhen (Docker Desktop)
# Settings → Resources → Memory: 16GB+

# Ollama Modell-Größe reduzieren
docker compose exec ollama ollama pull qwen2.5:3b-instruct  # statt 7b

# Monitoring
docker stats
```

---

## Backup & Recovery

### Qdrant Snapshots

**Manueller Snapshot:**
```bash
# Snapshot erstellen
curl -X POST http://localhost:6333/collections/rag_documents/snapshots

# Snapshots auflisten
ls -la data/qdrant/snapshots/

# Snapshot-Info
curl http://localhost:6333/collections/rag_documents/snapshots
```

**Automatisierung (Cron):**
```bash
# Crontab bearbeiten
crontab -e

# Täglich um 2 Uhr
0 2 * * * curl -X POST http://localhost:6333/collections/rag_documents/snapshots
```

**Recovery:**
```bash
# Qdrant stoppen
docker compose stop qdrant

# Snapshot wiederherstellen (in Qdrant-Container)
docker compose exec qdrant qdrant-cli \
  recover \
  --collection rag_documents \
  --snapshot /qdrant/snapshots/rag_documents-[timestamp].snapshot

# Qdrant starten
docker compose start qdrant
```

### PostgreSQL Backup

```bash
# Dump erstellen
docker compose exec postgres pg_dump -U n8n n8n_chat_history > backup_chat_history_$(date +%Y%m%d).sql

# Wiederherstellen
docker compose exec -T postgres psql -U n8n -d n8n_chat_history < backup_chat_history_20251109.sql
```

### Komplett-Backup

```bash
# Services stoppen
docker compose down

# Tar-Archive erstellen
tar -czf n8n-rag-backup-$(date +%Y%m%d).tar.gz \
  data/ \
  workflows/ \
  .env \
  docker-compose.yaml \
  init_postgres_schema.sql

# Services starten
docker compose up -d
```

**Offsite-Backup (empfohlen):**
```bash
# Rsync zu Remote-Server
rsync -avz n8n-rag-backup-*.tar.gz user@backup-server:/backups/

# Oder S3
aws s3 cp n8n-rag-backup-*.tar.gz s3://my-bucket/backups/
```

---

## Produktions-Deployment

### Checkliste

- [ ] **Hardware:** 16+ CPU Cores, 64GB+ RAM, NVIDIA GPU (optional)
- [ ] **OS:** Ubuntu 22.04 LTS (empfohlen)
- [ ] **Docker:** Docker CE + NVIDIA Container Toolkit (für GPU)
- [ ] **Netzwerk:** Firewall konfiguriert (nur Ports 80, 443 öffentlich)
- [ ] **SSL/TLS:** Nginx mit Let's Encrypt Zertifikaten
- [ ] **Credentials:** Sichere Passwörter in `.env` (nicht `admin/admin`!)
- [ ] **Backup:** Automatisierte Snapshots + Offsite-Kopien
- [ ] **Monitoring:** Grafana-Dashboards + Alerting (PagerDuty, Slack)
- [ ] **Logging:** Loki + Elasticsearch Retention-Policies
- [ ] **High Availability:** Load-Balancer, Read-Replicas für Qdrant/PostgreSQL

### GPU-Konfiguration (A6000)

**1. NVIDIA Container Toolkit installieren:**
```bash
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | \
  sudo tee /etc/apt/sources.list.d/nvidia-docker.list

sudo apt-get update
sudo apt-get install -y nvidia-docker2
sudo systemctl restart docker
```

**2. GPU in docker-compose.yaml aktivieren:**
```yaml
services:
  ollama:
    deploy:
      resources:
        reservations:
          devices:
            - capabilities: ["gpu"]
              driver: nvidia
              count: "all"
```

**3. GPU-Zugriff testen:**
```bash
docker compose exec ollama nvidia-smi
```

### Systemd Unit (Auto-Start)

```bash
# Systemd-Unit erstellen
sudo nano /etc/systemd/system/n8n-rag.service
```

```ini
[Unit]
Description=n8n RAG System
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/n8n-rag
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
User=n8n-user
Group=docker

[Install]
WantedBy=multi-user.target
```

```bash
# Aktivieren
sudo systemctl enable n8n-rag
sudo systemctl start n8n-rag

# Status
sudo systemctl status n8n-rag
```

### Nginx Reverse Proxy (SSL)

**1. Nginx installieren:**
```bash
sudo apt install nginx certbot python3-certbot-nginx
```

**2. Konfiguration:**
```nginx
# /etc/nginx/sites-available/n8n-rag
server {
    listen 80;
    server_name rag.example.com;

    location / {
        proxy_pass http://localhost:5678;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

**3. SSL mit Let's Encrypt:**
```bash
sudo ln -s /etc/nginx/sites-available/n8n-rag /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx

sudo certbot --nginx -d rag.example.com
```

### Skalierung

**Horizontal Scaling:**
- **Load-Balancer:** Nginx/HAProxy vor n8n-Instanzen
- **Qdrant:** Read-Replicas für Queries
- **PostgreSQL:** Master-Slave Replication
- **Ollama:** Separate Inferenz-Nodes mit Load-Balancing

**Monitoring & Alerting:**
```yaml
# prometheus/alerts.yml
groups:
  - name: rag_alerts
    rules:
      - alert: HighErrorRate
        expr: rate(n8n_workflow_errors_total[5m]) > 0.1
        for: 5m
        annotations:
          summary: "High error rate in n8n workflows"

      - alert: QdrantMemoryHigh
        expr: qdrant_memory_usage_bytes > 50e9  # 50GB
        for: 10m
        annotations:
          summary: "Qdrant memory usage high"
```

---

## Weitere Ressourcen

- **Projekt-Repository:** https://github.com/reinmatz/n8n-fullstack
- **n8n Dokumentation:** `n8n_docs_combined.md` (lokal)
- **Qdrant Docs:** https://qdrant.tech/documentation/
- **Ollama Model Library:** https://ollama.ai/library
- **Prometheus Query Examples:** https://prometheus.io/docs/prometheus/latest/querying/examples/

---

## Support & Troubleshooting

Bei Problemen siehe `CLAUDE.md` für erweiterte Guides oder erstelle ein Issue:
https://github.com/reinmatz/n8n-fullstack/issues

---

**Version:** 1.0
**Erstellt:** 9. November 2025
**Autor:** RAG System Team
