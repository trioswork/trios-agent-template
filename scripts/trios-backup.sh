#!/bin/bash
# Backup completo do Trios Work
# Uso: ./trios-backup.sh [--restore arquivo.tar.gz]

set -e

BACKUP_DIR="/root/.openclaw/backups"
TIMESTAMP=$(date +%Y-%m-%d_%H%M%S)
BACKUP_FILE="trios-backup-${TIMESTAMP}.tar.gz"
OPENCLAW_DIR="/root/.openclaw"

mkdir -p "$BACKUP_DIR"

if [ "$1" = "--restore" ]; then
    if [ -z "$2" ]; then
        echo "Uso: $0 --restore arquivo.tar.gz"
        exit 1
    fi
    RESTORE_FILE="$2"
    if [ ! -f "$RESTORE_FILE" ]; then
        echo "Arquivo não encontrado: $RESTORE_FILE"
        exit 1
    fi
    echo "Restaurando backup..."
    echo "AVISO: Isso vai sobrescrever configurações atuais!"
    read -p "Continuar? (s/N): " confirm
    if [ "$confirm" != "s" ]; then
        echo "Cancelado."
        exit 0
    fi
    cd /
    tar -xzf "$RESTORE_FILE"
    echo "Backup restaurado! Reinicie o gateway: openclaw gateway restart"
    exit 0
fi

echo "Criando backup do Trios Work..."
echo "Data: $(date)"
echo ""

# Criar backup
cd "$OPENCLAW_DIR"
tar -czf "${BACKUP_DIR}/${BACKUP_FILE}" \
    --exclude='node_modules' \
    --exclude='.git' \
    --exclude='backups' \
    --exclude='media/inbound' \
    --exclude='*.db-wal' \
    --exclude='*.db-shm' \
    openclaw.json \
    workspace/ \
    workspace-sdr/ \
    memory/ \
    agents/ \
    credentials/ \
    2>/dev/null || true

# Verificar tamanho
SIZE=$(du -h "${BACKUP_DIR}/${BACKUP_FILE}" | cut -f1)
echo "Backup criado: ${BACKUP_DIR}/${BACKUP_FILE} (${SIZE})"
echo ""
echo "Para restaurar: ./trios-backup.sh --restore ${BACKUP_FILE}"
echo "Ou: tar -xzf ${BACKUP_FILE} -C /root/.openclaw/"

# Manter apenas os 5 backups mais recentes
cd "$BACKUP_DIR"
ls -t trios-backup-*.tar.gz 2>/dev/null | tail -n +6 | xargs rm -f 2>/dev/null || true
echo "Backups antigos removidos (mantendo os 5 mais recentes)."
