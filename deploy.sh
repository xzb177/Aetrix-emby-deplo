#!/bin/bash
# RoyalBot Emby Portal - One-Click Deployment Script
# Version: 1.0.0

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
PROJECT_NAME="RoyalBot Emby Portal"
COMPOSE_FILE="docker-compose.yml"
ENV_FILE=".env"
REGISTRY="${REGISTRY:-ghcr.io/royalbot}"
IMAGE_TAG="${IMAGE_TAG:-latest}"

# Functions
print_banner() {
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║         $PROJECT_NAME                              ║"
    echo "║              One-Click Deployment                     ║"
    echo "║                    v1.0.0                             ║"
    echo "╚════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Check requirements
check_requirements() {
    log_info "检查系统依赖..."

    command -v docker >/dev/null 2>&1 || log_error "Docker 未安装"
    command -v docker compose >/dev/null 2>&1 || log_error "Docker Compose V2 未安装"

    log_info "系统依赖检查通过 ✓"
}

# Check environment file
check_env() {
    if [ ! -f "$ENV_FILE" ]; then
        log_warn "未找到 .env 文件"
        if [ -f ".env.example" ]; then
            cp .env.example "$ENV_FILE"
            log_warn "已从 .env.example 创建 .env 文件"
            log_warn "请编辑 .env 文件设置正确的配置后重新运行"
            exit 1
        else
            log_error "未找到 .env.example 文件"
        fi
    fi

    source "$ENV_FILE"

    local required_vars=("POSTGRES_PASSWORD" "REDIS_PASSWORD" "JWT_SECRET_KEY" "DEFAULT_ADMIN_PASSWORD")
    local missing_vars=()

    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ] || [[ "${!var}" == change_* ]]; then
            missing_vars+=("$var")
        fi
    done

    if [ ${#missing_vars[@]} -gt 0 ]; then
        log_error "以下环境变量未设置或使用默认值: ${missing_vars[*]}"
    fi
}

# Pull images
pull_images() {
    if [ "$SKIP_PULL" = "true" ]; then
        log_warn "跳过镜像拉取 (SKIP_PULL=true)"
        return
    fi

    log_info "拉取 Docker 镜像..."

    local services=("user-backend" "admin-backend" "user-frontend" "admin-frontend")
    for service in "${services[@]}"; do
        log_info "拉取 ${REGISTRY}/royalbot-${service}:${IMAGE_TAG}"
        docker pull "${REGISTRY}/royalbot-${service}:${IMAGE_TAG}" || true
    done
}

# Start services
start_services() {
    log_info "启动服务..."
    docker compose up -d

    log_info "等待服务启动..."
    sleep 15
}

# Health check
health_check() {
    log_info "执行健康检查..."

    # PostgreSQL
    local postgres_ready=false
    for i in {1..30}; do
        if docker exec royalbot_postgres pg_isready -U royalbot &>/dev/null; then
            postgres_ready=true
            break
        fi
        sleep 1
    done
    $postgres_ready && log_info "PostgreSQL: ✓" || log_warn "PostgreSQL: ✗"

    # Redis
    local redis_ready=false
    for i in {1..30}; do
        if docker exec royalbot_redis redis-cli ping &>/dev/null; then
            redis_ready=true
            break
        fi
        sleep 1
    done
    $redis_ready && log_info "Redis: ✓" || log_warn "Redis: ✗"

    # Backend APIs
    curl -sf http://localhost:8080/health >/dev/null && log_info "Admin Backend: ✓" || log_warn "Admin Backend: ✗"
    curl -sf http://localhost:8001/health >/dev/null && log_info "User Backend: ✓" || log_warn "User Backend: ✗"
}

# Show info
show_info() {
    echo ""
    echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}                    部署完成！                              ${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "服务地址:"
    echo "  用户端: https://login.laodaemby.xyz"
    echo "  管理后台: https://login.laodaemby.xyz/admin"
    echo ""
    echo "默认管理员: admin"
    echo "默认密码: 查看 .env 中的 DEFAULT_ADMIN_PASSWORD"
    echo ""
    echo "常用命令:"
    echo "  查看日志: docker compose logs -f [service]"
    echo "  停止服务: docker compose down"
    echo "  重启服务: docker compose restart [service]"
    echo "  更新服务: ./deploy.sh"
    echo ""
}

# Main
main() {
    print_banner
    echo ""

    check_requirements
    check_env
    pull_images
    start_services
    health_check
    show_info
}

main "$@"
