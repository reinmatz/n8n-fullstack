Version: 1.0
Datum: 08. November 2025
Projekt: N8N RAG System – Self-Hosted mit Docling, Ollama und lokaler Vektor-DB

Zweck und Ergebnis
- Ziel ist ein vollständig lokales RAG-System auf Docker-Basis mit n8n-Workflows für Upload/Ingestion und Chat/Retrieval, optimiert für deutschsprachige Inhalte, minimale Halluzinationen und reproduzierbare Deployments. 
- Ergebnisartefakte: docker-compose.yml (neu, mit dediziertem Netzwerk), zwei importierbare n8n-Workflows (Upload/Ingestion, Chat/Retrieval), ausführliche Bereitstellungsanleitung und Erklärung der Compose-Datei, Nutzung lokaler Dokumentation n8n_docs_combined.md als Prozessreferenz. 

Ziele und Rahmen
- Compose neu erstellen: Alle Services in einem benutzerdefinierten Bridge-Netz, service-discovery via DNS-Name, isoliert und minimal exponierte Ports. 
- Persistenz: Bind mounts für alle relevanten Datenverzeichnisse (n8n, Ollama-Modelle, Qdrant-Snapshots, Logs), um einfache Backups, Diffing und plattformübergreifende Handhabung zu gewährleisten. 
- Plattformen: Dev macOS M1 CPU, Test Windows mit NVIDIA 4070 Ti (12 GB), Prod Linux mit NVIDIA A6000 (48 GB), mit einheitlicher Compose-Basis und optionaler GPU-Beschleunigung. 

Systemarchitektur
- Komponenten:
  - n8n: Workflow-Orchestrierung, Formulare, Webhooks, BasicAuth, RAG-Logik. 
  - Docling Serve: Parsing für PDF, DOCX, XLSX; Ausgabe JSON; UI optional. 
  - Ollama: Embeddings und lokales LLM, GPU-unterstützt wo verfügbar. 
  - Vektor-DB: Qdrant als beste lokale Option für Filter, Snapshots/Backups, ARM64/x86-64 Support. 
  - Reranker: lokaler Cross-Encoder über Ollama/TEI für Re-Ranking. 
  - Observability: Prometheus, Grafana, Loki, Tempo; optional Elasticsearch für Suche/Analyse. 
- Netz: Ein dediziertes Bridge-Netz (z. B. rag-net) mit festen Service-Namen, nur benötigte Ports published. 

Dateifluss und Formate
- Unterstützte Uploads: md, txt direkt; pdf, docx, xlsx via Docling. 
- Größenlimit: 5 MB pro Datei; Validierung im Webhook. 
- Normalisierung: Docling-Output als JSON; Tabellen aus xlsx werden in strukturierte JSON-Objekte normalisiert. 
- Metadaten pro Chunk: document_id, filename, page_number, section, chunk_index, hash, created_at, tags, source_url; Upsert mit Versionsfeld. 

Chunking-Strategie
- Semantisches Chunking: Docling-Struktur (Überschriften/Abschnitte/Tabellen) als Primärgrenzen. 
- Ziel: geringe Halluzinationen durch größere kontextuelle Chunks; Overlap klein gehalten (z. B. 50–100 Tokens) nur bei Abschnittsgrenzen. 
- Page-aware: Für PDF/DOCX page_number in Metadaten und Beibehaltung der Abschnitts-Hierarchie. 

Embeddings und Modelle (Ollama)
- Embedding-Modell: deutsch-optimiert mit starker Mehrsprach-Performance, Empfehlung: bge-m3 oder e5-large-v2 Port in Ollama; falls verfügbar, deutsch-spezifisches all-minilm-de als Alternative. 
- LLM für QA/Chat:
  - Test (4070 Ti 12 GB): Qwen2.5-7B/14B-instruct oder Llama 3.1 8B-instruct in Q4_K_M; GPU-beschleunigt. 
  - Prod (A6000 48 GB): Llama 3.1 70B-instruct (gguf quantisiert) oder Qwen2.5-32B; Auswahl nach Latenz/Qualität. 
- Reranker: lokaler Cross-Encoder über Ollama (z. B. bge-reranker-base) oder TEI; MMR optional für Diversifizierung. 

Vektor-Datenbank
- Wahl: Qdrant aufgrund Featureset (HNSW, Filter, Snapshots, ARM64/x86-64 Images, REST/gRPC, gute Admin-Tools). 
- Konfiguration:
  - HNSW: m=16–32, ef_construct=100–200; ef_search dynamisch per Query. 
  - Filter: auf filename, tags, page_number, section, created_at, source_url. 
  - Snapshots: regelmäßige Snapshots im Bind-Mount, Offsite-Kopie. 
  - ARM64: Einsatz offizieller ARM64-Images für macOS M1. 

Retrieval + RAG-Workflow
- Pipeline:
  1) Vektor-Retrieval (top_k=20) mit Metadaten-Filter optional. 
  2) Reranking via lokaler Cross-Encoder auf top_k=20 → top_k=5. 
  3) Kontextkonstruktion mit Zitationsmarkern (Dokument/Seiten-Referenzen) und Abschnittstiteln. 
  4) Antwortgenerierung mit lokalem LLM, verpflichtende Zitationen je Passage. 
- Thresholding: Score-Grenze und MMR optional; fall-back auf Hybrid (BM25+Vector) via n8n-Node-Integration. 

Sicherheit, Governance, Observability
- Auth: BasicAuth auf n8n Webhook/Formular und WebUI via Reverse Proxy oder n8n-Credentials. 
- PII-Filter: Vor Embedding redaction/validation; bei Verstoß Fehlermeldung und Audit-Log-Eintrag. 
- Logging/Tracing: Loki für Logs, Tempo für Traces, Prometheus/Grafana für Metriken (Qdrant, n8n, Ollama Exporter). 
- Best Practices: Least privilege, nur benötigte Ports, Rate Limits am Webhook, Request-Queueing in n8n, regelmäßige Snapshots/Backups. 

Docker-Compose (Überblick)
- Services:
  - n8n (Ports: 5678), Bind mounts: ./.n8n, ./workflows, ./shared, environment für BasicAuth und n8n-DB (SQLite by default oder Postgres optional). 
  - docling-serve (Ports: 5001), optional UI, Caches als Bind mounts für OCR/Modelle. 
  - qdrant (Ports: 6333/6334), Bind mounts: ./qdrant/storage, ./qdrant/snapshots; Ressourcen-Limits optional. 
  - ollama (Ports: 11434), Bind mounts: ./ollama; Runtime nvidia über deploy/reservations für GPU-Hosts. 
  - reranker (optional, falls separiert) oder innerhalb von Ollama-Route. 
  - observability: prometheus, grafana, loki, tempo; optional elasticsearch/kibana. 
- Netzwerk: rag-net (bridge), alle Services verbunden, Ports nur dort published, wo nötig. 

Workflow 1 – Upload/Ingestion (n8n)
- Trigger: Webhook + Formular (BasicAuth geschützt). 
- Validierung: Dateityp (md, txt direkt; pdf, docx, xlsx via Docling), 5 MB Limit, MIME-Prüfung. 
- Parsing:
  - md/txt: direkt lesen, Abschnitte/Überschriften erkennen (Regex/Markdown-Parser). 
  - pdf/docx/xlsx: Docling Serve API; Output JSON; Tabellen aus xlsx normalisieren. 
- Semantisches Chunking:
  - Abschnitte durch Überschriften/Struktur (Docling) definieren. 
  - Overlap minimal; page-aware für pdf/docx; Metadaten wie spezifiziert. 
- Embedding:
  - Embeddings via Ollama Embedding-Endpoint; Retry/Backoff, Rate-Limits, Batching. 
- Upsert in Qdrant:
  - Collection auto-create, HNSW, Payload-Felder; content hash zur Duplicate-Detection; version increment bei Upsert. 
- Ergebnis:
  - Rückgabe JSON mit importierten Chunks, Counts, Snapshot-Hinweis und Zitations-IDs. 

Workflow 2 – Chat/Retrieval (n8n)
- Frontends: Formular, Webhook und WebUI. 
- Schritte:
  - Query normalisieren, optional Query-Expansion. 
  - Vektor-Suche top_k=20 in Qdrant; Filter optional. 
  - Reranking lokal (Cross-Encoder via Ollama/TEI) → top_k=5. 
  - Kontextbau mit Seiten-Referenzen; Antwort-Template mit Zitaten. 
  - LLM-Aufruf (Ollama), Temperatur niedrig, Max-Tokens angepasst. 
  - Antwort + strukturierte Quellenliste zurückgeben. 

Datenmodell
- Collection-Felder:
  - id (uuid), vector (embedding), content (text), meta document_id, filename, page_number, section, chunk_index, hash, created_at, tags, source_url, version. 
- Indizes/Filter: Auf metadata-Felder; effiziente Filter auf filename/tags/created_at. 
- Snapshots: Regelmäßig in ./qdrant/snapshots, versioniert; Offsite-Backup empfohlen. 

Bereitstellung
- Schritte:
  - Repositorium klonen; Verzeichnisse anlegen: ./.n8n, ./workflows, ./shared, ./qdrant/{storage,snapshots}, ./ollama, ./observability. 
  - docker compose up -d; Healthchecks prüfen; n8n-Credentials/BasicAuth setzen. 
  - Ollama Modelle laden: embedding und LLM; GPU-Systeme mit Runtime nvidia. 
  - n8n Workflows importieren; Webhook-URL testen; Qdrant-Collection validieren. 
- Plattformhinweise:
  - macOS M1: ARM64-Images verwenden; keine direkten Zugriffe auf /var/lib/docker/volumes; bind mounts wie definiert. 
  - Windows/NVIDIA: Docker Desktop + WSL2; NVIDIA Container Toolkit; Ports freigeben. 
  - Linux/A6000: NVIDIA Container Toolkit; persistente Mounts und systemd-Unit optional. 

Observability und Security Best Practices
- Exporte aktivieren: n8n Metriken, Qdrant Metriken, Ollama Metriken; Prometheus scrape. 
- Loki/Tempo Pipeline für zentrale Logs/Traces; Dashboards in Grafana für Throughput, Latenzen, Fehlerraten. 
- PII-Filter: Regex/NER vor Embedding; Audit-Log; Fehlerrückmeldung an Upload-Client. 
- Rate Limits/Queueing: Upload-Rate begrenzen; parallele Jobs steuern; Dead-letter Queue für Fehlerfälle. 

MCP Nutzung und lokale Dokumentation
- Für Ablaufplan und Umsetzung wird die lokale n8n Dokumentation n8n_docs_combined.md als Referenz genutzt (Konfiguration, Nodes, Best Practices). 
- Für weiterführende Recherche und Kontext werden angebundene MCP-Server (z. B. Context7, Deepwiki, Exa, Websearch, DuckDuckGo) eingesetzt. 

Akzeptanzkriterien
- Upload-Workflow akzeptiert md, txt, pdf, docx, xlsx; 5 MB Limit; validiert und verarbeitet Dateien; semantische, page-aware Chunks in Qdrant mit Metadaten; Deduplikation und Upsert mit Versionierung. 
- Chat-Workflow liefert Antworten mit Seiten-Referenzen; verwendet lokales LLM und lokalen Reranker; einstellbare top_k und Thresholds; BasicAuth geschützt. 
- Compose-Stack startet reproduzierbar auf ARM64 und x86-64; Observability-Stack zeigt Metriken, Logs, Traces; Snapshots/Backups ausführbar. 

Bereitzustellende Artefakte
- docker-compose.yml (neu) mit ausführlicher Kommentierung und dediziertem Netz. 
- n8n Workflow JSON Dateien:
  - 01_upload_ingest.json
  - 02_chat_retrieval.json 
- README_deploy.md mit detailierter Bereitstellung und Compose-Erklärung. 

Risiken und Mitigation
- GPU-Speichergrenzen auf 12 GB: Auswahl quantisierter Modelle und effizienter KV-Cache-Strategien; alternatives 7B/14B Modell. 
- ARM64 Unterschiede: Nutzung kompatibler Images; Testmatrix Dev/Test/Prod. 
- Qualität: Tuning von Chunking, Reranking und Hybrid-Retrieval; Monitoring der Antwortqualität in Grafana. 

Nächste Schritte
- Modelle festlegen und in Ollama pullen (Embedding + LLM + Reranker). 
- Compose und Verzeichnisse vorbereiten; Workflows importieren; End-to-end-Test mit Beispielfiles. 
- Dashboards und Alerts konfigurieren; Snapshot/Backup-Policy aktivieren.

Ergänzung zum PR: Kontinuierliche Bereitstellung auf GitHub via MCP
- Während der Umsetzung wird das Repository automatisiert und regelmäßig auf GitHub gespiegelt; Commits, Branches und Releases werden über einen angebundenen MCP-Workflow (z. B. GitHub-MCP) erstellt und aktualisiert. 
- Mindestumfang: automatisches Initial-Repo-Setup, Branch-Protection-Workflow, Commit-Hooks aus n8n bei Workflow-Änderungen, tägliche Snapshot-Commits der Bind-Mount-Konfigurationen und Artefakte (Workflows, Compose, README_deploy.md). 
- Trigger: bei Änderungen an 01_upload_ingest.json, 02_chat_retrieval.json, docker-compose.yml, README_deploy.md, sowie periodisch (z. B. 1×/Tag) für Status-/Snapshot-Commits. 
- Secrets und Zugriffe: GitHub-Token als n8n Credential, MCP-Server für GitHub mit minimalen Scopes (repo:status, contents:write) angebunden; keine sensiblen Payloads im Repo, Logs/PII bleiben in Observability-Stack. 
- Governance: Commit-Namensschema mit Konventions-Scopes (feat, fix, docs, infra, workflows, observability), Issues/PRs automatisiert anlegen für Breaking Changes, Review-Gates optional via GitHub Actions.



