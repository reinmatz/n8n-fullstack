 Zusammenfassung - Alle Services laufen ohne nginx:

  | Service          | URL                             | Status            |
  |------------------|---------------------------------|-------------------|
  | n8n              | http://localhost:5678           | ✅ Running         |
  | Qdrant           | http://localhost:6333           | ✅ Running         |
  | Qdrant Dashboard | http://localhost:6333/dashboard | ✅ Running         |
  | Kibana           | http://localhost:5601           | ✅ Running         |
  | Grafana          | http://localhost:3000           | ✅ Running         |
  | Prometheus       | http://localhost:9090           | ✅ Running         |
  | Elasticsearch    | http://localhost:9200           | ✅ Running         |
  | Ollama           | http://localhost:11434          | ✅ Running         |
  | Docling          | http://localhost:5001           | ✅ Running         |
  | Loki             | http://localhost:3100           | ✅ Running         |
  | Tempo            | http://localhost:3200           | ✅ Running (ready) |
  | Promtail         | (internal)                      | ✅ Running         |
  | Filebeat         | (internal)                      | ✅ Running         |



🎯 Datenfluß-Übersicht

  Container Logs  ─────► Promtail ─────► Loki ◄───── Grafana
                                                        ▲
  Container Stats ─────► cAdvisor ──────┐             │
  n8n Metrics    ─────► n8n:5678 ───────┤             │
  Qdrant Metrics ─────► Qdrant:6333 ────┤             │
  ES Metrics     ─────► ES-Exporter ────┼──► Prometheus
  Loki Metrics   ─────► Loki:3100 ──────┤             │
  Tempo Metrics  ─────► Tempo:3200 ─────┤             │
  Grafana Metrics ────► Grafana:3000 ───┘             │
                                                        │
  App Traces     ─────► Tempo:4317/4318 ──────────────┘

