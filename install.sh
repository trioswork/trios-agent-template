#!/bin/bash
# ============================================================
# Trios Agent — Instalador Zero-Click
# 
# Instala OpenClaw PURO + configurações validadas.
# Sem adulterar o OpenClaw. Só automatiza o setup.
#
# Uso (VPS virgem):
#   bash <(curl -fsSL https://raw.githubusercontent.com/trioswork/trios-agent-template/master/install.sh)
# ============================================================
set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo ""
echo -e "${BOLD}${CYAN}🤘 Trios Agent — Instalador${NC}"
echo -e "${BOLD}${CYAN}=============================${NC}"
echo ""

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Rode como root: sudo bash install.sh${NC}"
    exit 1
fi

# =============================================
# 1. Dependências do sistema
# =============================================
echo -e "${YELLOW}[1/7] Instalando dependências do sistema...${NC}"
apt-get update -qq
apt-get install -y -qq \
    git curl wget \
    python3 python3-pip python3-venv \
    postgresql postgresql-contrib \
    build-essential libpq-dev \
    ffmpeg \
    > /dev/null 2>&1
echo -e "${GREEN}  ✓ Sistema pronto${NC}"

# =============================================
# 2. Node.js 22
# =============================================
echo -e "${YELLOW}[2/7] Instalando Node.js 22...${NC}"
if ! command -v node &> /dev/null || [[ "$(node -v | cut -d. -f1)" != "v22" ]]; then
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash - > /dev/null 2>&1
    apt-get install -y -qq nodejs > /dev/null 2>&1
fi
echo -e "${GREEN}  ✓ Node.js $(node -v)${NC}"

# =============================================
# 3. PostgreSQL + pgvector
# =============================================
echo -e "${YELLOW}[3/7] Configurando PostgreSQL + pgvector...${NC}"

PG_VER=$(psql --version 2>/dev/null | grep -oP '\d+' | head -1 || echo "16")
apt-get install -y -qq "postgresql-${PG_VER}-pgvector" 2>/dev/null || \
apt-get install -y -qq postgresql-16-pgvector 2>/dev/null || {
    cd /tmp && rm -rf pgvector
    git clone --branch v0.7.0 https://github.com/pgvector/pgvector.git 2>/dev/null
    cd pgvector && make -j$(nproc) > /dev/null 2>&1 && make install > /dev/null 2>&1
    cd /root
}

PG_PASS=$(openssl rand -hex 16 2>/dev/null || python3 -c "import secrets;print(secrets.token_hex(16))")
sudo -u postgres psql -c "CREATE DATABASE agent_memory;" 2>/dev/null || true
sudo -u postgres psql -c "CREATE USER agent WITH PASSWORD '${PG_PASS}';" 2>/dev/null || true
sudo -u postgres psql -d agent_memory -c "CREATE EXTENSION IF NOT EXISTS vector;" 2>/dev/null || true
sudo -u postgres psql -d agent_memory -c "GRANT ALL ON SCHEMA public TO agent;" 2>/dev/null || true
sudo -u postgres psql -d agent_memory -c "ALTER SCHEMA public OWNER TO agent;" 2>/dev/null || true
echo -e "${GREEN}  ✓ PostgreSQL + pgvector${NC}"

# =============================================
# 4. Python deps
# =============================================
echo -e "${YELLOW}[4/7] Instalando dependências Python...${NC}"
pip3 install --break-system-packages -q psycopg2-binary 2>/dev/null || \
    pip3 install psycopg2-binary 2>/dev/null || true
echo -e "${GREEN}  ✓ Python deps${NC}"

# =============================================
# 5. OpenClaw (PURO, sem modificação)
# =============================================
echo -e "${YELLOW}[5/7] Instalando OpenClaw...${NC}"
if ! command -v openclaw &> /dev/null; then
    npm install -g openclaw > /dev/null 2>&1
fi
OC_VER=$(openclaw --version 2>/dev/null || echo "instalado")
echo -e "${GREEN}  ✓ OpenClaw ${OC_VER} (instalação original)${NC}"

# =============================================
# 6. Configurações validadas (não adultera o OpenClaw)
# =============================================
echo -e "${YELLOW}[6/7] Aplicando configurações validadas...${NC}"

WS="/root/.openclaw/workspace"

if [ -d "$WS/.git" ]; then
    echo "  Workspace já existe, atualizando..."
    cd "$WS" && git pull 2>/dev/null || true
else
    mkdir -p /root/.openclaw
    if [ -f "$(dirname "$0")/scripts/memory-sync.py" ]; then
        cp -r "$(cd "$(dirname "$0")" && pwd)" "$WS"
    else
        git clone https://github.com/trioswork/trios-agent-template.git "$WS" 2>/dev/null
    fi
fi

cd "$WS"

# Schema do banco (tabelas de memória + pgvector)
if [ -f "scripts/memory-schema.sql" ]; then
    sudo -u postgres psql -d agent_memory -f scripts/memory-schema.sql 2>/dev/null || true
    echo -e "${GREEN}  ✓ Schema do banco aplicado${NC}"
fi

# Crontab: memory sync a cada 15min
CRON_LINE="*/15 * * * * cd ${WS} && /usr/bin/python3 scripts/memory-sync.py >> /tmp/memory-sync.log 2>&1"
(crontab -l 2>/dev/null | grep -v "memory-sync.py"; echo "$CRON_LINE") | crontab -
echo -e "${GREEN}  ✓ Memory sync configurado (15min)${NC}"

# .env com PG já preenchido
if [ ! -f "$WS/.env" ]; then
    cat > "$WS/.env" << ENVFILE
# ============================================================
# Trios Agent — Variáveis de Ambiente
# ============================================================

# LLM Provider (OBRIGATÓRIO — escolha UM)
# OPENAI_API_KEY=
# ANTHROPIC_API_KEY=
# ZAI_API_KEY=
# GROQ_API_KEY=

# Gemini (embeddings pgvector, opcional)
# GEMINI_API_KEY=

# PostgreSQL (já configurado automaticamente)
PG_HOST=localhost
PG_PORT=5432
PG_DBNAME=agent_memory
PG_USER=agent
PG_PASSWORD=${PG_PASS}
ENVFILE
    echo -e "${GREEN}  ✓ .env criado (falta API key de LLM)${NC}"
else
    if ! grep -q "PG_PASSWORD=${PG_PASS}" "$WS/.env" 2>/dev/null; then
        sed -i "s/^PG_PASSWORD=.*/PG_PASSWORD=${PG_PASS}/" "$WS/.env" 2>/dev/null || true
    fi
    echo -e "${GREEN}  ✓ .env já existe${NC}"
fi

# Gateway service via openclaw (forma oficial)
openclaw gateway install 2>/dev/null || true
echo -e "${GREEN}  ✓ Gateway service instalado${NC}"

# Estrutura de pastas de memória (se não existe)
mkdir -p "$WS/memory/context" "$WS/memory/projects" "$WS/memory/sessions" \
         "$WS/memory/integrations" "$WS/memory/feedback" "$WS/skills" 2>/dev/null || true
echo -e "${GREEN}  ✓ Estrutura de memória criada${NC}"

echo -e "${GREEN}  ✓ Todas configurações aplicadas${NC}"

# =============================================
# 7. openclaw configure (interativo)
# =============================================
echo ""
echo -e "${BOLD}${GREEN}✅ Sistema instalado e configurado!${NC}"
echo ""
echo -e "${BOLD}Agora configure o OpenClaw (3 interações):${NC}"
echo ""
echo -e "  ${CYAN}1.${NC} Coloque sua API key no .env:"
echo -e "     ${BOLD}nano ${WS}/.env${NC}"
echo ""
echo -e "  ${CYAN}2.${NC} Configure modelo, canal e persona:"
echo -e "     ${BOLD}openclaw configure${NC}"
echo ""
echo -e "  ${CYAN}3.${NC} Inicie:"
echo -e "     ${BOLD}openclaw gateway restart${NC}"
echo ""
echo -e "Depois, personalize editando os arquivos em ${WS}:"
echo -e "  ${BOLD}SOUL.md${NC}     ← Personalidade do agente"
echo -e "  ${BOLD}USER.md${NC}     ← Suas informações"
echo -e "  ${BOLD}AGENTS.md${NC}   ← Regras operacionais"
echo ""
echo -e "${BOLD}O que já vem configurado:${NC}"
echo "  ✓ OpenClaw original (sem modificação)"
echo "  ✓ PostgreSQL + pgvector (memória semântica)"
echo "  ✓ Memory sync a cada 15min (crontab)"
echo "  ✓ Scripts de backup e manutenção"
echo "  ✓ Estrutura de pastas de memória"
echo "  ✓ Gateway service (systemd)"
echo "  ✓ Schema do banco (tabelas + embeddings)"
echo ""
echo "🤘 Tudo que a gente já validou, pronto pra usar."
