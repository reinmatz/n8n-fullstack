# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a fully local, self-hosted RAG (Retrieval-Augmented Generation) system built on Docker Compose. It enables document ingestion (PDF, DOCX, XLSX, MD, TXT) and semantic search/chat using local LLMs, optimized for German language content with minimal hallucinations.

**Key Components:**
- **n8n**: Workflow orchestration for upload/ingestion and chat/retrieval pipelines
- **Qdrant**: Vector database with HNSW indexing, metadata filtering, and snapshot support
- **Ollama**: Local LLM inference and embeddings (supports GPU acceleration)
- **Docling Serve**: Document parsing service (PDF, DOCX, XLSX to structured JSON)
- **Observability Stack**: Prometheus, Grafana, Loki, Tempo, Elasticsearch/Kibana

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

# Restart a specific service
docker compose restart n8n
```

### Ollama Model Management
```bash
# Pull embedding model (German-optimized)
docker compose exec ollama ollama pull bge-m3

# Pull LLM for chat/QA
docker compose exec ollama ollama pull qwen2.5:7b-instruct  # For 12GB GPU
docker compose exec ollama ollama pull llama3.1:70b         # For 48GB GPU

# List installed models
docker compose exec ollama ollama list

# Pull reranker model
docker compose exec ollama ollama pull bge-reranker-base
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
# Navigate to: http://localhost/n8n (via nginx proxy - requires nginx.conf setup)
# Or direct: http://localhost:5678 (exposed internally only, use port-forward if needed)
# Default credentials: admin/admin (see .env)

# Port-forward n8n if nginx not configured
docker compose exec -it n8n /bin/sh

# Export workflows (manual via UI or API)
# Workflow files should be saved to ./workflows/ directory
# Note: workflows/ directory is currently empty - import existing workflows or create new ones
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
- **Prometheus**: Scrapes metrics from n8n, Qdrant, Ollama (port 9090)
- **Grafana**: Dashboards for throughput, latency, error rates (accessed via nginx proxy)
- **Loki**: Centralized log aggregation from all containers
- **Promtail**: Log shipping agent (reads Docker container logs)
- **Tempo**: Distributed tracing (OTLP receivers on 4317/4318)
- **Elasticsearch/Kibana**: Optional advanced search/analysis (if enabled)

Configuration files:
- `observability/prometheus/prometheus.yml`: Scrape configs
- `observability/loki/config.yaml`: Loki storage/retention
- `observability/promtail/config.yaml`: Log collection rules

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

### Data Persistence (bind mounts)
- `data/n8n/`: n8n workflows, credentials, SQLite database
- `data/qdrant/storage/`: Vector collections, indices
- `data/qdrant/snapshots/`: Backup snapshots
- `data/ollama/`: Downloaded models
- `data/docling/`: Parsing cache
- `observability/`: Logs, metrics, traces, dashboards

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
   - Note: Some services (loki, promtail, tempo, web) may be restarting due to missing configs
3. Pull required Ollama models (see commands above)
   ```bash
   docker compose exec ollama ollama pull bge-m3
   docker compose exec ollama ollama pull qwen2.5:7b-instruct
   ```
4. Create/configure nginx.conf if needed for reverse proxy access
5. Access n8n UI:
   - If nginx configured: http://localhost/n8n
   - Direct (requires port forward): Access container directly
6. Create or import workflows (01_upload_ingest.json, 02_chat_retrieval.json)
   - Note: `workflows/` directory is currently empty
7. Test upload workflow with sample PDF/DOCX (< 5MB)
8. Verify chunks in Qdrant: `curl http://localhost:6333/collections`
9. Test chat workflow with query related to uploaded document
10. Check citations and page references in response

### Monitoring Health
- Prometheus targets: http://localhost:9090/targets
- Grafana dashboards: http://localhost/grafana (via nginx, needs nginx.conf setup)
- n8n execution logs: UI → Executions tab
- Container logs: `docker compose logs -f [service_name]`

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

### Services in restart loop (Loki, Promtail, Tempo, Web)
If observability services are restarting:
- **Loki/Promtail/Tempo**: Check if configuration files exist and are valid
  ```bash
  # Verify config files exist and are not empty
  ls -l observability/loki/config.yaml
  ls -l observability/promtail/config.yaml
  ```
- **Nginx (web)**: Requires valid `web/nginx.conf` configuration
  ```bash
  # Check if nginx.conf exists and is valid
  cat web/nginx.conf
  # If empty, nginx will fail to start - needs proper configuration
  ```
- Create minimal configs if missing (see pr.md for templates)

### Ollama model not loading
- Check GPU access: `docker compose exec ollama nvidia-smi` (GPU hosts)
- Verify model size vs. available memory
- Check ollama logs: `docker compose logs ollama`
- First-time setup: No models are pre-installed, must pull them manually

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

### Cannot access services via nginx (port 80)
- Nginx requires valid configuration in `web/nginx.conf` (currently empty)
- If nginx is in restart loop, access services directly via internal ports using port-forwarding
- Example port-forward: `docker compose exec -p 5678:5678 n8n`
