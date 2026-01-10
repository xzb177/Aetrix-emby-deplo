#!/bin/bash
# RoyalBot Emby Portal - Database Restore Script

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check arguments
if [ -z "$1" ]; then
    echo "用法: $0 <backup-file>"
    echo ""
    echo "可用备份:"
    ls -lh /backups/royalbot_*.sql.gz 2>/dev/null || echo "无备份文件"
    exit 1
fi

BACKUP_FILE="$1"

if [ ! -f "$BACKUP_FILE" ]; then
    log_error "备份文件不存在: $BACKUP_FILE"
fi

# Confirm
log_warn "即将恢复数据库，现有数据将被覆盖！"
read -p "确认继续? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    log_info "取消恢复"
    exit 0
fi

# Restore
log_info "开始恢复..."
if [[ "$BACKUP_FILE" == *.gz ]]; then
    gunzip -c "$BACKUP_FILE" | docker exec -i royalbot_postgres psql -U royalbot -d royalbot
else
    docker exec -i royalbot_postgres psql -U royalbot -d royalbot < "$BACKUP_FILE"
fi

log_info "恢复完成！"
