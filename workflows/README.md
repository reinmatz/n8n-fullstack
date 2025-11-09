# n8n RAG Workflows

Dieses Verzeichnis enthält die beiden Hauptworkflows für das RAG-System:

## Workflows

### 1. `01_upload_ingest.json` - Upload & Ingestion Pipeline

**Zweck:** Verarbeitet hochgeladene Dokumente und speichert sie als Vektor-Embeddings in Qdrant.

**Funktionen:**
- Webhook-Endpoint: `POST /upload` (BasicAuth geschützt)
- Datei-Validierung (PDF, DOCX, XLSX, MD, TXT, max 5MB)
- Routing: MD/TXT → Direct Parser, PDF/DOCX/XLSX → Docling API
- PII-Filterung (E-Mail, Telefon, IBAN, Kreditkarten, SSN)
- Semantisches Chunking (strukturbasiert, 512 Token-Chunks)
- Batch-Embedding via Ollama (bge-m3, Batches à 10 Chunks)
- Qdrant Upsert mit Deduplikation (Content-Hash)

**Metadaten pro Chunk:**
```json
{
  "document_id": "uuid",
  "filename": "example.pdf",
  "page_number": 42,
  "section": "Kapitel 3",
  "chunk_index": 5,
  "hash": "sha256...",
  "created_at": "2025-11-09T12:00:00Z",
  "tags": [],
  "source_url": null,
  "version": 1
}
```

---

### 2. `02_chat_retrieval.json` - Chat & Retrieval Pipeline

**Zweck:** Beantwortet Fragen basierend auf gespeicherten Dokumenten mit Zitationen.

**Funktionen:**
- Webhook-Endpoint: `POST /chat` (BasicAuth geschützt)
- Query-Expansion (deutsche Synonyme)
- Hybrid-Retrieval:
  - **Vector Search** (Qdrant, top_k=20)
  - **BM25 Search** (Keyword-basiert, top_k=10)
- **RRF Fusion** (Reciprocal Rank Fusion)
- Reranking auf Top 5 (Relevanz-Scoring)
- Context Building mit Zitationsmarkern `[1]`, `[2]`, etc.
- LLM-Generierung (Qwen2.5:3b-instruct, Temperatur 0.2)
- Chat-History-Speicherung in PostgreSQL

**Request-Format:**
```json
{
  "query": "Was sind die Hauptpunkte im Dokument?",
  "filters": {
    "filename": "example.pdf"
  },
  "session_id": "optional-uuid"
}
```

**Response-Format:**
```json
{
  "answer": "Die Hauptpunkte sind [1]...",
  "sources": [
    {
      "citation": 1,
      "filename": "example.pdf",
      "page_number": 3,
      "section": "Einleitung",
      "snippet": "..."
    }
  ],
  "session_id": "uuid",
  "metadata": {
    "query": "...",
    "expansion_applied": true,
    "retrieval_sources": "vector+bm25",
    "model": "qwen2.5:3b-instruct"
  }
}
```

---

## Workflow-Import in n8n

### Voraussetzungen
1. n8n läuft: `docker compose ps n8n` → Status: "Up"
2. n8n UI erreichbar: http://localhost:5678
3. Credentials konfiguriert (siehe unten)

### Import-Schritte

1. **n8n UI öffnen:**
   ```bash
   open http://localhost:5678
   ```
   Login: `admin` / `admin` (aus `.env`)

2. **Credentials erstellen:**

   **a) BasicAuth für Webhooks:**
   - Navigiere zu: **Settings** → **Credentials** → **Add Credential**
   - Typ: `HTTP Basic Auth`
   - Name: `n8n BasicAuth`
   - Username: `admin` (oder eigener Wert)
   - Password: `admin` (oder eigener Wert)
   - **Save**

   **b) PostgreSQL-Verbindung:**
   - Typ: `Postgres`
   - Name: `PostgreSQL n8n`
   - Host: `postgres`
   - Port: `5432`
   - Database: `n8n_chat_history`
   - User: `n8n`
   - Password: `n8n_secure_password` (aus `.env`)
   - SSL: `disable`
   - **Save**

3. **Workflows importieren:**

   **Workflow 1:**
   - Klicke auf **"+"** → **Import from File**
   - Wähle: `workflows/01_upload_ingest.json`
   - **Import**
   - **Save** (Strg+S)
   - **Activate** (Toggle oben rechts)

   **Workflow 2:**
   - Wiederhol Schritte für `workflows/02_chat_retrieval.json`
   - **Save** und **Activate**

4. **Webhook-URLs notieren:**
   - Öffne Workflow 1
   - Klicke auf "Webhook Upload"-Node
   - Kopiere **Production URL** (z.B. `http://localhost:5678/webhook/upload`)
   - Wiederhol für Workflow 2 (`http://localhost:5678/webhook/chat`)

---

## Workflow-Anpassungen (Optional)

### PII-Filterung Strict Mode
**Datei:** `01_upload_ingest.json`
**Node:** "PII Filter"
**Zeile 163:**
```javascript
const strictMode = false; // Ändere zu true um Files mit PII abzulehnen
```

### Chunk-Größe anpassen
**Datei:** `01_upload_ingest.json`
**Node:** "Semantic Chunking"
**Zeilen 189-190:**
```javascript
const CHUNK_OVERLAP = 50; // Token-Overlap an Grenzen
const MAX_CHUNK_SIZE = 512; // Max Tokens pro Chunk
```

### Top-K Werte
**Datei:** `02_chat_retrieval.json`
**Node:** "Vector Search (Qdrant)"
**Zeile 51:**
```json
"limit": 20  // Anzahl Vektor-Suchergebnisse
```

**Node:** "Reranking (Top 5)"
**Zeile 105:**
```javascript
.slice(0, 5); // Top-K nach Reranking
```

### LLM-Parameter
**Datei:** `02_chat_retrieval.json`
**Node:** "LLM Generation (Ollama)"
**Zeilen 139-142:**
```json
"options": {
  "temperature": 0.2,    // 0.0-1.0 (höher = kreativer)
  "top_p": 0.9,          // Nucleus Sampling
  "max_tokens": 512      // Max Response-Länge
}
```

---

## Test-Befehle

### Upload-Test (MD-Datei)
```bash
curl -X POST http://localhost:5678/webhook/upload \
  -u admin:admin \
  -F "data=@test-data/sample.md"
```

### Chat-Test
```bash
curl -X POST http://localhost:5678/webhook/chat \
  -u admin:admin \
  -H "Content-Type: application/json" \
  -d '{
    "query": "Was steht im Dokument?",
    "filters": {}
  }'
```

---

## Troubleshooting

### Workflow-Import schlägt fehl
- **Fehler:** "Invalid JSON"
  - **Lösung:** Überprüfe JSON-Syntax mit `jq . workflows/01_upload_ingest.json`

- **Fehler:** "Credential not found"
  - **Lösung:** Erstelle Credentials **VOR** Import (siehe Schritt 2 oben)

### Webhook 404 Error
- **Problem:** Workflow nicht aktiviert
  - **Lösung:** Toggle "Active" in n8n UI (oben rechts)

### Ollama-Embedding Timeout
- **Problem:** Modell nicht geladen
  - **Lösung:** `docker compose exec ollama ollama list` → Prüfe ob `bge-m3` vorhanden

### Qdrant Connection Error
- **Problem:** Collection existiert nicht
  - **Lösung:**
    ```bash
    curl http://localhost:6333/collections/rag_documents
    # Falls 404: Re-initialize mit init_qdrant_collection.sh
    ```

### PostgreSQL Insert Fehler
- **Problem:** Schema nicht initialisiert
  - **Lösung:**
    ```bash
    docker compose exec -T postgres psql -U n8n -d n8n_chat_history < init_postgres_schema.sql
    ```

---

## Workflow-Architektur

```
Upload/Ingestion (01):
Webhook → Validation → Route → Parser → PII-Filter → Chunking → Embedding → Qdrant

Chat/Retrieval (02):
Webhook → Query-Expansion → Embedding → [Vector + BM25] → RRF Merge → Reranking → Context → LLM → PostgreSQL → Response
```

---

## Nächste Schritte
1. ✅ Workflows importieren
2. ✅ Test-Dokument hochladen
3. ✅ Chat-Query testen
4. ✅ Zitationen in Response prüfen
5. ✅ PostgreSQL Chat-History ansehen
6. Optional: Grafana-Dashboards für Metriken

**Support:** Siehe `CLAUDE.md` für erweiterte Troubleshooting-Guides.
