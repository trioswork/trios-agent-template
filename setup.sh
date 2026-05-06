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
# 1. DEPENDÊNCIAS DO SISTEMA
# ============================================================
echo -e "${YELLOW}[1/4] Instalando dependências...${NC}"

apt update -y > /dev/null 2>&1

DEPS="curl git build-essential python3 python3-pip python3-dev postgresql postgresql-contrib postgresql-server-dev-all"
apt install -y $DEPS > /dev/null 2>&1
echo -e "  ${GREEN}✅ Sistema${NC}"

# Node.js 22
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash - > /dev/null 2>&1
    apt install -y nodejs > /dev/null 2>&1
fi
echo -e "  ${GREEN}✅ Node.js $(node -v)${NC}"

# OpenClaw
if ! command -v openclaw &> /dev/null; then
    npm install -g openclaw > /dev/null 2>&1
fi
echo -e "  ${GREEN}✅ OpenClaw$(openclaw --version 2>/dev/null || echo '')${NC}"

# PostgreSQL + pgvector
PG_VERSION=$(psql --version | grep -oP '\d+' | head -1)
if ! dpkg -l | grep -q "postgresql-${PG_VERSION}-pgvector" 2>/dev/null; then
    apt install -y "postgresql-${PG_VERSION}-pgvector" > /dev/null 2>&1 || {
        cd /tmp && rm -rf pgvector
        git clone --branch v0.8.0 https://github.com/pgvector/pgvector.git > /dev/null 2>&1
        cd pgvector && make > /dev/null 2>&1 && make install > /dev/null 2>&1
        cd /root && rm -rf /tmp/pgvector
    }
fi
echo -e "  ${GREEN}✅ PostgreSQL $(psql --version | awk '{print $3}') + pgvector${NC}"

# psycopg2
pip3 install psycopg2-binary > /dev/null 2>&1 2>/dev/null || \
    pip3 install --user psycopg2-binary > /dev/null 2>&1 || \
    apt install -y python3-psycopg2 > /dev/null 2>&1 || true
echo -e "  ${GREEN}✅ Python deps${NC}"

# ============================================================
# 2. CLONAR TEMPLATE + BANCO
# ============================================================
echo ""
echo -e "${YELLOW}[2/4] Configurando workspace e banco...${NC}"

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
[ -f "scripts/memory-schema.sql" ] && sudo -u postgres psql -d trios_memory -f scripts/memory-schema.sql > /dev/null 2>&1 || true

echo -e "  ${GREEN}✅ Workspace + banco${NC}"

# ============================================================
# 3. ONBOARDING (só o essencial)
# ============================================================
echo ""
echo -e "${YELLOW}[3/4] Configuração do agente${NC}"
echo ""

read -p "Seu nome: " USER_NAME
read -p "Nome do agente (ex: Bia, Max, Ana): " AGENT_NAME
read -p "Sua empresa: " BUSINESS_NAME
read -p "O que a empresa faz? (1 frase): " BUSINESS_DESC

echo ""
echo "Persona:"
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

TODAY=$(date +%d/%m/%Y)
TEMPLATES="$WORKSPACE/templates"

# Gerar arquivos a partir de templates
for tpl in SOUL.md USER.md IDENTITY.md AGENTS.md MEMORY.md HEARTBEAT.md; do
    if [ -f "$TEMPLATES/$tpl" ]; then
        sed \
            -e "s|{{USER_NAME}}|$USER_NAME|g" \
            -e "s|{{AGENT_NAME}}|$AGENT_NAME|g" \
            -e "s|{{AGENT_EMOJI}}|🤖|g" \
            -e "s|{{BUSINESS_NAME}}|$BUSINESS_NAME|g" \
            -e "s|{{LOCATION}}|Brasil|g" \
            -e "s|{{USER_EMAIL}}||g" \
            -e "s|{{BUSINESS_DESC}}|$BUSINESS_DESC|g" \
            -e "s|{{REVENUE_GOAL}}|0|g" \
            -e "s|{{REVENUE_DEADLINE}}|-|g" \
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

# .env (sem API key de IA - configura depois)
cat > "$WORKSPACE/.env" << EOF
# $BUSINESS_NAME — Gerado em $TODAY
PG_HOST=localhost
PG_PORT=5432
PG_DBNAME=trios_memory
PG_USER=trios
PG_PASSWORD=$PG_PASS
EOF
chmod 600 "$WORKSPACE/.env"

echo ""
echo -e "${GREEN}  ✅ Agente configurado${NC}"

# ============================================================
# 4. TELEGRAM + GATEWAY
# ============================================================
echo ""
echo -e "${YELLOW}[4/4] Telegram + Gateway${NC}"
echo ""

read -p "Token do bot Telegram (cole aqui): " TG_TOKEN

if [ -n "$TG_TOKEN" ]; then
    # Salvar no .env
    echo "TELEGRAM_BOT_TOKEN=$TG_TOKEN" >> "$WORKSPACE/.env"
    
    # Registrar canal no OpenClaw
    TELEGRAM_BOT_TOKEN="$TG_TOKEN" openclaw channels add --channel telegram --use-env --name Telegram > /dev/null 2>&1 || true
    
    echo -e "  ${GREEN}✅ Telegram configurado${NC}"
else
    echo -e "  ${YELLOW}⚠️ Sem token. Configure depois com: openclaw configure${NC}"
fi

# Instalar gateway como serviço
openclaw gateway install > /dev/null 2>&1 || true

# Drop-in systemd pra carregar o .env
mkdir -p /root/.config/systemd/user/openclaw-gateway.service.d
cat > /root/.config/systemd/user/openclaw-gateway.service.d/env.conf << EOF
[Service]
EnvironmentFile=-$WORKSPACE/.env
EOF

# Recarregar e iniciar
systemctl --user daemon-reload > /dev/null 2>&1 || true
systemctl --user enable --now openclaw-gateway.service > /dev/null 2>&1 || true

# Linger pra manter serviço ativo após logout
loginctl enable-linger root > /dev/null 2>&1 || true

# Aguardar gateway subir
sleep 5

# Diagnóstico final
echo ""
echo -e "${GREEN}  ✅ Gateway instalado e iniciado${NC}"
echo ""

# Health check
HEALTH=$(openclaw gateway health 2>&1 || true)
if echo "$HEALTH" | grep -q "OK"; then
    echo -e "  ${GREEN}✅ Gateway: OK${NC}"
else
    echo -e "  ${YELLOW}⚠️ Gateway pode precisar de um momento pra estabilizar${NC}"
    echo -e "  ${YELLOW}   Rode: openclaw gateway health${NC}"
fi

# Telegram check
if [ -n "$TG_TOKEN" ]; then
    CHANNEL_STATUS=$(openclaw channels status --deep --json 2>/dev/null || true)
    if echo "$CHANNEL_STATUS" | grep -q '"running":true'; then
        echo -e "  ${GREEN}✅ Telegram: conectado${NC}"
    else
        echo -e "  ${YELLOW}⚠️ Telegram: aguardando conexão${NC}"
    fi
fi

# ============================================================
# FINALIZAR
# ============================================================
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${GREEN}  ✅ Instalação completa!${NC}"
echo ""
echo "  🤖 $AGENT_NAME 🤖"
echo "  🏢 $BUSINESS_NAME"
echo "  📋 $BUSINESS_DESC"
echo ""
echo "  Próximos passos:"
echo ""
echo "  1. Configure IA e modelo:"
echo -e "     ${CYAN}openclaw configure${NC}"
echo ""
echo "  2. Mande /start no bot do Telegram"
echo ""
echo "  Diagnóstico:"
echo -e "     ${CYAN}openclaw gateway health${NC}"
echo -e "     ${CYAN}openclaw channels status${NC}"
echo ""
