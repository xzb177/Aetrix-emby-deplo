# RoyalBot Emby Portal

> 官方一键部署配置 | 生产环境就绪

[![Deploy](https://img.shields.io/badge/deploy-ready-brightgreen)](https://github.com/royalbot/royalbot-emby-deploy)
[![Docker](https://img.shields.io/badge/docker-supported-blue)](https://www.docker.com/)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

## 快速开始

```bash
# 克隆部署仓库
git clone https://github.com/royalbot/royalbot-emby-deploy.git
cd royalbot-emby-deploy

# 配置环境变量
cp .env.example .env
nano .env  # 修改密码等配置

# 一键部署
chmod +x deploy.sh
./deploy.sh
```

## 服务架构

```
┌─────────────────────────────────────────────────────────┐
│                         Nginx                            │
│                    (443/80)                             │
└───────────┬──────────────────────────┬──────────────────┘
            │                          │
    ┌───────▼────────┐        ┌───────▼────────┐
    │  User Frontend │        │ Admin Frontend │
    │      (Vue 3)   │        │     (Vue 3)    │
    └───────┬────────┘        └───────┬────────┘
            │                          │
    ┌───────▼────────┐        ┌───────▼────────┐
    │  User Backend  │        │ Admin Backend  │
    │    (FastAPI)   │        │    (FastAPI)   │
    │     :8001      │        │     :8080      │
    └───────┬────────┘        └───────┬────────┘
            │                          │
            └──────────┬───────────────┘
                       │
        ┌──────────────┴──────────────┐
        │                              │
    ┌───▼─────┐                  ┌────▼───┐
    │PostgreSQL│                  │ Redis  │
    │  :5432  │                  │  :6379 │
    └─────────┘                  └────────┘
```

## 环境变量

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `POSTGRES_PASSWORD` | PostgreSQL 密码 | - |
| `REDIS_PASSWORD` | Redis 密码 | - |
| `JWT_SECRET_KEY` | JWT 密钥 | - |
| `DEFAULT_ADMIN_PASSWORD` | 管理员密码 | - |
| `CRYPTO_KEY` | 加密密钥 | - |
| `FRONTEND_URL` | 前端 URL | https://login.laodaemby.xyz |

## 常用命令

```bash
# 查看服务状态
docker compose ps

# 查看日志
docker compose logs -f nginx
docker compose logs -f user_backend
docker compose logs -f admin_backend

# 重启服务
docker compose restart nginx
docker compose restart user_backend

# 停止所有服务
docker compose down

# 更新并重启
git pull
docker compose pull
docker compose up -d
```

## 数据库备份

```bash
# 手动备份
./scripts/backup.sh

# 恢复
./scripts/restore.sh <backup-file>
```

## SSL 证书

### Let's Encrypt 自动证书

```bash
# 安装 certbot
apt install certbot

# 获取证书
certbot certonly --standalone -d login.laodaemby.xyz

# 复制证书
cp /etc/letsencrypt/live/login.laodaemby.xyz/fullchain.pem nginx/ssl/
cp /etc/letsencrypt/live/login.laodaemby.xyz/privkey.pem nginx/ssl/

# 重启 Nginx
docker compose restart nginx
```

## 故障排查

### 服务无法启动

```bash
# 查看详细日志
docker compose logs [service]

# 检查网络
docker network inspect royalbot_network
```

### 数据库连接失败

```bash
# 测试连接
docker exec -it royalbot_postgres psql -U royalbot -d royalbot
```

## 安全建议

1. 修改所有默认密码
2. 启用防火墙，只开放 80/443 端口
3. 定期更新镜像
4. 配置数据库和 Redis 仅内部访问
5. 启用 fail2ban 防止暴力破解

## 许可证

MIT License
