-- ============================================================
-- Trios Memory Architecture — PostgreSQL + pgvector
-- Versão: 2.0.0 — 2026-05-04
-- Banco: trios_memory (localhost:5432)
-- ============================================================

BEGIN;

-- Extensões necessárias
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "vector";

-- ============================================================
-- 1. TABELA PRINCIPAL: memory_entries
-- ============================================================
CREATE TABLE IF NOT EXISTS memory_entries (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    kind            TEXT NOT NULL CHECK (kind IN (
        'decision', 'lesson', 'insight', 'fact', 'pattern',
        'principle', 'question', 'pending', 'project_update',
        'people_update', 'session_note'
    )),
    category        TEXT NOT NULL CHECK (category IN (
        'context', 'projects', 'sessions', 'integrations',
        'pending', 'feedback'
    )),
    title           TEXT NOT NULL,
    content         TEXT NOT NULL,
    domain          TEXT,
    tags            TEXT[] DEFAULT '{}',
    source_file     TEXT,
    agent_id        TEXT NOT NULL DEFAULT 'main',
    session_id      TEXT,
    retention       TEXT NOT NULL DEFAULT 'permanent' CHECK (retention IN (
        'permanent', 'tactical_30d', 'session_only'
    )),
    expires_at      TIMESTAMPTZ,
    embedding       VECTOR(1536),
    content_hash    VARCHAR(64),
    version         INTEGER NOT NULL DEFAULT 1,
    is_current      BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Índices para memory_entries
CREATE INDEX IF NOT EXISTS idx_memory_entries_kind ON memory_entries(kind);
CREATE INDEX IF NOT EXISTS idx_memory_entries_category ON memory_entries(category);
CREATE INDEX IF NOT EXISTS idx_memory_entries_domain ON memory_entries(domain);
CREATE INDEX IF NOT EXISTS idx_memory_entries_tags ON memory_entries USING GIN(tags);
CREATE INDEX IF NOT EXISTS idx_memory_entries_agent_id ON memory_entries(agent_id);
CREATE INDEX IF NOT EXISTS idx_memory_entries_retention ON memory_entries(retention);
CREATE INDEX IF NOT EXISTS idx_memory_entries_is_current ON memory_entries(is_current);
CREATE INDEX IF NOT EXISTS idx_memory_entries_expires_at ON memory_entries(expires_at) WHERE expires_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_memory_entries_content_hash ON memory_entries(content_hash);
CREATE INDEX IF NOT EXISTS idx_memory_entries_source_file ON memory_entries(source_file);
CREATE INDEX IF NOT EXISTS idx_memory_entries_embedding ON memory_entries USING HNSW(embedding vector_cosine_ops);

-- ============================================================
-- 2. TABELA DE CONEXÕES: memory_edges
-- ============================================================
CREATE TABLE IF NOT EXISTS memory_edges (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    from_id         UUID NOT NULL REFERENCES memory_entries(id) ON DELETE CASCADE,
    to_id           UUID NOT NULL REFERENCES memory_entries(id) ON DELETE CASCADE,
    relation_type   TEXT NOT NULL CHECK (relation_type IN (
        'same_mechanism_as', 'analogous_to', 'instance_of',
        'generalizes', 'causes', 'depends_on', 'contradicts',
        'evidence_for', 'refines'
    )),
    why             TEXT NOT NULL CHECK (LENGTH(why) >= 20),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(from_id, to_id, relation_type)
);

CREATE INDEX IF NOT EXISTS idx_memory_edges_from ON memory_edges(from_id);
CREATE INDEX IF NOT EXISTS idx_memory_edges_to ON memory_edges(to_id);
CREATE INDEX IF NOT EXISTS idx_memory_edges_relation ON memory_edges(relation_type);

-- ============================================================
-- 3. TABELA DE SESSÕES: memory_sessions
-- ============================================================
CREATE TABLE IF NOT EXISTS memory_sessions (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_id            TEXT NOT NULL,
    session_key         TEXT,
    started_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ended_at            TIMESTAMPTZ,
    entries_created     INTEGER DEFAULT 0,
    entries_updated     INTEGER DEFAULT 0,
    compaction_triggered BOOLEAN DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_memory_sessions_agent ON memory_sessions(agent_id);
CREATE INDEX IF NOT EXISTS idx_memory_sessions_started ON memory_sessions(started_at);

-- ============================================================
-- 4. TABELA DE SYNC LOG: memory_sync_log
-- ============================================================
CREATE TABLE IF NOT EXISTS memory_sync_log (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sync_type           TEXT NOT NULL CHECK (sync_type IN (
        'periodic_15min', 'pre_compaction', 'manual'
    )),
    agent_id            TEXT NOT NULL DEFAULT 'main',
    entries_synced      INTEGER DEFAULT 0,
    embeddings_generated INTEGER DEFAULT 0,
    errors              INTEGER DEFAULT 0,
    duration_ms         INTEGER,
    details             JSONB,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sync_log_type ON memory_sync_log(sync_type);
CREATE INDEX IF NOT EXISTS idx_sync_log_created ON memory_sync_log(created_at);

-- ============================================================
-- 5. TABELA DE FEEDBACK: memory_feedback
-- ============================================================
CREATE TABLE IF NOT EXISTS memory_feedback (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    context         TEXT NOT NULL,
    decision        TEXT NOT NULL CHECK (decision IN ('approve', 'reject')),
    reason          TEXT,
    tags            TEXT[] DEFAULT '{}',
    agent_id        TEXT NOT NULL DEFAULT 'main',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_feedback_decision ON memory_feedback(decision);
CREATE INDEX IF NOT EXISTS idx_feedback_tags ON memory_feedback USING GIN(tags);

-- ============================================================
-- 6. FUNÇÕES SQL
-- ============================================================

-- Busca semântica via pgvector
CREATE OR REPLACE FUNCTION search_memories(
    query_embedding VECTOR(1536),
    match_count INTEGER DEFAULT 10,
    filter_kind TEXT DEFAULT NULL,
    filter_domain TEXT DEFAULT NULL,
    filter_agent TEXT DEFAULT NULL
)
RETURNS TABLE (
    id UUID,
    kind TEXT,
    category TEXT,
    title TEXT,
    content TEXT,
    domain TEXT,
    tags TEXT[],
    agent_id TEXT,
    source_file TEXT,
    similarity FLOAT,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        me.id,
        me.kind,
        me.category,
        me.title,
        me.content,
        me.domain,
        me.tags,
        me.agent_id,
        me.source_file,
        1 - (me.embedding <=> query_embedding) AS similarity,
        me.created_at,
        me.updated_at
    FROM memory_entries me
    WHERE me.is_current = TRUE
        AND me.embedding IS NOT NULL
        AND (filter_kind IS NULL OR me.kind = filter_kind)
        AND (filter_domain IS NULL OR me.domain = filter_domain)
        AND (filter_agent IS NULL OR me.agent_id = filter_agent)
    ORDER BY me.embedding <=> query_embedding
    LIMIT match_count;
END;
$$;

-- Busca por texto exato (fallback quando não tem embedding)
CREATE OR REPLACE FUNCTION search_memories_text(
    search_query TEXT,
    match_count INTEGER DEFAULT 10,
    filter_kind TEXT DEFAULT NULL,
    filter_domain TEXT DEFAULT NULL
)
RETURNS TABLE (
    id UUID,
    kind TEXT,
    category TEXT,
    title TEXT,
    content TEXT,
    domain TEXT,
    tags TEXT[],
    agent_id TEXT,
    similarity FLOAT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        me.id,
        me.kind,
        me.category,
        me.title,
        me.content,
        me.domain,
        me.tags,
        me.agent_id,
        1.0::FLOAT AS similarity
    FROM memory_entries me
    WHERE me.is_current = TRUE
        AND (me.title ILIKE '%' || search_query || '%'
             OR me.content ILIKE '%' || search_query || '%'
             OR search_query = ANY(me.tags))
        AND (filter_kind IS NULL OR me.kind = filter_kind)
        AND (filter_domain IS NULL OR me.domain = filter_domain)
    ORDER BY me.updated_at DESC
    LIMIT match_count;
END;
$$;

-- Cleanup de memórias táticas expiradas
CREATE OR REPLACE FUNCTION cleanup_expired()
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    -- Marca como não-atual as memórias expiradas
    UPDATE memory_entries
    SET is_current = FALSE, updated_at = NOW()
    WHERE retention = 'tactical_30d'
        AND expires_at IS NOT NULL
        AND expires_at < NOW()
        AND is_current = TRUE;

    GET DIAGNOSTICS deleted_count = ROW_COUNT;

    -- Log da operação
    INSERT INTO memory_sync_log (sync_type, agent_id, entries_synced, details)
    VALUES ('periodic_15min', 'system', deleted_count,
            jsonb_build_object('action', 'cleanup_expired', 'count', deleted_count));

    RETURN deleted_count;
END;
$$;

-- Estatísticas gerais
CREATE OR REPLACE FUNCTION get_memory_stats()
RETURNS TABLE (
    stat_type TEXT,
    stat_key TEXT,
    count BIGINT
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Total por kind
    RETURN QUERY
    SELECT 'by_kind'::TEXT, me.kind, COUNT(*)
    FROM memory_entries me WHERE me.is_current = TRUE
    GROUP BY me.kind;

    -- Total por category
    RETURN QUERY
    SELECT 'by_category'::TEXT, me.category, COUNT(*)
    FROM memory_entries me WHERE me.is_current = TRUE
    GROUP BY me.category;

    -- Total por agent
    RETURN QUERY
    SELECT 'by_agent'::TEXT, me.agent_id, COUNT(*)
    FROM memory_entries me WHERE me.is_current = TRUE
    GROUP BY me.agent_id;

    -- Total por retention
    RETURN QUERY
    SELECT 'by_retention'::TEXT, me.retention, COUNT(*)
    FROM memory_entries me WHERE me.is_current = TRUE
    GROUP BY me.retention;

    -- Total geral
    RETURN QUERY
    SELECT 'total'::TEXT, 'current'::TEXT, COUNT(*)
    FROM memory_entries me WHERE me.is_current = TRUE;

    RETURN QUERY
    SELECT 'total'::TEXT, 'all_versions'::TEXT, COUNT(*)
    FROM memory_entries;

    RETURN QUERY
    SELECT 'total'::TEXT, 'edges'::TEXT, COUNT(*)
    FROM memory_edges;
END;
$$;

-- Inserir ou atualizar memória com versionamento
CREATE OR REPLACE FUNCTION upsert_memory(
    p_kind TEXT,
    p_category TEXT,
    p_title TEXT,
    p_content TEXT,
    p_domain TEXT DEFAULT NULL,
    p_tags TEXT[] DEFAULT '{}',
    p_source_file TEXT DEFAULT NULL,
    p_agent_id TEXT DEFAULT 'main',
    p_session_id TEXT DEFAULT NULL,
    p_retention TEXT DEFAULT 'permanent',
    p_expires_at TIMESTAMPTZ DEFAULT NULL,
    p_content_hash VARCHAR(64) DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
AS $$
DECLARE
    existing_id UUID;
    new_id UUID;
    next_version INTEGER;
BEGIN
    -- Procura versão existente pelo hash do conteúdo
    SELECT me.id INTO existing_id
    FROM memory_entries me
    WHERE me.content_hash = p_content_hash
        AND me.is_current = TRUE
        AND me.agent_id = p_agent_id
    LIMIT 1;

    IF existing_id IS NOT NULL THEN
        -- Atualiza a versão existente
        UPDATE memory_entries
        SET updated_at = NOW()
        WHERE id = existing_id;
        RETURN existing_id;
    END IF;

    -- Procura por título + fonte (possível atualização de conteúdo)
    SELECT me.id, me.version INTO existing_id, next_version
    FROM memory_entries me
    WHERE me.title = p_title
        AND me.source_file = p_source_file
        AND me.is_current = TRUE
    LIMIT 1;

    IF existing_id IS NOT NULL THEN
        -- Desativa versão antiga
        UPDATE memory_entries
        SET is_current = FALSE, updated_at = NOW()
        WHERE id = existing_id;

        -- Cria nova versão
        INSERT INTO memory_entries (
            kind, category, title, content, domain, tags,
            source_file, agent_id, session_id, retention,
            expires_at, content_hash, version
        ) VALUES (
            p_kind, p_category, p_title, p_content, p_domain, p_tags,
            p_source_file, p_agent_id, p_session_id, p_retention,
            p_expires_at, p_content_hash, COALESCE(next_version, 0) + 1
        ) RETURNING id INTO new_id;

        RETURN new_id;
    END IF;

    -- Inserção nova
    INSERT INTO memory_entries (
        kind, category, title, content, domain, tags,
        source_file, agent_id, session_id, retention,
        expires_at, content_hash
    ) VALUES (
        p_kind, p_category, p_title, p_content, p_domain, p_tags,
        p_source_file, p_agent_id, p_session_id, p_retention,
        p_expires_at, p_content_hash
    ) RETURNING id INTO new_id;

    RETURN new_id;
END;
$$;

-- ============================================================
-- 7. VIEWS
-- ============================================================

-- Memórias atuais
CREATE OR REPLACE VIEW v_current_memories AS
SELECT
    me.id, me.kind, me.category, me.title, me.content,
    me.domain, me.tags, me.source_file, me.agent_id,
    me.retention, me.expires_at, me.version,
    me.created_at, me.updated_at
FROM memory_entries me
WHERE me.is_current = TRUE
ORDER BY me.updated_at DESC;

-- Atividade por agente
CREATE OR REPLACE VIEW v_agent_activity AS
SELECT
    me.agent_id,
    COUNT(*) FILTER (WHERE me.created_at >= NOW() - INTERVAL '24 hours') AS last_24h,
    COUNT(*) FILTER (WHERE me.created_at >= NOW() - INTERVAL '7 days') AS last_7d,
    COUNT(*) FILTER (WHERE me.created_at >= NOW() - INTERVAL '30 days') AS last_30d,
    COUNT(*) AS total_current,
    MAX(me.created_at) AS last_entry_at
FROM memory_entries me
WHERE me.is_current = TRUE
GROUP BY me.agent_id;

-- Pendências ativas
CREATE OR REPLACE VIEW v_pending_items AS
SELECT
    me.id, me.title, me.content, me.domain, me.tags,
    me.agent_id, me.created_at, me.updated_at
FROM memory_entries me
WHERE me.is_current = TRUE
    AND (me.kind = 'pending' OR me.category = 'pending')
ORDER BY me.created_at DESC;

-- Memórias táticas expirando em 7 dias
CREATE OR REPLACE VIEW v_expiring_soon AS
SELECT
    me.id, me.kind, me.title, me.content, me.domain,
    me.retention, me.expires_at,
    EXTRACT(DAY FROM me.expires_at - NOW())::INTEGER AS days_until_expiry
FROM memory_entries me
WHERE me.is_current = TRUE
    AND me.retention = 'tactical_30d'
    AND me.expires_at IS NOT NULL
    AND me.expires_at <= NOW() + INTERVAL '7 days'
    AND me.expires_at > NOW()
ORDER BY me.expires_at ASC;

-- ============================================================
-- 8. MIGRAÇÃO: Dados da tabela antiga (memories) → memory_entries
-- ============================================================

INSERT INTO memory_entries (
    kind, category, title, content, domain, tags,
    source_file, agent_id, retention, embedding, content_hash,
    created_at, updated_at
)
SELECT
    m.kind,
    CASE
        WHEN m.source = 'MEMORY.md' THEN 'context'
        WHEN m.source = 'decisions' THEN 'context'
        WHEN m.source LIKE 'projects/%' THEN 'projects'
        WHEN m.source LIKE 'sessions/%' THEN 'sessions'
        WHEN m.source LIKE 'integrations/%' THEN 'integrations'
        WHEN m.source = 'pending.md' THEN 'pending'
        WHEN m.source LIKE 'feedback/%' THEN 'feedback'
        ELSE 'context'
    END AS category,
    m.title,
    m.content,
    COALESCE(m.domain, 'geral'),
    COALESCE(m.tags, '{}'),
    m.source,
    'main' AS agent_id,
    'permanent' AS retention,
    m.embedding,
    m.content_hash,
    m.created_at,
    m.updated_at
FROM memories m
WHERE NOT EXISTS (
    SELECT 1 FROM memory_entries me
    WHERE me.content_hash = m.content_hash
);

-- Nota: memory_edges antiga usa integer PKs, nova usa UUID.
-- Como não há edges existentes (0 rows), não é necessário migrar.
-- Se edges forem adicionadas no futuro, usar os UUIDs de memory_entries.

COMMIT;

-- ============================================================
-- VERIFICAÇÃO
-- ============================================================
SELECT 'memory_entries' AS tabela, COUNT(*) AS total FROM memory_entries
UNION ALL
SELECT 'memory_edges', COUNT(*) FROM memory_edges
UNION ALL
SELECT 'memory_sessions', COUNT(*) FROM memory_sessions
UNION ALL
SELECT 'memory_sync_log', COUNT(*) FROM memory_sync_log
UNION ALL
SELECT 'memory_feedback', COUNT(*) FROM memory_feedback;
