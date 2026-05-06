#!/bin/bash
# ============================================================
# Trios Agent — Setup Completo
# Uso: bash setup.sh
# Um único comando: instala tudo + onboarding + Telegram
# ============================================================
set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

clear
echo -e "${CYAN}"
echo "  ╔══════════════════════════════════════════╗"
echo "  ║   🤘 Trios Agent — Setup Completo        ║"
echo "  ║   Instalação + Onboarding + Telegram      ║"
echo "  ╚══════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

# ============================================================
# 1. INSTALAR INFRAESTRUTURA
# ============================================================
echo -e "${YELLOW}━━━ 1/4 INFRAESTRUTURA ━━━${NC}"
echo ""

# 1a. Sistema
echo "  Atualizando sistema..."
apt update && apt upgrade -y > /dev/null 2>&1

# 1b. Node.js 22
echo "  Instalando Node.js 22..."
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash - > /dev/null 2>&1
    apt install -y nodejs > /dev/null 2>&1
fi
echo -e "  ${GREEN}Node.js $(node -v)${NC}"

# 1c. PostgreSQL + pgvector
echo "  Instalando PostgreSQL + pgvector..."
if ! command -v psql &> /dev/null; then
    apt install -y postgresql postgresql-contrib > /dev/null 2>&1
fi
PG_VERSION=$(psql --version | grep -oP '\d+' | head -1)
apt install -y postgresql-${PG_VERSION}-pgvector > /dev/null 2>&1 || true
echo -e "  ${GREEN}PostgreSQL $(psql --version | awk '{print $3}')${NC}"

# 1d. Python deps
echo "  Dependências Python..."
pip3 install psycopg2-binary --break-system-packages > /dev/null 2>&1 || pip3 install psycopg2-binary > /dev/null 2>&1

# 1e. OpenClaw
echo "  Instalando OpenClaw..."
if ! command -v openclaw &> /dev/null; then
    npm install -g openclaw > /dev/null 2>&1
fi
echo -e "  ${GREEN}OpenClaw $(openclaw --version 2>/dev/null || echo 'ok')${NC}"

echo ""
echo -e "${GREEN}  ✅ Infraestrutura pronta${NC}"
echo ""

# ============================================================
# 2. CONFIGURAR BANCO DE DADOS
# ============================================================
echo -e "${YELLOW}━━━ 2/4 BANCO DE DADOS ━━━${NC}"
echo ""

# Gerar senha aleatória
PG_PASS=$(openssl rand -hex 16)

# Criar banco e usuário
sudo -u postgres psql -c "CREATE DATABASE trios_memory;" 2>/dev/null || true
sudo -u postgres psql -c "CREATE USER trios WITH PASSWORD '$PG_PASS';" 2>/dev/null || true
sudo -u postgres psql -d trios_memory -c "CREATE EXTENSION IF NOT EXISTS vector;" 2>/dev/null || true
sudo -u postgres psql -d trios_memory -c "GRANT ALL ON SCHEMA public TO trios;" 2>/dev/null || true
sudo -u postgres psql -d trios_memory -c "ALTER SCHEMA public OWNER TO trios;" 2>/dev/null || true

echo -e "  ${GREEN}Banco 'trios_memory' criado${NC}"
echo -e "  ${CYAN}Senha PG: $PG_PASS${NC} (anote!)"
echo ""

# ============================================================
# 3. CLONAR WORKSPACE + SCHEMA
# ============================================================
echo -e "${YELLOW}━━━ 3/4 WORKSPACE ━━━${NC}"
echo ""

WORKSPACE="/root/.openclaw/workspace"
if [ ! -d "$WORKSPACE" ]; then
    mkdir -p /root/.openclaw
    cd /root/.openclaw
    git clone https://github.com/trioswork/trios-agent-template.git workspace
fi
cd "$WORKSPACE"

# Rodar schema
if [ -f "scripts/memory-schema.sql" ]; then
    sudo -u postgres psql -d trios_memory -f scripts/memory-schema.sql > /dev/null 2>&1 || true
    echo -e "  ${GREEN}Schema aplicado${NC}"
fi

# Criar .env se não existe
if [ ! -f ".env" ]; then
    cat > .env << EOF
# Gerado pelo setup em $(date +%d/%m/%Y)

# PostgreSQL
PG_HOST=localhost
PG_PORT=5432
PG_DBNAME=trios_memory
PG_USER=trios
PG_PASSWORD=$PG_PASS

# IA (preencher)
OPENAI_API_KEY=
GEMINI_API_KEY=

# Telegram (preencher com /start do bot)
TELEGRAM_BOT_TOKEN=
EOF
    echo -e "  ${GREEN}.env criado${NC}"
else
    # Atualizar senha PG no .env existente
    sed -i "s/^PG_PASSWORD=.*/PG_PASSWORD=$PG_PASS/" .env
    echo -e "  ${GREEN}.env atualizado com senha PG${NC}"
fi

echo ""

# ============================================================
# 4. ONBOARDING
# ============================================================
echo -e "${YELLOW}━━━ 4/4 ONBOARDING ━━━${NC}"
echo ""
echo "  Vou abrir o wizard de configuração."
echo "  Ele pergunta: nome, empresa, clientes, persona."
echo ""
read -p "  Pressione ENTER pra começar..."

# Copiar templates genéricos como arquivos finais
if [ -d "$WORKSPACE/templates" ]; then
    echo -e "  ${GREEN}Templates encontrados${NC}"
fi

bash onboarding.sh

# ============================================================
# FINALIZAR
# ============================================================
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${GREEN}  ✅ Tudo instalado e configurado!${NC}"
echo ""
echo "  Próximos passos:"
echo ""
echo "  1. Preencha as API keys no .env:"
echo -e "     ${CYAN}nano /root/.openclaw/workspace/.env${NC}"
echo ""
echo "  2. Configure o Telegram:"
echo -e "     ${CYAN}openclaw configure${NC}"
echo "     (segue o wizard pra conectar o bot)"
echo ""
echo "  3. Inicie o gateway:"
echo -e "     ${CYAN}openclaw gateway start${NC}"
echo ""
echo -e "  🤘 Pronto pra trabalhar!"
echo ""
