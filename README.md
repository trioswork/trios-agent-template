# 🤖 Agent Template

Template instalável para OpenClaw Agent. Instale um agente IA operacional em minutos.

## Instalação rápida

```bash
# 1. Subir VPS (Ubuntu/Debian)
# 2. Rodar:
bash setup.sh
# 3. Conectar Telegram:
openclaw configure
# 4. Iniciar:
openclaw gateway start
```

## O que faz

O `setup.sh` instala automaticamente:
- Node.js 22
- PostgreSQL + pgvector
- OpenClaw
- Workspace com scripts, templates e schema

O `onboarding.sh` configura:
- Persona do agente (nome, emoji, tom)
- Dados do negócio (empresa, clientes, metas)
- Gera SOUL.md, USER.md, IDENTITY.md, AGENTS.md, MEMORY.md, HEARTBEAT.md
- Limpa memória do banco (zero dados de empresa anterior)

## Estrutura

```
├── setup.sh              # Instalador completo (tudo em um)
├── install.sh            # Infraestrutura (Node, PG, OpenClaw)
├── onboarding.sh         # Wizard de configuração
├── templates/            # Templates genéricos
│   ├── SOUL.md           # Persona
│   ├── USER.md           # Dados do usuário
│   ├── IDENTITY.md       # Identidade do agente
│   ├── AGENTS.md         # Regras operacionais
│   ├── MEMORY.md         # Índice de memória
│   └── HEARTBEAT.md      # Checklist de heartbeats
├── scripts/              # Scripts de automação
│   ├── memory-sync.py    # Sync de memória
│   ├── pre-compaction.py # Extração antes de compactação
│   ├── memory-to-postgres.py
│   ├── generate-embeddings.py
│   ├── backup-to-github.sh
│   └── memory-schema.sql
└── DISASTER-RECOVERY.md  # Guia de recuperação
```

## Requisitos

- VPS Ubuntu/Debian (mínimo 1GB RAM)
- Token de API de IA (OpenAI, Z.ai, Xiaomi ou Google)
- Bot do Telegram (@BotFather)
