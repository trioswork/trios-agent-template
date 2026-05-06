# MEMORY.md — Índice de Memória

> Banco PostgreSQL + pgvector. Este arquivo é o mapa.

## 🧠 Banco de Dados

- **Host:** localhost:5432/trios_memory
- **User:** trios
- **Tabelas:** memory_entries, memory_edges, memory_sessions, memory_sync_log, memory_feedback

## 📂 Estrutura

| Arquivo | Propósito |
|---------|-----------|
| `SOUL.md` | Persona do agente |
| `USER.md` | Info do usuário |
| `AGENTS.md` | Regras operacionais |
| `IDENTITY.md` | Identidade do agente |
| `HEARTBEAT.md` | Checklist de heartbeats |
| `MEMORY.md` | Este arquivo (índice) |

## 🔄 Como funciona

```
Sessão começa → Carrega SOUL.md, USER.md, AGENTS.md, MEMORY.md
    ↓
Precisa de memória? → search_memories() no PostgreSQL
    ↓
90% do limite da sessão → pre-compaction.py extrai → compacta
```

## 🔍 Como buscar memórias

```python
search_memories("termo")  # Busca semântica
```

---
*Configurado via Onboarding em {{DATE}}*
