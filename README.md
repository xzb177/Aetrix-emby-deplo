# Aetrix Emby Portal

> 🚀 专业级 Emby 媒体服务器管理平台 - 一键部署配置

[![Deploy](https://img.shields.io/badge/deploy-ready-brightgreen)](https://github.com/xzb177/Aetrix-emby-deplo)
[![Docker](https://img.shields.io/badge/docker-supported-blue)](https://www.docker.com/)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

## ✨ 功能特性

- 🎬 **Emby 集成** - 无缝对接 Emby 媒体服务器
- 👥 **用户管理** - 完善的用户注册、认证、权限系统
- 💳 **订阅管理** - 灵活的套餐订阅与支付对接
- 🎫 **工单系统** - 便捷的用户支持工单处理
- 📊 **数据统计** - 实时的用户行为与媒体消费分析
- 🔐 **安全加固** - 多层安全防护，符合生产环境标准
- ⚡ **性能优化** - Redis 缓存、数据库连接池、Gzip 压缩
- 📱 **响应式设计** - 完美支持桌面端与移动端

## 📋 系统要求

| 组件 | 最低配置 | 推荐配置 |
|------|----------|----------|
| 操作系统 | Ubuntu 20.04+ / CentOS 8+ | Ubuntu 22.04 LTS |
| CPU | 2 核 | 4 核+ |
| 内存 | 4 GB | 8 GB+ |
| 磁盘 | 40 GB | 100 GB+ SSD |
| Docker | 20.10+ | 24.0+ |
| Docker Compose | 2.0+ | 2.20+ |

## 🏗️ 服务架构

```
┌─────────────────────────────────────────────────────────────┐
│                        Nginx (反向代理)                       │
│                    SSL / Gzip / 限流                         │
└────────────┬────────────────────────────┬───────────────────┘
             │                            │
    ┌────────▼─────────┐        ┌────────▼─────────┐
    │   用户端前端      │        │   管理后台前端    │
    │   Vue 3 + Vite   │        │   Vue 3 + Vite   │
    │   Element Plus   │        │   Element Plus   │
    └────────┬─────────┘        └────────┬─────────┘
             │                            │
    ┌────────▼─────────┐        ┌────────▼─────────┐
    │   用户端后端      │        │   管理后台后端    │
    │    FastAPI       │        │    FastAPI       │
    │    :8001         │        │    :8080         │
    └────────┬─────────┘        └────────┬─────────┘
             │                            │
             └──────────┬─────────────────┘
                        │
        ┌───────────────┴───────────────┐
        │                               │
    ┌───▼──────┐                    ┌───▼──────┐
    │PostgreSQL│                    │  Redis   │
    │  :5432   │                    │  :6379   │
    │  用户数据 │                    │  会话缓存 │
    └──────────┘                    └──────────┘
```

## 🚀 快速部署

### 方式一：一键部署脚本（推荐）

```bash
# 1. 克隆部署仓库
git clone https://github.com/xzb177/Aetrix-emby-deplo.git
cd Aetrix-emby-deplo

# 2. 配置环境变量
cp .env.example .env
nano .env

# 修改以下必填项：
# - POSTGRES_PASSWORD（数据库密码）
# - REDIS_PASSWORD（Redis 密码）
# - JWT_SECRET_KEY（JWT 密钥）
# - DEFAULT_ADMIN_PASSWORD（管理员密码）

# 3. 生成安全密钥（可选）
openssl rand -hex 32  # 复制输出作为 JWT_SECRET_KEY

# 4. 一键部署
chmod +x deploy.sh
./deploy.sh
```

### 方式二：手动部署

```bash
# 1. 拉取镜像
docker pull ghcr.io/royalbot/royalbot-user-backend:latest
docker pull ghcr.io/royalbot/royalbot-admin-backend:latest
docker pull ghcr.io/royalbot/royalbot-user-frontend:latest
docker pull ghcr.io/royalbot/royalbot-admin-frontend:latest

# 2. 启动服务
docker compose up -d

# 3. 查看状态
docker compose ps
```

## ⚙️ 环境变量配置

### 必填配置

| 变量 | 说明 | 生成方式 |
|------|------|----------|
| `POSTGRES_PASSWORD` | PostgreSQL 数据库密码 | 自行设置，建议 16 位以上 |
| `REDIS_PASSWORD` | Redis 缓存密码 | 自行设置 |
| `JWT_SECRET_KEY` | JWT 签名密钥 | `openssl rand -hex 32` |
| `DEFAULT_ADMIN_PASSWORD` | 默认管理员密码 | 自行设置，首次登录后请修改 |
| `CRYPTO_KEY` | 数据加密密钥 | `openssl rand -hex 16` |

### 可选配置

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `DEBUG` | 调试模式 | `false` |
| `FRONTEND_URL` | 前端访问地址 | `https://your-domain.com` |
| `TELEGRAM_BOT_TOKEN` | Telegram Bot 令牌 | - |
| `IMAGE_TAG` | 镜像标签 | `latest` |

## 🔒 SSL 证书配置

### Let's Encrypt 免费证书（推荐）

```bash
# 1. 安装 Certbot
apt update && apt install certbot -y

# 2. 获取证书（需先停止 80 端口占用）
docker compose stop nginx
certbot certonly --standalone -d your-domain.com

# 3. 创建 SSL 目录
mkdir -p nginx/ssl

# 4. 复制证书
cp /etc/letsencrypt/live/your-domain.com/fullchain.pem nginx/ssl/
cp /etc/letsencrypt/live/your-domain.com/privkey.pem nginx/ssl/

# 5. 启动 Nginx
docker compose start nginx

# 6. 设置自动续期
echo "0 0 * * * certbot renew --quiet && docker compose restart nginx" | crontab -
```

### 自有证书

```bash
# 将证书文件放置到 nginx/ssl/ 目录
nginx/ssl/fullchain.pem  # 证书链
nginx/ssl/privkey.pem     # 私钥
```

## 📦 镜像列表

| 镜像 | 说明 | 来源 |
|------|------|------|
| `royalbot-user-backend` | 用户端后端 API | [ghcr.io](https://ghcr.io) |
| `royalbot-admin-backend` | 管理后台后端 API | [ghcr.io](https://ghcr.io) |
| `royalbot-user-frontend` | 用户端前端（Vue 3） | [ghcr.io](https://ghcr.io) |
| `royalbot-admin-frontend` | 管理后台前端（Vue 3） | [ghcr.io](https://ghcr.io) |

## 🔧 常用命令

```bash
# 查看服务状态
docker compose ps

# 查看实时日志
docker compose logs -f nginx
docker compose logs -f user_backend
docker compose logs -f admin_backend

# 重启单个服务
docker compose restart nginx
docker compose restart user_backend

# 停止所有服务
docker compose down

# 停止并删除数据卷
docker compose down -v

# 更新并重启
git pull
docker compose pull
docker compose up -d --remove-orphans
docker image prune -f
```

## 💾 数据备份与恢复

### 手动备份

```bash
# 运行备份脚本
./scripts/backup.sh

# 备份文件存储在 Docker 卷中，可通过以下命令导出
docker run --rm -v royalbot-emby-deploy_backup_data:/data -v $(pwd):/out alpine tar czf /out/backup.tar.gz -C /data .
```

### 恢复数据

```bash
# 查看可用备份
ls -lh /var/lib/docker/volumes/royalbot-emby-deploy_backup_data/_data/

# 恢复指定备份
./scripts/restore.sh /path/to/backup.sql.gz
```

### 自动备份

```bash
# 启用自动备份（每天凌晨 2 点）
echo "0 2 * * * cd /root/Aetrix-emby-deplo && ./scripts/backup.sh" | crontab -
```

## 🛠️ 故障排查

### 服务启动失败

```bash
# 1. 查看详细日志
docker compose logs [service-name]

# 2. 检查端口占用
netstat -tunlp | grep -E ':(80|443|5432|6379|8001|8080)'

# 3. 检查磁盘空间
df -h
```

### 数据库连接失败

```bash
# 1. 测试数据库连接
docker exec -it royalbot_postgres psql -U royalbot -d royalbot

# 2. 检查数据库日志
docker compose logs postgres
```

### Nginx 502 错误

```bash
# 1. 检查后端服务状态
docker compose ps

# 2. 检查后端日志
docker compose logs user_backend
docker compose logs admin_backend

# 3. 测试后端直接访问
curl http://localhost:8001/health
curl http://localhost:8080/health
```

## 🔐 安全加固建议

1. **修改默认密码** - 部署后立即修改所有默认密码
2. **防火墙配置** - 只开放 80、443 端口
   ```bash
   ufw allow 80/tcp
   ufw allow 443/tcp
   ufw enable
   ```
3. **Fail2ban** - 防止 SSH 暴力破解
   ```bash
   apt install fail2ban -y
   ```
4. **定期更新** - 保持系统和 Docker 镜像最新
5. **限制访问** - 数据库和 Redis 仅内部网络访问
6. **日志审计** - 定期检查访问日志

## 📊 性能优化

### Nginx 优化

- ✅ Gzip 压缩（已启用）
- ✅ HTTP/2 支持
- ✅ 连接复用（keepalive）
- ✅ 请求限流

### 后端优化

- ✅ Redis 缓存
- ✅ 数据库连接池
- ✅ 异步 I/O

### 前端优化

- ✅ 代码分割
- ✅ 懒加载
- ✅ 资源压缩

## 📝 更新日志

### v1.0.0 (2025-01-10)

- 🎉 初始发布
- ✅ 完整的 Docker Compose 配置
- ✅ Nginx 反向代理 + SSL 支持
- ✅ 一键部署脚本
- ✅ 数据库备份/恢复脚本
- ✅ GitHub Actions CI/CD

## 📄 许可证

MIT License - 详见 [LICENSE](LICENSE) 文件

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📞 支持

- 📧 邮箱: support@aetrix.com
- 💬 Telegram: [@AetrixSupport](https://t.me/AetrixSupport)
- 🌐 官网: https://aetrix.com

---

<div align="center">

**Made with ❤️ by Aetrix Team**

</div>
