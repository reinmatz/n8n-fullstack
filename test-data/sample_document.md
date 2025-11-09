# Technische Dokumentation: RAG-Systeme

## Einleitung

Retrieval-Augmented Generation (RAG) ist eine moderne Architektur für Large Language Models (LLMs), die externe Wissensdatenbanken mit generativen Modellen kombiniert. Diese Dokumentation beschreibt die Kernkonzepte, Implementierungen und Best Practices für RAG-Systeme.

### Motivation

Traditionelle LLMs leiden unter mehreren Einschränkungen:
- Halluzinationen bei fehlenden Informationen
- Veraltetes Wissen aufgrund des festen Trainingsdatums
- Keine Quellenangaben für generierte Antworten
- Schwierigkeiten bei domänenspezifischem Wissen

RAG-Systeme adressieren diese Probleme durch die Integration einer Retrieval-Komponente.

## Architektur

### Komponenten

Ein vollständiges RAG-System besteht aus folgenden Hauptkomponenten:

1. **Dokumenten-Ingestion**
   - Upload-Interface für verschiedene Dateiformate (PDF, DOCX, TXT)
   - Parsing und Strukturierung der Inhalte
   - Chunking-Strategie zur Aufteilung in verarbeitbare Segmente

2. **Vektordatenbank**
   - Speicherung von Embeddings
   - Effiziente Similaritätssuche (HNSW, IVF)
   - Metadaten-Filterung

3. **Retrieval-Pipeline**
   - Query-Expansion für bessere Trefferquote
   - Hybrid-Suche (Vector + BM25)
   - Reranking der Top-K Ergebnisse

4. **Generierungs-Pipeline**
   - Context-Building mit Zitationsmarkern
   - LLM-Inferenz mit niedrigen Temperaturen
   - Strukturierte Response mit Quellenangaben

### Datenfluss

```
User Query → Query-Expansion → Embedding → Retrieval → Reranking → Context → LLM → Response
```

## Embedding-Modelle

Die Auswahl des Embedding-Modells ist entscheidend für die Retrieval-Qualität. Folgende Kriterien sind wichtig:

- **Sprachunterstützung**: Mehrsprachige Modelle wie bge-m3, e5-large-v2
- **Dimensionalität**: Trade-off zwischen Genauigkeit (1024-dim) und Geschwindigkeit (384-dim)
- **Domain-Adaptation**: Fine-tuning auf spezifische Fachgebiete
- **Lizenz**: Open-Source vs. proprietäre Modelle

### Vergleich gängiger Modelle

| Modell | Dimensionen | Sprachen | MTEB Score | Lizenz |
|--------|-------------|----------|------------|--------|
| bge-m3 | 1024 | 100+ | 66.1 | MIT |
| e5-large-v2 | 1024 | 100+ | 64.5 | MIT |
| multilingual-e5-base | 768 | 100+ | 61.5 | MIT |
| all-MiniLM-L6-v2 | 384 | EN | 58.8 | Apache 2.0 |

## Chunking-Strategien

### Semantisches Chunking

Semantisches Chunking nutzt die Dokumentstruktur (Überschriften, Absätze, Tabellen) als Chunk-Grenzen:

**Vorteile:**
- Erhalt des Kontexts innerhalb eines Chunks
- Natürliche Grenzen reduzieren Informationsverlust
- Bessere Zitierbarkeit durch Abschnittsbezug

**Nachteile:**
- Variable Chunk-Größen
- Komplexere Implementierung
- Abhängigkeit von Parsing-Qualität

### Fixed-Size Chunking

Alternative: Fixe Token-Länge mit Overlap:

```python
CHUNK_SIZE = 512  # Tokens
OVERLAP = 50      # Tokens
```

## Best Practices

### 1. Metadaten-Management

Jeder Chunk sollte umfangreiche Metadaten enthalten:
- `document_id`: Eindeutige Dokument-Referenz
- `filename`: Originaldateiname
- `page_number`: Seitenzahl (bei PDF/DOCX)
- `section`: Abschnittsüberschrift
- `created_at`: Zeitstempel der Ingestion
- `tags`: Kategorisierung
- `version`: Versionskontrolle

### 2. PII-Filterung

Sensible Daten müssen vor der Speicherung gefiltert werden:
- E-Mail-Adressen
- Telefonnummern
- IBAN/Kreditkartennummern
- Sozialversicherungsnummern

Empfehlung: Regex-basierte Erkennung mit optionalem Strict-Mode.

### 3. Hybrid-Retrieval

Kombination von Vektor- und Keyword-Suche (BM25):

```
Score_final = RRF(Score_vector, Score_BM25)
```

Reciprocal Rank Fusion (RRF) merged die Ergebnisse optimal.

### 4. Zitationssystem

LLM-Prompts sollten verpflichtende Quellenangaben fordern:

```
Kontext:
[1] (Quelle: dokument.pdf, Seite 3, Abschnitt: Einleitung)
...

Frage: Was sind die Hauptpunkte?

WICHTIG: Zitiere ALLE verwendeten Quellen mit [1], [2], etc.
```

## Skalierung und Performance

### Latenz-Optimierung

Typische Latenzen in einem RAG-System:
- Embedding: 50-200ms
- Vector-Search: 10-50ms
- Reranking: 100-500ms
- LLM-Generation: 2000-10000ms (abhängig von Modellgröße)

**Optimierungen:**
- Batch-Processing für Embeddings
- HNSW-Index mit optimierten Parametern (m=16, ef_construct=100)
- Quantization für schnellere Inferenz
- Model-Caching

### Horizontale Skalierung

Für hohe Last empfehlen sich:
- Read-Replicas für Vektordatenbank
- Load-Balancer vor LLM-Endpoints
- Queueing-System (z.B. RabbitMQ, Redis)
- Distributed Caching (Redis, Memcached)

## Monitoring und Observability

### Metriken

Wichtige Metriken für RAG-Systeme:

**Retrieval-Qualität:**
- Precision@K
- Recall@K
- Mean Reciprocal Rank (MRR)

**Performance:**
- Query Latency (p50, p95, p99)
- Throughput (Requests/Minute)
- Error Rate

**Datenqualität:**
- Chunk-Count pro Dokument
- Average Chunk-Size
- PII-Detection-Rate

### Logging

Strukturiertes Logging mit folgenden Feldern:
```json
{
  "timestamp": "2025-11-09T12:00:00Z",
  "level": "INFO",
  "query": "...",
  "retrieval_count": 20,
  "rerank_count": 5,
  "llm_tokens": 512,
  "latency_ms": 3500,
  "session_id": "uuid"
}
```

## Sicherheit

### Zugriffskontrolle

- BasicAuth für alle Webhooks
- API-Key-Rotation alle 90 Tage
- Rate-Limiting (z.B. 100 Requests/Minute pro IP)

### Datenschutz

- PII-Redaction vor Embedding
- Encryption-at-Rest für Vektordatenbank
- GDPR-konforme Löschfunktionen

## Zusammenfassung

RAG-Systeme bieten eine leistungsstarke Lösung für wissensintensive LLM-Anwendungen. Die Kombination aus Retrieval und Generation ermöglicht:

- Aktuelle Informationen ohne Retraining
- Quellenbasierte Antworten
- Domain-spezifisches Wissen
- Reduzierte Halluzinationen

**Kernempfehlungen:**
1. Semantisches Chunking für bessere Kontexterhaltung
2. Hybrid-Retrieval (Vector + BM25) für Robustheit
3. Verpflichtende Zitationen im LLM-Prompt
4. Umfassendes Monitoring und Logging

## Anhang

### Weiterführende Ressourcen

- LangChain RAG Documentation
- Qdrant Best Practices Guide
- Ollama Model Library
- n8n Workflow Examples

### Glossar

- **HNSW**: Hierarchical Navigable Small World (Index-Algorithmus)
- **BM25**: Best Matching 25 (Ranking-Funktion)
- **RRF**: Reciprocal Rank Fusion
- **MTEB**: Massive Text Embedding Benchmark
- **PII**: Personally Identifiable Information

---

**Version:** 1.0
**Letzte Aktualisierung:** 9. November 2025
**Autor:** RAG System Documentation Team
