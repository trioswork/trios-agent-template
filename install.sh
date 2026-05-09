#!/bin/bash
# ============================================================
# Trios Agent — Instalador Zero-Click
# VPS virgem → agente funcionando em 5 minutos
#
# Uso (numa VPS recém-criada):
#   bash <(curl -fsSL https://raw.githubusercontent.com/trioswork/trios-agent-template/main/install.sh)
#
# Ou se já clonou o repo:
#   bash install.sh
# ============================================================
set -e

# Cores
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

# =============================================
# Detectar se é root
# =============================================
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Rode como root: sudo bash install.sh${NC}"
    exit 1
fi

# =============================================
# 1. Sistema (silencioso, sem干预 desnecessário)
# =============================================
echo -e "${YELLOW}[1/8] Preparando sistema...${NC}"
apt-get update -qq

# Dependências essenciais (git, curl, python3, pip, postgresql, build tools)
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
echo -e "${YELLOW}[2/8] Instalando Node.js 22...${NC}"
if ! command -v node &> /dev/null || [[ "$(node -v | cut -d. -f1)" != "v22" ]]; then
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash - > /dev/null 2>&1
    apt-get install -y -qq nodejs > /dev/null 2>&1
fi
echo -e "${GREEN}  ✓ Node.js $(node -v)${NC}"

# =============================================
# 3. PostgreSQL + pgvector
# =============================================
echo -e "${YELLOW}[3/8] Configurando PostgreSQL + pgvector...${NC}"

# Instalar pgvector
PG_VER=$(psql --version 2>/dev/null | grep -oP '\d+' | head -1 || echo "16")
apt-get install -y -qq "postgresql-${PG_VER}-pgvector" 2>/dev/null || \
apt-get install -y -qq postgresql-16-pgvector 2>/dev/null || {
    # Compilar pgvector se não tiver pacote
    echo "  Compilando pgvector..."
    cd /tmp
    rm -rf pgvector
    git clone --branch v0.7.0 https://github.com/pgvector/pgvector.git 2>/dev/null
    cd pgvector
    make -j$(nproc) > /dev/null 2>&1
    make install > /dev/null 2>&1
    cd /root
}

# Criar banco e usuário
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
echo -e "${YELLOW}[4/8] Instalando dependências Python...${NC}"
pip3 install --break-system-packages -q psycopg2-binary 2>/dev/null || \
    pip3 install psycopg2-binary 2>/dev/null || true
echo -e "${GREEN}  ✓ Python deps${NC}"

# =============================================
# 5. OpenClaw
# =============================================
echo -e "${YELLOW}[5/8] Instalando OpenClaw...${NC}"
if ! command -v openclaw &> /dev/null; then
    npm install -g openclaw > /dev/null 2>&1
fi
OC_VER=$(openclaw --version 2>/dev/null || echo "instalado")
echo -e "${GREEN}  ✓ OpenClaw ${OC_VER}${NC}"

# =============================================
# 6. Workspace (clonar template)
# =============================================
echo -e "${YELLOW}[6/8] Montando workspace...${NC}"
WS="/root/.openclaw/workspace"

if [ -d "$WS/.git" ]; then
    echo "  Workspace já existe, pulando clone."
else
    mkdir -p /root/.openclaw
    if [ -f "$(dirname "$0")/scripts/memory-sync.py" ]; then
        # Rodando de dentro do repo já clonado
        cp -r "$(cd "$(dirname "$0")" && pwd)" "$WS"
    else
        # Clonar do GitHub
        git clone https://github.com/trioswork/trios-agent-template.git "$WS" 2>/dev/null
    fi
fi

cd "$WS"

# Criar schema do banco
if [ -f "scripts/memory-schema.sql" ]; then
    sudo -u postgres psql -d agent_memory -f scripts/memory-schema.sql 2>/dev/null || true
fi

# Configurar crontab (memory sync a cada 15min)
CRON_LINE="*/15 * * * * cd ${WS} && /usr/bin/python3 scripts/memory-sync.py >> /tmp/memory-sync.log 2>&1"
(crontab -l 2>/dev/null | grep -v "memory-sync.py"; echo "$CRON_LINE") | crontab -

echo -e "${GREEN}  ✓ Workspace montado${NC}"

# =============================================
# 7. .env (interativo)
# =============================================
echo -e "${YELLOW}[7/8] Configurando credenciais...${NC}"

if [ ! -f "$WS/.env" ]; then
    cat > "$WS/.env" << ENVFILE
# ============================================================
# Trios Agent — Variáveis de Ambiente
# Preencha com suas credenciais
# ============================================================

# LLM Provider (obrigatório)
# Opções: OPENAI_API_KEY, ANTHROPIC_API_KEY, ZAI_API_KEY, etc.
# Use a chave do seu provider preferido
LLM_API_KEY=
LLM_PROVIDER=openai

# Gemini (embeddings, opcional)
GEMINI_API_KEY=

# PostgreSQL (memória local, já configurado)
PG_HOST=localhost
PG_PORT=5432
PG_DBNAME=agent_memory
PG_USER=agent
PG_PASSWORD=${PG_PASS}
ENVFILE

    echo -e "${RED}  ⚠ IMPORTANTE: Edite ${WS}/env com sua API key${NC}"
    echo -e "${RED}    nano ${WS}/.env${NC}"
else
    # Atualizar PG_PASSWORD se necessário
    if ! grep -q "PG_PASSWORD=${PG_PASS}" "$WS/.env" 2>/dev/null; then
        sed -i "s/^PG_PASSWORD=.*/PG_PASSWORD=${PG_PASS}/" "$WS/.env" 2>/dev/null || true
    fi
    echo -e "${GREEN}  ✓ .env já existe${NC}"
fi

# =============================================
# 8. Primeiro boot
# =============================================
echo -e "${YELLOW}[8/8] Preparando primeiro boot...${NC}"

# Systemd service pro gateway
mkdir -p ~/.config/systemd/user

cat > ~/.config/systemd/user/openclaw-gateway.service << SERVICE
[Unit]
Description=OpenClaw Gateway
After=network.target postgresql.service

[Service]
Type=simple
ExecStart=/usr/bin/openclaw gateway start
Restart=on-failure
RestartSec=5
WorkingDirectory=${WS}

[Install]
WantedBy=default.target
SERVICE

systemctl --user daemon-reload 2>/dev/null || true

echo -e "${GREEN}  ✓ Service configurado${NC}"

# =============================================
# FIM
# =============================================
echo ""
echo -e "${BOLD}${GREEN}✅ Instalação concluída!${NC}"
echo ""
echo -e "${BOLD}Próximos passos:${NC}"
echo ""
echo -e "  ${CYAN}1.${NC} Edite o .env com sua API key de LLM:"
echo -e "     ${BOLD}nano ${WS}/.env${NC}"
echo ""
echo -e "  ${CYAN}2.${NC} Configure o OpenClaw (escolha modelo, canal, etc):"
echo -e "     ${BOLD}openclaw configure${NC}"
echo ""
echo -e "  ${CYAN}3.${NC} Personalize o agente:"
echo -e "     ${BOLD}nano ${WS}/SOUL.md${NC}    ← quem é o agente"
echo -e "     ${BOLD}nano ${WS}/USER.md${NC}    ← quem é você"
echo -e "     ${BOLD}nano ${WS}/AGENTS.md${NC}  ← regras operacionais"
echo ""
echo -e "  ${CYAN}4.${NC} Inicie o gateway:"
echo -e "     ${BOLD}openclaw gateway start${NC}"
echo ""
echo -e "${BOLD}Memory sync:${NC} a cada 15min (crontab já configurado)"
echo -e "${BOLD}PostgreSQL:${NC} agent_memory em localhost:5432"
echo -e "${BOLD}Workspace:${NC} ${WS}"
echo ""
echo "🤘 Seu agente tá pronto. Só precisa de uma API key."
