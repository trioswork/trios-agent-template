#!/bin/bash
# ============================================================
# Instalador Universal — OpenClaw Agent
# Uso: bash <(curl -s https://raw.githubusercontent.com/trioswork/trios-agent-template/master/setup.sh)
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
echo "  ║   🤖 OpenClaw Agent — Instalador Único   ║"
echo "  ║   Tudo automático em um comando           ║"
echo "  ╚══════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

# ============================================================
# 1. INSTALAR INFRAESTRUTURA
# ============================================================
echo -e "${YELLOW}[1/5] Instalando infraestrutura...${NC}"

apt update > /dev/null 2>&1
apt upgrade -y > /dev/null 2>&1

# Node.js 22
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash - > /dev/null 2>&1
    apt install -y nodejs > /dev/null 2>&1
fi
echo -e "  ${GREEN}✅ Node.js $(node -v)${NC}"

# PostgreSQL + pgvector
if ! command -v psql &> /dev/null; then
    apt install -y postgresql postgresql-contrib > /dev/null 2>&1
fi
PG_VERSION=$(psql --version | grep -oP '\d+' | head -1)
apt install -y postgresql-${PG_VERSION}-pgvector > /dev/null 2>&1 || true
echo -e "  ${GREEN}✅ PostgreSQL $(psql --version | awk '{print $3}')${NC}"

# Python deps
pip3 install psycopg2-binary --break-system-packages > /dev/null 2>&1 || pip3 install psycopg2-binary > /dev/null 2>&1
echo -e "  ${GREEN}✅ Python deps${NC}"

# OpenClaw
if ! command -v openclaw &> /dev/null; then
    npm install -g openclaw > /dev/null 2>&1
fi
echo -e "  ${GREEN}✅ OpenClaw $(openclaw --version 2>/dev/null || echo 'ok')${NC}"

# ============================================================
# 2. CLONAR TEMPLATE
# ============================================================
echo ""
echo -e "${YELLOW}[2/5] Baixando template...${NC}"

WORKSPACE="/root/.openclaw/workspace"
if [ ! -d "$WORKSPACE" ]; then
    mkdir -p /root/.openclaw
    git clone https://github.com/trioswork/trios-agent-template.git "$WORKSPACE" > /dev/null 2>&1
fi
cd "$WORKSPACE"
echo -e "  ${GREEN}✅ Template baixado${NC}"

# ============================================================
# 3. CONFIGURAR BANCO
# ============================================================
echo ""
echo -e "${YELLOW}[3/5] Configurando banco de dados...${NC}"

PG_PASS=$(openssl rand -hex 16)

sudo -u postgres psql -c "CREATE DATABASE trios_memory;" 2>/dev/null || true
sudo -u postgres psql -c "CREATE USER trios WITH PASSWORD '$PG_PASS';" 2>/dev/null || true
sudo -u postgres psql -d trios_memory -c "CREATE EXTENSION IF NOT EXISTS vector;" 2>/dev/null || true
sudo -u postgres psql -d trios_memory -c "GRANT ALL ON SCHEMA public TO trios;" 2>/dev/null || true
sudo -u postgres psql -d trios_memory -c "ALTER SCHEMA public OWNER TO trios;" 2>/dev/null || true

if [ -f "scripts/memory-schema.sql" ]; then
    sudo -u postgres psql -d trios_memory -f scripts/memory-schema.sql > /dev/null 2>&1 || true
fi

echo -e "  ${GREEN}✅ Banco configurado${NC}"
echo -e "  ${CYAN}Senha PG: $PG_PASS${NC} (anote!)"

# ============================================================
# 4. ONBOARDING
# ============================================================
echo ""
echo -e "${YELLOW}[4/5] Configuração do agente${NC}"
echo ""

read -p "Seu nome: " USER_NAME
read -p "Nome do agente (ex: Ana, Max, Bia): " AGENT_NAME
read -p "Emoji do agente (ex: 🤖, 🦾, 💪): " AGENT_EMOJI
read -p "Sua empresa: " BUSINESS_NAME
read -p "Cidade/Estado: " LOCATION
read -p "Seu email: " USER_EMAIL
read -p "O que a empresa faz? (1 frase): " BUSINESS_DESC
read -p "Meta mensal R$ (ex: 30000): " REVENUE_GOAL
read -p "Prazo (ex: 2026-06): " REVENUE_DEADLINE

echo ""
echo "Persona do agente:"
echo "  1) Formal e profissional"
echo "  2) Informal e direto"
echo "  3) Amigável e consultivo"
echo "  4) Técnico e objetivo"
read -p "Escolha (1-4): " PERSONA_CHOICE

case $PERSONA_CHOICE in
    1) TONE="profissional, respeitoso, estruturado" ;;
    2) TONE="direto, sem enrolação, como um amigo" ;;
    3) TONE="amigável, orientador, empático" ;;
    4) TONE="objetivo, técnico, focado em resultados" ;;
    *) TONE="direto e amigável" ;;
esac

echo ""
echo "API key de IA (OpenAI, Google, Z.ai ou Xiaomi):"
read -p "Provider (openai/google/zai/xiaomi): " PROVIDER_NAME
read -p "API Key: " API_KEY

# Gerar arquivos
TODAY=$(date +%d/%m/%Y)
TEMPLATES="$WORKSPACE/templates"

generate_from_template() {
    sed \
        -e "s|{{USER_NAME}}|$USER_NAME|g" \
        -e "s|{{AGENT_NAME}}|$AGENT_NAME|g" \
        -e "s|{{AGENT_EMOJI}}|$AGENT_EMOJI|g" \
        -e "s|{{BUSINESS_NAME}}|$BUSINESS_NAME|g" \
        -e "s|{{LOCATION}}|$LOCATION|g" \
        -e "s|{{USER_EMAIL}}|$USER_EMAIL|g" \
        -e "s|{{BUSINESS_DESC}}|$BUSINESS_DESC|g" \
        -e "s|{{REVENUE_GOAL}}|$REVENUE_GOAL|g" \
        -e "s|{{REVENUE_DEADLINE}}|$REVENUE_DEADLINE|g" \
        -e "s|{{AVG_TICKET}}|0|g" \
        -e "s|{{TONE}}|$TONE|g" \
        -e "s|{{DATE}}|$TODAY|g" \
        "$1" > "$2"
}

generate_from_template "$TEMPLATES/SOUL.md" "$WORKSPACE/SOUL.md"
generate_from_template "$TEMPLATES/USER.md" "$WORKSPACE/USER.md"
generate_from_template "$TEMPLATES/IDENTITY.md" "$WORKSPACE/IDENTITY.md"
generate_from_template "$TEMPLATES/AGENTS.md" "$WORKSPACE/AGENTS.md"
generate_from_template "$TEMPLATES/MEMORY.md" "$WORKSPACE/MEMORY.md"
generate_from_template "$TEMPLATES/HEARTBEAT.md" "$WORKSPACE/HEARTBEAT.md"

# Estrutura de memória
mkdir -p "$WORKSPACE/memory"/{context,projects,sessions,integrations,feedback}
mkdir -p "$WORKSPACE/backups"
echo "# Decisões Permanentes" > "$WORKSPACE/memory/context/decisions.md"
echo "" > "$WORKSPACE/memory/context/lessons.md"
echo "# Pessoas e Contatos" > "$WORKSPACE/memory/context/people.md"
echo "# Contexto do Negócio" > "$WORKSPACE/memory/context/business-context.md"
echo "# Tarefas Pendentes" > "$WORKSPACE/memory/pending.md"
echo "[]" > "$WORKSPACE/memory/heartbeat-state.json"

# .env
cat > "$WORKSPACE/.env" << EOF
# $BUSINESS_NAME — Gerado em $TODAY
${PROVIDER_NAME^^}_API_KEY=$API_KEY
PG_HOST=localhost
PG_PORT=5432
PG_DBNAME=trios_memory
PG_USER=trios
PG_PASSWORD=$PG_PASS
GEMINI_API_KEY=
EOF

echo -e "  ${GREEN}✅ Agente configurado${NC}"

# ============================================================
# 5. TELEGRAM
# ============================================================
echo ""
echo -e "${YELLOW}[5/5] Conectar Telegram${NC}"
echo ""
echo "  Crie um bot no @BotFather e cole o token abaixo."
echo "  (ou Enter pra configurar depois)"
echo ""
read -p "Token do bot: " TG_TOKEN

if [ -n "$TG_TOKEN" ]; then
    # Salvar token no .env
    echo "TELEGRAM_BOT_TOKEN=$TG_TOKEN" >> "$WORKSPACE/.env"
    echo -e "  ${GREEN}✅ Telegram configurado${NC}"
else
    echo -e "  ${YELLOW}⚠️ Configure depois: openclaw configure${NC}"
fi

# ============================================================
# FINALIZAR
# ============================================================
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${GREEN}  ✅ Instalação concluída!${NC}"
echo ""
echo "  🤖 Agente: $AGENT_NAME $AGENT_EMOJI"
echo "  🏢 Empresa: $BUSINESS_NAME"
echo "  🎯 Meta: R$ $REVENUE_GOAL/mês"
echo ""
echo "  Pra iniciar:"
echo -e "    ${CYAN}openclaw gateway start${NC}"
echo ""
echo "  🤖 $AGENT_NAME tá pronto pra trabalhar!"
echo ""
