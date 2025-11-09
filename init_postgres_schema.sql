-- PostgreSQL Schema für n8n RAG System Chat History
-- Version: 1.0
-- Date: 2025-11-09

-- Chat Sessions Tabelle
CREATE TABLE IF NOT EXISTS chat_sessions (
    session_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    user_id VARCHAR(255),
    metadata JSONB DEFAULT '{}',
    is_active BOOLEAN DEFAULT true
);

-- Messages Tabelle
CREATE TABLE IF NOT EXISTS messages (
    message_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES chat_sessions(session_id) ON DELETE CASCADE,
    role VARCHAR(50) NOT NULL CHECK (role IN ('user', 'assistant', 'system')),
    content TEXT NOT NULL,
    citations JSONB DEFAULT '[]',
    metadata JSONB DEFAULT '{}',
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    token_count INTEGER,
    model_used VARCHAR(100)
);

-- Indizes für Performance
CREATE INDEX IF NOT EXISTS idx_messages_session_id ON messages(session_id);
CREATE INDEX IF NOT EXISTS idx_messages_timestamp ON messages(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_messages_role ON messages(role);
CREATE INDEX IF NOT EXISTS idx_chat_sessions_created_at ON chat_sessions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_chat_sessions_user_id ON chat_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_chat_sessions_is_active ON chat_sessions(is_active);

-- GIN Index für JSONB-Felder (für schnelle JSON-Abfragen)
CREATE INDEX IF NOT EXISTS idx_messages_citations_gin ON messages USING GIN (citations);
CREATE INDEX IF NOT EXISTS idx_messages_metadata_gin ON messages USING GIN (metadata);
CREATE INDEX IF NOT EXISTS idx_chat_sessions_metadata_gin ON chat_sessions USING GIN (metadata);

-- Trigger für automatische updated_at-Aktualisierung
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_chat_sessions_updated_at
    BEFORE UPDATE ON chat_sessions
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- View für aggregierte Session-Statistiken
CREATE OR REPLACE VIEW session_statistics AS
SELECT
    cs.session_id,
    cs.created_at,
    cs.updated_at,
    cs.user_id,
    COUNT(m.message_id) as message_count,
    SUM(CASE WHEN m.role = 'user' THEN 1 ELSE 0 END) as user_message_count,
    SUM(CASE WHEN m.role = 'assistant' THEN 1 ELSE 0 END) as assistant_message_count,
    SUM(m.token_count) as total_tokens,
    MAX(m.timestamp) as last_message_at
FROM
    chat_sessions cs
LEFT JOIN
    messages m ON cs.session_id = m.session_id
GROUP BY
    cs.session_id, cs.created_at, cs.updated_at, cs.user_id;

-- Kommentare für Dokumentation
COMMENT ON TABLE chat_sessions IS 'Speichert Chat-Sitzungen mit Metadaten und Zeitstempeln';
COMMENT ON TABLE messages IS 'Speichert Chat-Nachrichten mit Zitationen und Kontext';
COMMENT ON COLUMN messages.citations IS 'JSON-Array mit Quellenangaben: [{document_id, filename, page_number, section, snippet}]';
COMMENT ON COLUMN messages.metadata IS 'Zusätzliche Metadaten wie filters, top_k, model_parameters, etc.';
COMMENT ON VIEW session_statistics IS 'Aggregierte Statistiken pro Chat-Session für Monitoring und Analytics';

-- Beispiel-Insert für Tests (auskommentiert)
-- INSERT INTO chat_sessions (session_id, user_id, metadata)
-- VALUES ('00000000-0000-0000-0000-000000000001', 'test_user', '{"source": "test"}');
