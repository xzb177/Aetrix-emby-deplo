#!/bin/bash
# RoyalBot 服务看门狗脚本
# 定期检查服务状态，自动重启停止的服务

LOG_FILE="/var/log/royalbot-watchdog.log"
LOCK_FILE="/tmp/royalbot-watchdog.lock"

# 重要容器列表
CONTAINERS=(
    "royalbot_nginx"
    "royalbot_user_frontend"
    "royalbot_user_backend"
    "royalbot_admin_frontend"
    "royalbot_admin_backend"
    "royalbot_postgres"
    "royalbot_redis"
)

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# 检查并重启容器
check_and_restart() {
    local container=$1
    local status=$(docker inspect -f '{{.State.Running}}' "$container" 2>/dev/null)

    if [ "$status" != "true" ]; then
        log "⚠️  容器 $container 未运行，正在启动..."
        docker start "$container" >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            log "✅ 容器 $container 启动成功"
        else
            log "❌ 容器 $container 启动失败"
        fi
    fi
}

# 防止重复运行
if [ -f "$LOCK_FILE" ]; then
    pid=$(cat "$LOCK_FILE")
    if ps -p "$pid" >/dev/null 2>&1; then
        exit 0
    fi
fi
echo $$ > "$LOCK_FILE"

# 检查所有容器
for container in "${CONTAINERS[@]}"; do
    check_and_restart "$container"
done

# 清理锁文件
rm -f "$LOCK_FILE"
