#!/bin/bash
# ============================================================
# Trios Workspace — Instalador
# Uso: bash install.sh
# ============================================================
set -e

echo "🤘 Trios Workspace — Instalador"
echo "================================"
echo ""

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# 1. Sistema
echo -e "${YELLOW}[1/7] Atualizando sistema...${NC}"
apt update && apt upgrade -y

# 2. Node.js 22
echo -e "${YELLOW}[2/7] Instalando Node.js 22...${NC}"
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
    apt install -y nodejs
fi
echo -e "${GREEN}  Node.js $(node -v)${NC}"

# 3. PostgreSQL + pgvector
echo -e "${YELLOW}[3/7] Instalando PostgreSQL + pgvector...${NC}"
if ! command -v psql &> /dev/null; then
    apt install -y postgresql postgresql-contrib
fi
PG_VERSION=$(psql --version | grep -oP '\d+' | head -1)
apt install -y postgresql-${PG_VERSION}-pgvector 2>/dev/null || apt install -y postgresql-16-pvvector 2>/dev/null || true

# Criar banco
sudo -u postgres psql -c "CREATE DATABASE trios_memory;" 2>/dev/null || true
# Gerar senha aleatória se não existir
PG_PASS=${PG_PASSWORD:-$(openssl rand -hex 16)}
sudo -u postgres psql -c "CREATE USER trios WITH PASSWORD '$PG_PASS';" 2>/dev/null || true
echo "  Senha PG salva em .env (PG_PASSWORD=$PG_PASS)"
sudo -u postgres psql -d trios_memory -c "CREATE EXTENSION IF NOT EXISTS vector;" 2>/dev/null || true
sudo -u postgres psql -d trios_memory -c "GRANT ALL ON SCHEMA public TO trios;" 2>/dev/null || true
sudo -u postgres psql -d trios_memory -c "ALTER SCHEMA public OWNER TO trios;" 2>/dev/null || true
echo -e "${GREEN}  PostgreSQL $(psql --version | head -1)${NC}"

# 4. Python deps
echo -e "${YELLOW}[4/7] Instalando dependências Python...${NC}"
pip3 install psycopg2-binary --break-system-packages 2>/dev/null || pip3 install psycopg2-binary

# 5. OpenClaw
echo -e "${YELLOW}[5/7] Instalando OpenClaw...${NC}"
if ! command -v openclaw &> /dev/null; then
    npm install -g openclaw
fi
echo -e "${GREEN}  OpenClaw $(openclaw --version 2>/dev/null || echo 'instalado')${NC}"

# 6. Workspace
echo -e "${YELLOW}[6/7] Configurando workspace...${NC}"
WORKSPACE="/root/.openclaw/workspace"
if [ ! -d "$WORKSPACE" ]; then
    mkdir -p /root/.openclaw
    cd /root/.openclaw
    git clone https://github.com/trioswork/trios-agent-template.git workspace
fi
cd "$WORKSPACE"

# Restaurar banco (se dump existe)
LATEST=$(ls -t backups/trios_memory_*.sql.gz 2>/dev/null | head -1)
if [ -n "$LATEST" ]; then
    echo -e "${YELLOW}  Restaurando banco de dados...${NC}"
    gunzip -kf "$LATEST"
    DUMP_FILE="${LATEST%.gz}"
    sudo -u postgres psql trios_memory < "$DUMP_FILE" 2>/dev/null || echo "  (aviso: tabela já existe, continuando)"
    echo -e "${GREEN}  Banco restaurado${NC}"
else
    echo -e "${YELLOW}  Nenhum dump encontrado, criando schema...${NC}"
    if [ -f "scripts/memory-schema.sql" ]; then
        sudo -u postgres psql -d trios_memory -f scripts/memory-schema.sql 2>/dev/null || true
    fi
fi

# 7. Configurar .env
echo -e "${YELLOW}[7/7] Configurando credenciais...${NC}"
if [ ! -f "$WORKSPACE/.env" ]; then
    cp "$WORKSPACE/.env.example" "$WORKSPACE/.env" 2>/dev/null || true
    echo -e "${RED}  IMPORTANTE: Edite $WORKSPACE/.env com suas credenciais${NC}"
fi

# Schema do banco (se não existe)
sudo -u postgres psql -d trios_memory -f "$WORKSPACE/scripts/memory-schema.sql" 2>/dev/null || true

echo ""
echo "================================"
echo -e "${GREEN}✅ Instalação concluída!${NC}"
echo ""
echo "Próximos passos:"
echo "  1. Edite /root/.openclaw/workspace/.env com suas API keys"
echo "  2. Rode: openclaw configure"
echo "  3. Rode: openclaw gateway start"
echo "  4. Configure Telegram bot com /start"
echo ""
echo "Credenciais necessárias (no .env):"
echo "  - OPENAI_API_KEY"
echo "  - GEMINI_API_KEY"
echo "  - SUPABASE_URL + SUPABASE_KEY"
echo "  - GOOGLE_CLIENT_ID + GOOGLE_CLIENT_SECRET + GOOGLE_REFRESH_TOKEN_ARONE"
echo ""
echo "GitHub: https://github.com/trioswork/trios-agent-template"
echo "🤘 Pronto pra usar!"
