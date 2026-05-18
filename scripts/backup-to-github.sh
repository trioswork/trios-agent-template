#!/bin/bash
# Backup do banco PostgreSQL + .md essenciais pro GitHub
# Roda a cada 4 horas via cron (minuto 5). Há também um dump diário separado no crontab.

set -e

WORKSPACE="/root/.openclaw/workspace"
BACKUP_DIR="$WORKSPACE/backups"
DB_NAME="trios_memory"
DB_USER="trios"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Criar dump do banco
sudo -u postgres pg_dump "$DB_NAME" > "$BACKUP_DIR/trios_memory_${TIMESTAMP}.sql"

# Manter só os últimos 12 dumps .sql não compactados criados por esta rotina
ls -t "$BACKUP_DIR"/trios_memory_*.sql 2>/dev/null | tail -n +13 | xargs -r rm

# Copiar dump mais recente como "latest"
cp "$BACKUP_DIR/trios_memory_${TIMESTAMP}.sql" "$BACKUP_DIR/trios_memory_latest.sql"

# Compactar dump mais recente
gzip -f "$BACKUP_DIR/trios_memory_${TIMESTAMP}.sql"

# Commit e push no GitHub
cd "$WORKSPACE"
git add -A
git commit -m "backup: ${TIMESTAMP} (${DB_NAME})" --allow-empty 2>/dev/null || true
git push origin master 2>/dev/null || true

echo "[$(date)] Backup concluído: ${TIMESTAMP}"
