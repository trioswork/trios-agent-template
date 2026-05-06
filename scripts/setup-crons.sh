#!/bin/bash
# ============================================================
# Configurar Crons Essenciais
# Rodar DEPOIS do gateway estar rodando
# ============================================================
set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Configurando crons essenciais...${NC}"
echo ""

# Verificar se gateway tá rodando
if ! pgrep -f "openclaw" > /dev/null; then
    echo -e "${YELLOW}⚠️ Gateway não parece estar rodando. Rode 'openclaw gateway start' primeiro.${NC}"
    exit 1
fi

# Os crons são criados via OpenClaw CLI ou API
# Este script gera o arquivo de configuração que o agente pode usar

WORKSPACE="/root/.openclaw/workspace"

cat > "$WORKSPACE/memory/crons-config.md" << 'EOF'
# Crons Essenciais — Configurar no OpenClaw

Use `/cron add` ou a API pra criar estes crons:

## 1. Memory Sync (a cada 15 min)
- Nome: memory-sync-postgres
- Schedule: every 15min
- Payload: Rode `python3 /root/.openclaw/workspace/scripts/memory-to-postgres.py`
- Delivery: none

## 2. Backup GitHub (a cada 4h)
- Nome: backup-github
- Schedule: cron 0 */4 * * *
- Payload: Rode `bash /root/.openclaw/workspace/scripts/backup-to-github.sh`
- Delivery: none

## 3. Health Monitor (a cada 20 min)
- Nome: gateway-health-monitor
- Schedule: every 20min
- Payload: Verifique `systemctl --user status openclaw-gateway.service`. Se problema, alerte.
- Delivery: announce

## 4. Consolidação de Memória (3h)
- Nome: memory-consolidation
- Schedule: cron 0 */3 * * *
- Payload: Rode `python3 /root/.openclaw/workspace/scripts/memory-sync.py --agent-id main`
- Delivery: none
EOF

echo -e "${GREEN}  ✅ Config de crons salva em memory/crons-config.md${NC}"
echo ""
echo "  Os crons serão criados automaticamente quando o agente"
echo "  receber a primeira mensagem e ler as instruções."
echo ""
echo -e "${GREEN}  🤘 Pronto!${NC}"
