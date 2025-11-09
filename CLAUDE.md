# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a fully local, self-hosted RAG (Retrieval-Augmented Generation) system built on Docker Compose. It enables document ingestion (PDF, DOCX, XLSX, MD, TXT) and semantic search/chat using local LLMs, optimized for German language content with minimal hallucinations.

**Key Components:**
- **n8n**: Workflow orchestration for upload/ingestion and chat/retrieval pipelines
- **PostgreSQL**: Chat history and n8n data persistence
- **Qdrant**: Vector database with HNSW indexing, metadata filtering, and snapshot support
- **Ollama**: Local LLM inference and embeddings (supports GPU acceleration)
- **Docling Serve**: Document parsing service (PDF, DOCX, XLSX to structured JSON)
- **Observability Stack**: Prometheus, Grafana, Loki, Tempo, Elasticsearch/Kibana, cAdvisor, Filebeat
- **Exporters**: postgres-exporter, elasticsearch-exporter for Prometheus metrics

**Target Platforms:**
- Dev: macOS M1 (ARM64, CPU-only)
- Test: Windows with NVIDIA 4070 Ti (12GB)
- Prod: Linux with NVIDIA A6000 (48GB)

## Common Commands

### Start/Stop the Stack
```bash
# Start all services
docker compose up -d

# Stop all services
docker compose down

# View logs for specific service
docker compose logs -f n8n
docker compose logs -f qdrant
docker compose logs -f ollama
docker compose logs -f postgres

# Check service status
docker compose ps

# Restart a specific service
docker compose restart n8n
```

### PostgreSQL Management
```bash
# Access PostgreSQL CLI
docker compose exec postgres psql -U n8n -d n8n_chat_history

# View chat history
docker compose exec postgres psql -U n8n -d n8n_chat_history -c "SELECT * FROM pg_tables WHERE schemaname='public';"

# Check PostgreSQL metrics
curl http://localhost:9187/metrics

# View PostgreSQL logs
docker compose logs -f postgres
```

### Ollama Model Management
```bash
# IMPORTANT: No models are installed by default. You must pull them first.

# List installed models (check what's available)
docker compose exec ollama ollama list

# Pull embedding model (German-optimized) - REQUIRED
docker compose exec ollama ollama pull bge-m3

# Pull LLM for chat/QA - REQUIRED (choose based on your GPU)
docker compose exec ollama ollama pull qwen2.5:7b-instruct  # For 12GB GPU (4070 Ti)
docker compose exec ollama ollama pull llama3.1:70b         # For 48GB GPU (A6000)

# For macOS M1/M2/M3 (CPU-only, choose smaller models)
docker compose exec ollama ollama pull qwen2.5:3b-instruct
docker compose exec ollama ollama pull llama3.2:3b

# Pull reranker model (optional, improves accuracy)
docker compose exec ollama ollama pull bge-reranker-base

# Check model details
docker compose exec ollama ollama show bge-m3

# Remove a model (if needed)
docker compose exec ollama ollama rm [model-name]
```

### Qdrant Operations
```bash
# Access Qdrant REST API (from host)
curl http://localhost:6333/collections

# Create manual snapshot
docker compose exec qdrant curl -X POST http://localhost:6333/collections/{collection_name}/snapshots

# List snapshots
ls -la data/qdrant/snapshots/
```

### n8n Workflow Management
```bash
# Access n8n UI
# Direct access (port is exposed): http://localhost:5678
# Default credentials: admin/admin (configured in .env)
# Username: admin
# Password: admin

# Export workflows (via UI)
# 1. Open workflow in n8n UI
# 2. Click "..." menu → Download
# 3. Save to ./workflows/ directory
# 4. Recommended naming: 01_upload_ingest.json, 02_chat_retrieval.json

# Import workflows (via UI)
# 1. Open n8n UI
# 2. Click "..." → Import from File
# 3. Select workflow JSON from ./workflows/

# Access n8n container
docker compose exec -it n8n /bin/sh

# View n8n metrics
curl http://localhost:5678/metrics

# Note: workflows/ directory is currently empty - create workflows first
```

### Directory Structure Setup
```bash
# Initial directory creation (already automated in ordneranlage.sh)
./ordneranlage.sh

# Or manually check required directories exist:
# data/{n8n,docling/{cache,ocr_cache},qdrant/{storage,snapshots},ollama}
# observability/{prometheus,grafana,loki,promtail,tempo,elasticsearch,*-logs}
# web/{certs,html}, workflows/, shared/
```

## Architecture

### Service Communication
All services run in a dedicated Docker bridge network (`rag-net`) with DNS-based service discovery. Services communicate via internal DNS names (e.g., `n8n`, `qdrant`, `ollama`). Only necessary ports are exposed to the host:
- Port 80: Nginx reverse proxy (web UI, n8n access)
- Port 9090: Prometheus
- All other services: internal only (`expose` not `ports`)

### Data Flow

#### Upload/Ingestion Pipeline (Workflow 1)
1. **Webhook/Form** (BasicAuth protected) → accepts md, txt, pdf, docx, xlsx (5MB limit)
2. **Validation** → MIME type, file size, format checks
3. **Parsing**:
   - md/txt: Direct parsing with regex/markdown parser for sections
   - pdf/docx/xlsx: Docling Serve API → structured JSON output
4. **Semantic Chunking**:
   - Uses document structure (headings, sections, tables from Docling)
   - Page-aware for PDF/DOCX with metadata: `document_id`, `filename`, `page_number`, `section`, `chunk_index`, `hash`, `created_at`, `tags`, `source_url`
   - Small overlap (50-100 tokens) only at section boundaries
5. **Embedding** → Ollama embedding endpoint (e.g., bge-m3)
6. **Upsert to Qdrant** → Content hash for deduplication, versioning support

#### Chat/Retrieval Pipeline (Workflow 2)
1. **Query Input** → via form/webhook/WebUI
2. **Vector Search** → Qdrant top_k=20 with optional metadata filters
3. **Reranking** → Local cross-encoder (via Ollama/TEI) → top_k=5
4. **Context Building** → Include citation markers (document/page references, section titles)
5. **LLM Generation** → Ollama with low temperature, mandatory citations per passage
6. **Response** → Answer + structured source list with page references

### Metadata Schema (Qdrant)
Each vector chunk includes:
```json
{
  "id": "uuid",
  "vector": [...],
  "content": "text chunk",
  "metadata": {
    "document_id": "uuid",
    "filename": "example.pdf",
    "page_number": 42,
    "section": "Chapter 3: Introduction",
    "chunk_index": 5,
    "hash": "sha256...",
    "created_at": "2025-11-08T12:00:00Z",
    "tags": ["category1", "category2"],
    "source_url": "optional",
    "version": 1
  }
}
```

### Observability
- **Prometheus**: Scrapes metrics from n8n, Qdrant, Loki, Tempo, Grafana, cAdvisor, postgres-exporter, elasticsearch-exporter (port 9090)
- **Grafana**: Dashboards for throughput, latency, error rates (port 3000)
- **Loki**: Centralized log aggregation from all containers (port 3100)
- **Promtail**: Log shipping agent (reads Docker container logs)
- **Tempo**: Distributed tracing (OTLP receivers on ports 4317/4318)
- **Elasticsearch/Kibana**: Advanced search/analysis (ports 9200/5601)
- **Filebeat**: Log shipper to Elasticsearch
- **cAdvisor**: Container metrics (CPU, memory, network) (port 8080)
- **postgres-exporter**: PostgreSQL metrics for Prometheus (port 9187)
- **elasticsearch-exporter**: Elasticsearch metrics for Prometheus (port 9114)

Configuration files:
- `observability/prometheus/prometheus.yml`: Scrape configs (configured and working)
- `observability/loki/config.yaml`: Loki storage/retention (configured and working)
- `observability/promtail/config.yaml`: Log collection rules (configured)
- `observability/tempo/config.yaml`: Distributed tracing config
- `observability/filebeat/filebeat.yml`: Filebeat config
- `observability/qdrant-config.yaml`: Qdrant metrics and logging config

## Development Workflow

### Adding/Modifying n8n Workflows
1. Access n8n UI (http://localhost/n8n or :5678)
2. Edit workflows: `01_upload_ingest.json`, `02_chat_retrieval.json`
3. Export updated workflows via UI (Settings → Export)
4. Save to `./workflows/` directory
5. Version control in git (if applicable)

### Modifying Document Processing
- **Chunking logic**: Edit n8n workflow nodes for semantic chunking
- **Docling configuration**: Adjust docker-compose.yaml environment variables for `docling` service
- **Supported formats**: Modify validation in upload workflow webhook

### Tuning RAG Performance
- **Embedding model**: Change in Ollama (pull different model, update n8n workflow)
- **LLM model**: Pull different model size based on GPU memory
- **top_k values**: Adjust in chat workflow (initial retrieval: 20, post-rerank: 5)
- **HNSW parameters**: Qdrant collection config (m=16-32, ef_construct=100-200)
- **Reranking**: Enable/disable in workflow, adjust cross-encoder model

### GPU Configuration
For NVIDIA GPU hosts (Windows/Linux):
```yaml
# In docker-compose.yaml, uncomment for ollama service:
deploy:
  resources:
    reservations:
      devices:
        - capabilities: ["gpu"]
          driver: nvidia
          count: "all"
```
Requires NVIDIA Container Toolkit installed on host.

### Security Configuration
- **BasicAuth credentials**: Set in `.env` file (`N8N_USER`, `N8N_PASSWORD`)
- **PII filtering**: Implement in n8n upload workflow (before embedding step)
- **Rate limiting**: Configure in nginx.conf or n8n webhook settings
- **Network isolation**: All services in `rag-net`, minimal port exposure

## Important File Locations

### Configuration
- `docker-compose.yaml`: Service definitions, network, volumes
- `.env`: Credentials (n8n, Grafana)
- `web/nginx.conf`: Reverse proxy configuration ⚠️ **Currently minimal/empty - needs configuration**
- `observability/prometheus/prometheus.yml`: Metrics scraping ⚠️ **May need configuration**
- `observability/loki/config.yaml`: Log storage config ⚠️ **May need configuration**
- `observability/promtail/config.yaml`: Log collection rules ⚠️ **May need configuration**


### Configuration
- `docker-compose.yaml`: Service definitions, network, volumes (17 services total)
- `.env`: Credentials (n8n, Grafana, PostgreSQL)
  - `N8N_USER`: n8n username (default: admin)
  - `N8N_PASSWORD`: n8n password (default: admin)
  - `GRAFANA_USER`: Grafana username (default: admin)
  - `GRAFANA_PASSWORD`: Grafana password (default: admin)
  - `POSTGRES_USER`: PostgreSQL username (default: n8n)
  - `POSTGRES_PASSWORD`: PostgreSQL password (default: n8n_secure_password)
- `observability/prometheus/prometheus.yml`: Metrics scraping ✅ **Configured and working**
- `observability/loki/config.yaml`: Loki storage config ✅ **Configured and working**
- `observability/promtail/config.yaml`: Log collection rules ✅ **Configured**
- `observability/tempo/config.yaml`: Distributed tracing config
- `observability/filebeat/filebeat.yml`: Filebeat log shipping config
- `observability/qdrant-config.yaml`: Qdrant configuration
### Data Persistence (bind mounts)
- `data/n8n/`: n8n workflows, credentials, execution data
- `data/postgres/`: PostgreSQL database (chat history)
- `data/qdrant/storage/`: Vector collections, indices
- `data/qdrant/snapshots/`: Backup snapshots
- `data/ollama/`: Downloaded Ollama models (currently empty - pull models first)
- `data/docling/cache/`: Docling parsing cache
- `data/docling/ocr_cache/`: OCR cache
- `observability/`: Logs, metrics, traces, dashboards
  - `observability/prometheus/`: Prometheus data and config
  - `observability/grafana/`: Grafana dashboards and data
  - `observability/loki/`: Loki log storage
  - `observability/tempo/`: Tempo trace storage
  - `observability/elasticsearch/`: Elasticsearch data
  - `observability/kibana-data/`: Kibana configuration
  - `observability/*-logs/`: Service-specific log directories

### Workflows
- `workflows/`: n8n workflow JSON files (01_upload_ingest.json, 02_chat_retrieval.json)
- `shared/`: Shared volume between n8n, ollama, docling for file transfer

### Reference Documentation
- `pr.md`: Detailed project requirements and architecture (German) - **Primary reference document**
- `antworten.txt`: Original requirements questionnaire responses (German)
- `n8n_docs_combined.md`: Complete n8n documentation for reference (~3.8MB)
- `ordneranlage.sh`: Directory setup script (Bash for macOS/Linux)
- `ornderanlage.ps1`: Directory setup script (PowerShell for Windows)

## Platform-Specific Notes

### macOS M1 (ARM64)
- Use ARM64-compatible Docker images (all services support it)
- No direct access to `/var/lib/docker/volumes` - use bind mounts as configured
- Ollama runs CPU-only (no GPU acceleration on M1)
- Promtail may have limited Docker socket access - verify in logs

### Windows (WSL2 + NVIDIA)
- Requires Docker Desktop with WSL2 backend
- NVIDIA Container Toolkit must be installed in WSL2 distribution
- Verify GPU access: `docker compose exec ollama nvidia-smi`
- Use PowerShell script `ornderanlage.ps1` for directory setup

### Linux (Production with A6000)
- Enable GPU in docker-compose.yaml (uncomment deploy/resources section)
- Install NVIDIA Container Toolkit: `nvidia-docker2` package
- Consider systemd unit for auto-start: `systemctl enable docker-compose@n8n-rag`
- Use larger models (70B) for production quality

## Testing & Validation

### End-to-End Test
1. Start stack: `docker compose up -d`

2. Verify all services healthy: `docker compose ps`
   - All 17 services should be "Up" (some may show "Up X hours (healthy)")
   - If any services are restarting, check logs: `docker compose logs [service-name]`

3. **REQUIRED**: Pull Ollama models (none are pre-installed)
   ```bash
   # Embedding model (required)
   docker compose exec ollama ollama pull bge-m3

   # Chat model - choose based on your hardware:
   # For macOS M1/M2/M3 (CPU-only)
   docker compose exec ollama ollama pull qwen2.5:3b-instruct

   # For 12GB GPU (4070 Ti)
   docker compose exec ollama ollama pull qwen2.5:7b-instruct

   # For 48GB GPU (A6000)
   docker compose exec ollama ollama pull llama3.1:70b

   # Verify models installed
   docker compose exec ollama ollama list
   ```

4. Access n8n UI: http://localhost:5678
   - Username: `admin` (from .env: N8N_USER)
   - Password: `admin` (from .env: N8N_PASSWORD)

5. Create or import workflows (01_upload_ingest.json, 02_chat_retrieval.json)
   - **Note**: `workflows/` directory is currently empty - workflows must be created first
   - Create workflows in n8n UI following RAG pipeline architecture (see Data Flow section)
   - Export workflows and save to `./workflows/` directory

6. Verify Qdrant is accessible: `curl http://localhost:6333/collections`

7. Test upload workflow with sample PDF/DOCX (< 5MB)
   - Upload via n8n webhook or form
   - Check execution logs in n8n UI

8. Verify chunks stored in Qdrant: `curl http://localhost:6333/collections`

9. Test chat workflow with query related to uploaded document

10. Check citations and page references in response

11. Verify observability stack:
    - Prometheus: http://localhost:9090
    - Grafana: http://localhost:3000 (admin/admin)
    - Kibana: http://localhost:5601
    - cAdvisor: http://localhost:8080

### Monitoring Health
- **Prometheus** targets: http://localhost:9090/targets
  - Should show: prometheus, n8n, qdrant, loki, tempo, grafana, cadvisor, postgres-exporter, elasticsearch-exporter
- **Grafana** dashboards: http://localhost:3000 (admin/admin)
- **Kibana** log viewer: http://localhost:5601
- **cAdvisor** container metrics: http://localhost:8080
- **n8n** execution logs: http://localhost:5678 → Executions tab
- **Qdrant** dashboard: http://localhost:6333/dashboard
- **PostgreSQL** metrics: http://localhost:9187/metrics
- **Elasticsearch** metrics: http://localhost:9114/metrics
- Container logs: `docker compose logs -f [service_name]`

Available service names for logs:
- n8n, postgres, qdrant, ollama, docling
- prometheus, grafana, loki, promtail, tempo
- elasticsearch, kibana, filebeat
- cadvisor, postgres-exporter, elasticsearch-exporter

## Backup & Recovery

### Qdrant Snapshots
```bash
# Create snapshot (via API or Qdrant UI)
curl -X POST http://localhost:6333/collections/{collection}/snapshots

# Snapshots stored in: data/qdrant/snapshots/
# Backup externally: rsync, S3, etc.
```

### n8n Workflows
- Workflows persisted in `data/n8n/database.sqlite`
- Export manually via UI for version control
- Backup entire `data/n8n/` directory

### Complete System Backup
```bash
# Stop services
docker compose down

# Backup data directory
tar -czf n8n-rag-backup-$(date +%Y%m%d).tar.gz data/ workflows/ .env docker-compose.yaml

# Restart services
docker compose up -d
```

## Troubleshooting

### Service won't start
- Check logs: `docker compose logs [service]`
- Verify directory permissions: `ls -la data/`
- Ensure ports not in use: `netstat -tuln | grep [port]`

### Services in restart loop
If services are restarting:
- **Check logs first**: `docker compose logs [service-name]`
- **Loki/Promtail/Tempo**: Configuration files exist and are properly configured
  ```bash
  # Config files are already in place:
  # observability/loki/config.yaml ✅
  # observability/promtail/config.yaml ✅
  # observability/tempo/config.yaml ✅
  ```
- **Common issues**:
  - **Promtail**: May have limited Docker socket access on macOS - verify in logs
  - **Filebeat**: Requires proper permissions for Docker socket
  - **Volume permissions**: Check `ls -la data/` and `ls -la observability/`

If restart loops persist, check:
```bash
# Check specific service logs
docker compose logs --tail=50 [service-name]

# Check resource usage
docker stats

# Restart specific service
docker compose restart [service-name]
```

### Ollama model not loading
- **IMPORTANT**: No models are pre-installed by default. You MUST pull them first.
- Check installed models: `docker compose exec ollama ollama list`
- Pull required models (see Ollama Model Management section above)
- Check GPU access (GPU hosts only): `docker compose exec ollama nvidia-smi`
- Verify model size vs. available memory:
  - macOS M1/M2/M3: Use 3B-7B models (CPU-only)
  - 12GB GPU: Use 7B-14B models with quantization
  - 48GB GPU: Can use 70B models
- Check ollama logs: `docker compose logs ollama`
- Verify Ollama is accessible: `curl http://localhost:11434/api/tags`

### Qdrant connection errors
- Verify service is running: `docker compose ps qdrant`
- Check internal DNS: `docker compose exec n8n ping qdrant`
- Verify port 6333 accessible internally
- Qdrant web UI: Not exposed by default (only internal ports 6333/6334)

### n8n workflow execution fails
- Check n8n execution logs in UI
- Verify service dependencies (qdrant, ollama, docling) are running
- Check credentials and connection settings in n8n nodes
- Review observability logs in Grafana/Loki
- **Important**: No workflows exist in `workflows/` directory yet - must be created/imported first

### Direct service access (no reverse proxy configured)
All services are directly accessible via their published ports:
- **n8n**: http://localhost:5678 (username: admin, password: admin)
- **Qdrant**: http://localhost:6333 (dashboard at /dashboard)
- **Prometheus**: http://localhost:9090
- **Grafana**: http://localhost:3000 (username: admin, password: admin)
- **Kibana**: http://localhost:5601
- **Elasticsearch**: http://localhost:9200
- **Loki**: http://localhost:3100
- **Tempo**: http://localhost:3200
- **Ollama**: http://localhost:11434
- **Docling**: http://localhost:5001
- **cAdvisor**: http://localhost:8080
- **PostgreSQL**: localhost:5432
- **postgres-exporter**: http://localhost:9187/metrics
- **elasticsearch-exporter**: http://localhost:9114/metrics

Note: Nginx reverse proxy in `web/` directory is not currently configured. All services use direct port access.
