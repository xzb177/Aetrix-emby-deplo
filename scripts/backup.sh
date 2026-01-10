#!/bin/bash
# RoyalBot Emby Portal - Database Backup Script

set -e

# Configuration
BACKUP_DIR="/backups"
RETENTION_DAYS=${BACKUP_RETENTION_DAYS:-7}
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/royalbot_${TIMESTAMP}.sql.gz"

# Colors
GREEN='\033[0;32m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Backup database
log_info "开始备份..."
docker exec royalbot_postgres pg_dump -U royalbot royalbot | gzip > "$BACKUP_FILE"
log_info "备份完成: $BACKUP_FILE"

# Cleanup old backups
log_info "清理 ${RETENTION_DAYS} 天前的备份..."
find "$BACKUP_DIR" -name "royalbot_*.sql.gz" -mtime +${RETENTION_DAYS} -delete

# List backups
log_info "当前备份列表:"
ls -lh "$BACKUP_DIR"/royalbot_*.sql.gz 2>/dev/null || echo "无备份文件"
