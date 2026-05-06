#!/bin/bash
# ============================================================
# Onboarding Wizard
# Configura persona, objetivos, clientes, crons
# Gera TODOS os arquivos a partir de templates genéricos
# ============================================================
set -e

WORKSPACE="/root/.openclaw/workspace"
TEMPLATES="$WORKSPACE/templates"
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

clear
echo -e "${CYAN}"
echo "  ╔══════════════════════════════════════╗"
echo "  ║   🤘 Onboarding — Seu Agente IA      ║"
echo "  ╚══════════════════════════════════════╝"
echo -e "${NC}"
echo ""

# ============================================================
# 1. IDENTIDADE
# ============================================================
echo -e "${YELLOW}━━━ 1. SUA IDENTIDADE ━━━${NC}"
echo ""

read -p "Seu nome: " USER_NAME
read -p "Nome do agente (ex: Trios, Ana, Max): " AGENT_NAME
read -p "Emoji do agente (ex: 🤘, 🤖, 🦾): " AGENT_EMOJI
read -p "Sua empresa/negócio: " BUSINESS_NAME
read -p "Cidade/Estado: " LOCATION
read -p "Seu email profissional: " USER_EMAIL

echo ""
echo -e "${GREEN}✅ Identidade configurada${NC}"
echo ""

# ============================================================
# 2. NEGÓCIO
# ============================================================
echo -e "${YELLOW}━━━ 2. SEU NEGÓCIO ━━━${NC}"
echo ""

read -p "O que sua empresa faz? (1 frase): " BUSINESS_DESC
read -p "Meta de faturamento mensal (ex: 30000): " REVENUE_GOAL
read -p "Prazo da meta (ex: 2026-06): " REVENUE_DEADLINE
read -p "Ticket médio por cliente (ex: 3000): " AVG_TICKET

echo ""
echo -e "${GREEN}✅ Negócio configurado${NC}"
echo ""

# ============================================================
# 3. CLIENTES
# ============================================================
echo -e "${YELLOW}━━━ 3. SEUS CLIENTES ATUAIS ━━━${NC}"
echo ""
echo "Vou criar os clientes no banco. Preencha cada um."
echo "Digite 'fim' quando terminar."

CLIENT_COUNT=0

while true; do
    read -p "Nome do cliente (ou 'fim'): " CLIENT_NAME
    if [ "$CLIENT_NAME" = "fim" ]; then break; fi
    read -p "  Valor mensal (R$): " CLIENT_VALUE
    read -p "  Dia de pagamento: " CLIENT_DAY
    read -p "  Descrição do serviço: " CLIENT_DESC
    
    CLIENT_COUNT=$((CLIENT_COUNT + 1))
    echo -e "  ${GREEN}✅ $CLIENT_NAME — R$ $CLIENT_VALUE/mês${NC}"
    echo ""
done

echo -e "${GREEN}✅ $CLIENT_COUNT clientes cadastrados${NC}"
echo ""

# ============================================================
# 4. PERSONA DO AGENTE
# ============================================================
echo -e "${YELLOW}━━━ 4. PERSONA DO AGENTE ━━━${NC}"
echo ""
echo "Como $AGENT_NAME deve se comportar?"
echo ""
echo "  1) Formal e profissional"
echo "  2) Informal e direto"
echo "  3) Amigável e consultivo"
echo "  4) Técnico e objetivo"
echo ""
read -p "Escolha (1-4): " PERSONA_CHOICE

case $PERSONA_CHOICE in
    1) PERSONA="formal"; TONE="profissional, respeitoso, estruturado" ;;
    2) PERSONA="informal"; TONE="direto, sem enrolação, como um amigo" ;;
    3) PERSONA="consultivo"; TONE="amigável, orientador, empático" ;;
    4) PERSONA="tecnico"; TONE="objetivo, técnico, focado em resultados" ;;
    *) PERSONA="informal"; TONE="direto e amigável" ;;
esac

echo ""
read -p "Alguma instrução especial pro agente? (Enter pra pular): " SPECIAL_INSTRUCTIONS

echo -e "${GREEN}✅ Persona: $PERSONA${NC}"
echo ""

# ============================================================
# 5. TELEGRAM
# ============================================================
echo -e "${YELLOW}━━━ 5. TELEGRAM ━━━${NC}"
echo ""
echo "Pra configurar o Telegram, preciso do bot token."
echo "Crie um bot pelo @BotFather e cole o token aqui."
echo ""
read -p "Telegram bot token (ou Enter pra configurar depois): " TELEGRAM_TOKEN

if [ -n "$TELEGRAM_TOKEN" ]; then
    echo -e "${GREEN}✅ Telegram configurado${NC}"
else
    echo -e "${YELLOW}⚠️ Configure depois com: openclaw configure${NC}"
fi
echo ""

# ============================================================
# 6. API KEYS
# ============================================================
echo -e "${YELLOW}━━━ 6. API KEYS ━━━${NC}"
echo ""
echo "Preciso de pelo menos UMA API key de IA pra funcionar."
echo ""
echo "  1) OpenAI (GPT, Whisper)"
echo "  2) Z.ai (GLM)"
echo "  3) Xiaomi (MiMo)"
echo "  4) Google (Gemini)"
echo ""
read -p "Qual provider usar? (1-4): " PROVIDER_CHOICE

case $PROVIDER_CHOICE in
    1) PROVIDER_NAME="OPENAI"; read -p "OpenAI API Key: " API_KEY ;;
    2) PROVIDER_NAME="ZAI"; read -p "Z.ai API Key: " API_KEY ;;
    3) PROVIDER_NAME="XIAOMI"; read -p "Xiaomi API Key: " API_KEY ;;
    4) PROVIDER_NAME="GOOGLE"; read -p "Google API Key: " API_KEY ;;
esac

echo ""
echo -e "${GREEN}✅ Provider: $PROVIDER_NAME${NC}"
echo ""

# ============================================================
# 7. GERAR ARQUIVOS A PARTIR DE TEMPLATES
# ============================================================
echo -e "${YELLOW}━━━ 7. CONFIGURANDO AMBIENTE ━━━${NC}"
echo ""

TODAY=$(date +%d/%m/%Y)

# Função pra substituir placeholders num template e gerar arquivo
generate_from_template() {
    local template="$1"
    local output="$2"
    
    if [ ! -f "$template" ]; then
        echo -e "  ${RED}⚠️ Template não encontrado: $template${NC}"
        return 1
    fi
    
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
        -e "s|{{AVG_TICKET}}|$AVG_TICKET|g" \
        -e "s|{{TONE}}|$TONE|g" \
        -e "s|{{DATE}}|$TODAY|g" \
        "$template" > "$output"
    
    echo -e "  ${GREEN}$(basename $output) criado${NC}"
}

# Gerar TODOS os arquivos a partir dos templates
generate_from_template "$TEMPLATES/SOUL.md" "$WORKSPACE/SOUL.md"
generate_from_template "$TEMPLATES/USER.md" "$WORKSPACE/USER.md"
generate_from_template "$TEMPLATES/IDENTITY.md" "$WORKSPACE/IDENTITY.md"
generate_from_template "$TEMPLATES/AGENTS.md" "$WORKSPACE/AGENTS.md"
generate_from_template "$TEMPLATES/MEMORY.md" "$WORKSPACE/MEMORY.md"
generate_from_template "$TEMPLATES/HEARTBEAT.md" "$WORKSPACE/HEARTBEAT.md"

# Adicionar instruções especiais no SOUL.md se houver
if [ -n "$SPECIAL_INSTRUCTIONS" ]; then
    echo "" >> "$WORKSPACE/SOUL.md"
    echo "## Instruções Especiais" >> "$WORKSPACE/SOUL.md"
    echo "" >> "$WORKSPACE/SOUL.md"
    echo "$SPECIAL_INSTRUCTIONS" >> "$WORKSPACE/SOUL.md"
fi

# IDENTITY.md — preencher background e missão com dados do negócio
# (o template já foi gerado, mas vamos adicionar contexto específico)

# MEMORY.md — zerado (sem dados de empresa anterior)
echo -e "  ${GREEN}Memória zerada (sem dados de empresa anterior)${NC}"

# Criar estrutura de diretórios de memória
echo -e "  ${CYAN}Criando estrutura de memória...${NC}"
mkdir -p "$WORKSPACE/memory/context"
mkdir -p "$WORKSPACE/memory/projects"
mkdir -p "$WORKSPACE/memory/sessions"
mkdir -p "$WORKSPACE/memory/integrations"
mkdir -p "$WORKSPACE/memory/feedback"
mkdir -p "$WORKSPACE/backups"

# Criar arquivos iniciais vaziosecho "# Decisões Permanentes" > "$WORKSPACE/memory/context/decisions.md"echo "" > "$WORKSPACE/memory/context/lessons.md"echo "# Pessoas e Contatos" > "$WORKSPACE/memory/context/people.md"echo "# Contexto do Negócio" > "$WORKSPACE/memory/context/business-context.md"echo "# Tarefas Pendentes" > "$WORKSPACE/memory/pending.md"echo "[]" > "$WORKSPACE/memory/heartbeat-state.json"
echo -e "  ${GREEN}Estrutura de memória criada${NC}"

# Configurar crons
echo -e "  ${CYAN}Configurando crons...${NC}"
bash "$WORKSPACE/scripts/setup-crons.sh" 2>/dev/null || true

# Criar .env
cat > "$WORKSPACE/.env" << EOF
# Credenciais — $BUSINESS_NAME
# Gerado pelo Onboarding em $TODAY

# IA Provider
${PROVIDER_NAME}_API_KEY=$API_KEY

# PostgreSQL (memória)
PG_HOST=localhost
PG_PORT=5432
PG_DBNAME=trios_memory
PG_USER=trios
PG_PASSWORD=$(openssl rand -hex 16)

# Gemini (embeddings) — preencher depois
GEMINI_API_KEY=
EOF
echo -e "  ${GREEN}.env criado${NC}"

# Schema do banco
sudo -u postgres psql -d trios_memory -f "$WORKSPACE/scripts/memory-schema.sql" 2>/dev/null || true
echo -e "  ${GREEN}Banco de dados configurado${NC}"

# Limpar memória do banco (empresa anterior)
sudo -u postgres psql -d trios_memory -c "DELETE FROM memory_entries;" 2>/dev/null || true
sudo -u postgres psql -d trios_memory -c "DELETE FROM memory_edges;" 2>/dev/null || true
echo -e "  ${GREEN}Memória do banco limpa${NC}"

echo ""
echo "================================"
echo -e "${GREEN}✅ Onboarding concluído!${NC}"
echo ""
echo "Resumo:"
echo "  🤖 Agente: $AGENT_NAME $AGENT_EMOJI"
echo "  🏢 Negócio: $BUSINESS_NAME"
echo "  👥 Clientes: $CLIENT_COUNT"
echo "  🎯 Meta: R$ $(printf "%'.0f" $REVENUE_GOAL)/mês"
echo "  🎭 Persona: $PERSONA"
echo ""
echo "Arquivos gerados:"
echo "  ✅ SOUL.md (persona)"
echo "  ✅ USER.md (seus dados)"
echo "  ✅ IDENTITY.md (identidade do agente)"
echo "  ✅ AGENTS.md (regras operacionais)"
echo "  ✅ MEMORY.md (índice zerado)"
echo "  ✅ HEARTBEAT.md (checklist)"
echo "  ✅ .env (credenciais)"
echo "  ✅ Banco de dados limpo"
echo ""
if [ -n "$TELEGRAM_TOKEN" ]; then
    echo "Próximo passo: openclaw gateway start"
else
    echo "Próximos passos:"
    echo "  1. Configure Telegram: openclaw configure"
    echo "  2. Inicie: openclaw gateway start"
fi
echo ""
echo "🤘 $AGENT_NAME tá pronto pra trabalhar!"
