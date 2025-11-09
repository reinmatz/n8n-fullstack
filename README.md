# n8n-RAG: Local Self-Hosted RAG System

A fully local, self-hosted RAG (Retrieval-Augmented Generation) system optimized for German language documents. Built with Docker Compose, featuring document ingestion, semantic search, and LLM-powered chat with minimal hallucinations.

## Features

- **100% Local & Privacy-First**: All data processing happens on your infrastructure
- **Multi-Format Support**: PDF, DOCX, XLSX, MD, TXT document ingestion
- **German Language Optimized**: Using BGE-M3 embeddings and German-capable LLMs
- **Semantic Chunking**: Structure-aware document parsing with page-level citations
- **Production-Ready**: Comprehensive observability stack (Prometheus, Grafana, Loki, Tempo)
- **GPU Acceleration**: Optional NVIDIA GPU support for faster inference
- **Hybrid Search**: Vector search with metadata filtering and reranking

## Architecture

### Core Components
- **n8n**: Workflow orchestration for upload/ingestion and chat/retrieval pipelines
- **Qdrant**: High-performance vector database with HNSW indexing
- **Ollama**: Local LLM inference engine with GPU support
- **Docling Serve**: Advanced document parsing (PDF, DOCX, XLSX to structured JSON)

### Observability Stack
- Prometheus + Grafana for metrics and dashboards
- Loki + Promtail for centralized logging
- Tempo for distributed tracing
- Elasticsearch + Kibana for advanced log analysis

## Quick Start

### Prerequisites
- Docker & Docker Compose
- 16GB+ RAM recommended
- (Optional) NVIDIA GPU with Container Toolkit for acceleration

### 1. Setup Directories
```bash
# macOS/Linux
chmod +x ordneranlage.sh
./ordneranlage.sh

# Windows (PowerShell)
.\ornderanlage.ps1
```

### 2. Configure Environment
```bash
cp .env.example .env
# Edit .env to set credentials (N8N_USER, N8N_PASSWORD, etc.)
```

### 3. Start Services
```bash
docker compose up -d
```

### 4. Pull Required Models
```bash
# Embedding model (required)
docker compose exec ollama ollama pull bge-m3

# Chat model - choose based on your GPU:
# For 12GB GPU (RTX 4070 Ti)
docker compose exec ollama ollama pull qwen2.5:7b-instruct

# For 48GB GPU (A6000)
docker compose exec ollama ollama pull llama3.1:70b

# Reranker model (optional, improves accuracy)
docker compose exec ollama ollama pull bge-reranker-base
```

### 5. Access Services
- **n8n**: http://localhost:5678 (or via nginx proxy)
- **Qdrant**: http://localhost:6333
- **Prometheus**: http://localhost:9090
- **Grafana**: http://localhost:3000 (via nginx)

## Usage

### Document Upload
1. Access n8n UI and activate the upload workflow
2. Send documents via webhook or form (max 5MB)
3. Supported formats: PDF, DOCX, XLSX, MD, TXT
4. Documents are parsed, chunked, embedded, and stored in Qdrant

### Chat/Retrieval
1. Activate the chat workflow in n8n
2. Submit queries via webhook or UI
3. System retrieves relevant chunks, reranks, and generates answers with citations
4. Responses include page-level references and section context

## Platform Support

### macOS M1/M2/M3 (ARM64)
- CPU-only inference (no GPU acceleration)
- All services run natively on ARM64

### Windows with NVIDIA GPU
- Requires Docker Desktop with WSL2
- NVIDIA Container Toolkit in WSL2
- GPU acceleration for Ollama

### Linux with NVIDIA GPU
- Install `nvidia-docker2` package
- Uncomment GPU configuration in `docker-compose.yaml`
- Production-ready for large models (70B+)

## Configuration

### GPU Acceleration
Edit `docker-compose.yaml` and uncomment for the `ollama` service:
```yaml
deploy:
  resources:
    reservations:
      devices:
        - capabilities: ["gpu"]
          driver: nvidia
          count: "all"
```

### Tuning RAG Performance
- **top_k**: Adjust in chat workflow (default: 20 → rerank to 5)
- **Chunk size**: Modify in upload workflow semantic chunking
- **Models**: Swap embedding/LLM models via Ollama
- **HNSW parameters**: Edit Qdrant collection config (m=16-32, ef_construct=100-200)

## Monitoring

- **Prometheus**: http://localhost:9090/targets
- **Grafana Dashboards**: Via nginx proxy
- **n8n Execution Logs**: UI → Executions
- **Service Logs**: `docker compose logs -f [service]`

## Backup & Recovery

### Qdrant Snapshots
```bash
curl -X POST http://localhost:6333/collections/{collection}/snapshots
# Snapshots saved to: data/qdrant/snapshots/
```

### Full System Backup
```bash
docker compose down
tar -czf n8n-rag-backup-$(date +%Y%m%d).tar.gz data/ workflows/ .env docker-compose.yaml
docker compose up -d
```

## Project Structure
```
n8n-rag/
├── docker-compose.yaml       # Service definitions
├── .env                      # Credentials (git-ignored)
├── ordneranlage.sh          # Directory setup (macOS/Linux)
├── ornderanlage.ps1         # Directory setup (Windows)
├── data/                    # Persistent volumes (git-ignored)
│   ├── n8n/
│   ├── qdrant/
│   ├── ollama/
│   └── docling/
├── workflows/               # n8n workflow definitions
├── observability/           # Monitoring configs
│   ├── prometheus/
│   ├── grafana/
│   ├── loki/
│   └── tempo/
└── web/                     # Nginx reverse proxy
```

## Documentation

- **CLAUDE.md**: Detailed developer guide and troubleshooting
- **pr.md**: Complete project requirements and architecture (German)
- **n8n_docs_combined.md**: Full n8n documentation reference

## Troubleshooting

### Services won't start
```bash
# Check logs
docker compose logs [service_name]

# Verify directories
ls -la data/

# Check port conflicts
netstat -tuln | grep [port]
```

### Ollama model not loading
```bash
# Check GPU access (if applicable)
docker compose exec ollama nvidia-smi

# View ollama logs
docker compose logs ollama

# Verify models are pulled
docker compose exec ollama ollama list
```

See **CLAUDE.md** for comprehensive troubleshooting guide.

## License

MIT License - See LICENSE file for details

## Contributing

Contributions welcome! Please open issues or pull requests for:
- Bug fixes
- Feature enhancements
- Documentation improvements
- Platform-specific optimizations

## Security

- All services run in isolated Docker network
- BasicAuth protection on webhooks
- No external API calls (100% local processing)
- Credentials stored in `.env` (git-ignored)

For security concerns, please open a private security advisory.
