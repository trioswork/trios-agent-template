# Disaster Recovery

## O que tá no GitHub (recuperável)
- SOUL.md, USER.md, AGENTS.md, IDENTITY.md, HEARTBEAT.md, TOOLS.md, MEMORY.md
- Scripts (memory-sync.py, backup-to-github.sh, pre-compaction.py, etc.)
- memory/ (README, integrations, feedback)
- backups/trios_memory_*.sql.gz (último dump do banco)
- .env (API keys, credenciais)
- financeiro/ (dashboard, calculadora, clientes)

## O que NÃO tá no GitHub (precisa reconfigurar)
- openclaw.json (config do gateway: Telegram bot, providers, plugins)
- Cron jobs (precisa recriar)
- Credenciais de serviço (Supabase, WhatsApp, etc.)

## Procedimento de Recovery

### 1. Criar nova VPS (Ubuntu 22.04+)
```bash
# Atualizar sistema
apt update && apt upgrade -y
```

### 2. Instalar OpenClaw
```bash
# Instalar Node.js 22
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt install -y nodejs

# Instalar OpenClaw
npm install -g openclaw

# Configurar gateway
openclaw configure
```

### 3. Instalar PostgreSQL + pgvector
```bash
apt install -y postgresql postgresql-contrib
apt install -y postgresql-16-pgvector

# Criar banco
sudo -u postgres psql -c "CREATE DATABASE trios_memory;"
sudo -u postgres psql -c "CREATE USER trios WITH PASSWORD '<SUA_SENHA_PG>';"
sudo -u postgres psql -d trios_memory -c "CREATE EXTENSION vector;"
sudo -u postgres psql -d trios_memory -c "GRANT ALL ON SCHEMA public TO trios;"
```

### 4. Clonar workspace do GitHub
```bash
cd /root/.openclaw
git clone https://github.com/trioswork/trios-agent-template.git workspace
cd workspace

# Instalar dependências Python
pip3 install psycopg2-binary --break-system-packages
```

### 5. Restaurar banco de dados
```bash
# Pegar o dump mais recente do GitHub
LATEST=$(ls -t backups/trios_memory_*.sql.gz | head -1)
gunzip -k "$LATEST"

# Restaurar
sudo -u postgres psql trios_memory < "${LATEST%.gz}"
```

### 6. Reconfigurar openclaw.json
Precisa reconfigurar manualmente:
- **Telegram bot token** — pegar do @BotFather
- **Providers** (xiaomi, zai, openai) — API keys
- **Plugins** (deepgram, memory-core)

### 7. Recriar cron jobs
Os crons são salvos no gateway, não no GitHub. Precisa recriar:
- memory-sync-postgres (15min)
- backup-github (2h)
- backup-diario-22h
- Checklist Proativo (4x/dia)
- Consolidação memória (3h)
- Secretária Relatório, Email, Agenda
- Instagram Post 08h

### 8. Testar
```bash
# Gateway
openclaw gateway restart
openclaw status

# Banco
sudo -u postgres psql -d trios_memory -c "SELECT COUNT(*) FROM memory_entries;"

# Busca semântica
python3 scripts/memory-sync.py --agent-id main --dry-run
```

## ⚠️ Riscos
- **Cron jobs** — não estão no GitHub. Se perder, precisa recriar manualmente.
- **openclaw.json** — config do gateway não versionada (tem secrets).
- **Supabase** — banco de finanças é externo, não precisa restaurar.
- **WhatsApp** — precisa reconectar instância (QR code).

## 💡 Sugestão
Salvar um backup do openclaw.json (sem secrets) no GitHub pra facilitar recovery.
