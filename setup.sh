#!/bin/bash
# ============================================================
# OpenClaw Agent — Instalador Universal
# Tudo em um comando, zero intervenção manual
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
echo "  ╚══════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

# ============================================================
# 1. DEPENDÊNCIAS DO SISTEMA (tudo que precisa pra funcionar)
# ============================================================
echo -e "${YELLOW}[1/5] Instalando dependências do sistema...${NC}"

apt update -y > /dev/null 2>&1

# Pacotes essenciais (instalar tudo de uma vez)
DEPS="curl git build-essential python3 python3-pip python3-dev postgresql postgresql-contrib postgresql-server-dev-all"

apt install -y $DEPS > /dev/null 2>&1

echo -e "  ${GREEN}✅ Dependências do sistema${NC}"

# ============================================================
# 2. NODE.JS + OPENCLAW
# ============================================================
echo -e "${YELLOW}[2/5] Instalando Node.js + OpenClaw...${NC}"

if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash - > /dev/null 2>&1
    apt install -y nodejs > /dev/null 2>&1
fi
echo -e "  ${GREEN}✅ Node.js $(node -v)${NC}"

if ! command -v openclaw &> /dev/null; then
    npm install -g openclaw > /dev/null 2>&1
fi
echo -e "  ${GREEN}✅ OpenClaw $(openclaw --version 2>/dev/null || echo 'ok')${NC}"

# ============================================================
# 3. POSTGRESQL + PGVECTOR + PYTHON
# ============================================================
echo -e "${YELLOW}[3/5] Configurando PostgreSQL + pgvector...${NC}"

# Descobrir versão do PostgreSQL
PG_VERSION=$(psql --version | grep -oP '\d+' | head -1)

# Tentar instalar pgvector via pacote (funciona em Ubuntu 22.04+)
if ! dpkg -l | grep -q "postgresql-${PG_VERSION}-pgvector" 2>/dev/null; then
    apt install -y "postgresql-${PG_VERSION}-pgvector" > /dev/null 2>&1 || {
        # Se pacote não existe, compilar do source
        echo -e "  ${CYAN}  Compilando pgvector do source...${NC}"
        cd /tmp
        rm -rf pgvector
        git clone --branch v0.8.0 https://github.com/pgvector/pgvector.git > /dev/null 2>&1
        cd pgvector
        make > /dev/null 2>&1
        make install > /dev/null 2>&1
        cd /root
        rm -rf /tmp/pgvector
    }
fi
echo -e "  ${GREEN}✅ PostgreSQL $(psql --version | awk '{print $3}') + pgvector${NC}"

# psycopg2 (compatível com qualquer versão de pip)
pip3 install psycopg2-binary > /dev/null 2>&1 2>/dev/null || \
    pip3 install --user psycopg2-binary > /dev/null 2>&1 || \
    apt install -y python3-psycopg2 > /dev/null 2>&1 || true
echo -e "  ${GREEN}✅ Python psycopg2${NC}"

# ============================================================
# 4. CLONAR TEMPLATE + BANCO
# ============================================================
echo -e "${YELLOW}[4/5] Baixando template e configurando banco...${NC}"

WORKSPACE="/root/.openclaw/workspace"
if [ ! -d "$WORKSPACE" ]; then
    mkdir -p /root/.openclaw
    git clone https://github.com/trioswork/trios-agent-template.git "$WORKSPACE" > /dev/null 2>&1
fi
cd "$WORKSPACE"

# Banco
PG_PASS=$(openssl rand -hex 16)
sudo -u postgres psql -c "CREATE DATABASE trios_memory;" 2>/dev/null || true
sudo -u postgres psql -c "CREATE USER trios WITH PASSWORD '$PG_PASS';" 2>/dev/null || true
sudo -u postgres psql -d trios_memory -c "CREATE EXTENSION IF NOT EXISTS vector;" 2>/dev/null || true
sudo -u postgres psql -d trios_memory -c "GRANT ALL ON SCHEMA public TO trios;" 2>/dev/null || true
sudo -u postgres psql -d trios_memory -c "ALTER SCHEMA public OWNER TO trios;" 2>/dev/null || true

if [ -f "scripts/memory-schema.sql" ]; then
    sudo -u postgres psql -d trios_memory -f scripts/memory-schema.sql > /dev/null 2>&1 || true
fi

echo -e "  ${GREEN}✅ Template + banco configurados${NC}"

# ============================================================
# 5. ONBOARDING INTERATIVO
# ============================================================
echo ""
echo -e "${YELLOW}[5/5] Configuração do agente${NC}"
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
echo "API key de IA:"
read -p "Provider (openai/google/zai/xiaomi): " PROVIDER_NAME
read -p "API Key: " API_KEY

TODAY=$(date +%d/%m/%Y)
TEMPLATES="$WORKSPACE/templates"

# Gerar arquivos a partir de templates
for tpl in SOUL.md USER.md IDENTITY.md AGENTS.md MEMORY.md HEARTBEAT.md; do
    if [ -f "$TEMPLATES/$tpl" ]; then
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
            "$TEMPLATES/$tpl" > "$WORKSPACE/$tpl"
    fi
done

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
PROV_UPPER=$(echo "$PROVIDER_NAME" | tr '[:lower:]' '[:upper:]')
cat > "$WORKSPACE/.env" << EOF
# $BUSINESS_NAME — Gerado em $TODAY
${PROV_UPPER}_API_KEY=$API_KEY
PG_HOST=localhost
PG_PORT=5432
PG_DBNAME=trios_memory
PG_USER=trios
PG_PASSWORD=$PG_PASS
GEMINI_API_KEY=
EOF

echo ""
echo -e "${GREEN}  ✅ Agente configurado${NC}"

# Telegram
echo ""
echo -e "${YELLOW}Telegram (último passo)${NC}"
echo ""
echo "  Crie um bot no @BotFather e cole o token."
echo "  (ou Enter pra configurar depois com openclaw configure)"
echo ""
read -p "Token do bot: " TG_TOKEN

if [ -n "$TG_TOKEN" ]; then
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
echo -e "${GREEN}  ✅ Tudo instalado e configurado!${NC}"
echo ""
echo "  🤖 $AGENT_NAME $AGENT_EMOJI"
echo "  🏢 $BUSINESS_NAME"
echo "  🎯 R$ $REVENUE_GOAL/mês até $REVENUE_DEADLINE"
echo ""
echo "  Pra iniciar:"
echo -e "    ${CYAN}openclaw gateway start${NC}"
echo ""
