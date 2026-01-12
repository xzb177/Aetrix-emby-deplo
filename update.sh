#!/bin/bash
# RoyalBot Emby Portal - One-Click Update Script
# Version: 1.0.0
# 此脚本用于从源码构建并更新服务

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SOURCE_DIR="/root/RoyalBot-Portal"
DEPLOY_DIR="/root/royalbot-emby-deploy"
PROJECT_NAME="RoyalBot Emby Portal"

# Functions
print_banner() {
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║         $PROJECT_NAME                              ║"
    echo "║              One-Click Update                         ║"
    echo "║                    v1.0.0                             ║"
    echo "╚════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Check if source directory exists
check_source() {
    log_info "检查源码目录..."

    if [ ! -d "$SOURCE_DIR" ]; then
        log_error "源码目录不存在: $SOURCE_DIR"
    fi

    # Check if source is a git repo
    if [ ! -d "$SOURCE_DIR/.git" ]; then
        log_error "源码目录不是 git 仓库"
    fi

    log_info "源码目录检查通过 ✓"
}

# Pull latest code
pull_code() {
    log_info "拉取最新代码..."
    cd "$SOURCE_DIR"
    git fetch origin
    git reset --hard origin/main
    log_info "代码更新完成 ✓"
}

# Build user backend
build_user_backend() {
    log_info "构建用户后端..."
    cd "$SOURCE_DIR/user_backend"
    docker build -t royalbot-portal-user_backend:latest .
    log_info "用户后端构建完成 ✓"
}

# Build user frontend
build_user_frontend() {
    log_info "构建用户前端..."
    cd "$SOURCE_DIR/user_frontend"
    npm run build-only 2>/dev/null || npm run build 2>/dev/null
    rm -rf "${DEPLOY_DIR}/user_frontend_dist"/*
    cp -r dist/* "${DEPLOY_DIR}/user_frontend_dist/"
    log_info "用户前端构建完成 ✓"
}

# Build admin backend
build_admin_backend() {
    log_info "构建管理后端..."
    cd "$SOURCE_DIR/admin_backend"
    docker build -t royalbot-portal-admin_backend:latest .
    log_info "管理后端构建完成 ✓"
}

# Build admin frontend
build_admin_frontend() {
    log_info "构建管理前端..."
    cd "$SOURCE_DIR/admin_frontend"
    npm run build-only 2>/dev/null || npm run build 2>/dev/null
    rm -rf "${DEPLOY_DIR}/admin_frontend_dist"/*
    cp -r dist/* "${DEPLOY_DIR}/admin_frontend_dist/"
    log_info "管理前端构建完成 ✓"
}

# Restart services
restart_services() {
    log_info "重启服务..."

    # Stop and remove old containers
    docker stop royalbot_user_backend royalbot_admin_backend 2>/dev/null || true
    docker rm royalbot_user_backend royalbot_admin_backend 2>/dev/null || true

    # Start new containers
    cd "$DEPLOY_DIR"
    docker compose up -d user_backend admin_backend

    log_info "服务重启完成 ✓"
}

# Health check
health_check() {
    log_info "执行健康检查..."

    sleep 5

    # Backend APIs
    curl -sf http://localhost:8080/health >/dev/null && log_info "Admin Backend: ✓" || log_warn "Admin Backend: ✗"
    curl -sf http://localhost:8001/health >/dev/null && log_info "User Backend: ✓" || log_warn "User Backend: ✗"

    # Nginx
    curl -sk https://localhost/ >/dev/null && log_info "Nginx: ✓" || log_warn "Nginx: ✗"
}

# Show info
show_info() {
    echo ""
    echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}                    更新完成！                              ${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "更新内容:"
    echo "  - 用户后端 (royalbot-portal-user_backend)"
    echo "  - 管理后端 (royalbot-portal-admin_backend)"
    echo "  - 用户前端 (user_frontend_dist)"
    echo "  - 管理前端 (admin_frontend_dist)"
    echo ""
    echo "服务地址:"
    echo "  用户端: https://login.laodaemby.xyz"
    echo "  管理后台: https://login.laodaemby.xyz/admin"
    echo ""
}

# Main
main() {
    print_banner
    echo ""

    # Parse arguments
    UPDATE_ALL=true
    UPDATE_USER_BACKEND=false
    UPDATE_USER_FRONTEND=false
    UPDATE_ADMIN_BACKEND=false
    UPDATE_ADMIN_FRONTEND=false
    SKIP_PULL=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --backend)
                UPDATE_ALL=false
                UPDATE_USER_BACKEND=true
                UPDATE_ADMIN_BACKEND=true
                shift
                ;;
            --frontend)
                UPDATE_ALL=false
                UPDATE_USER_FRONTEND=true
                UPDATE_ADMIN_FRONTEND=true
                shift
                ;;
            --user-backend)
                UPDATE_ALL=false
                UPDATE_USER_BACKEND=true
                shift
                ;;
            --user-frontend)
                UPDATE_ALL=false
                UPDATE_USER_FRONTEND=true
                shift
                ;;
            --admin-backend)
                UPDATE_ALL=false
                UPDATE_ADMIN_BACKEND=true
                shift
                ;;
            --admin-frontend)
                UPDATE_ALL=false
                UPDATE_ADMIN_FRONTEND=true
                shift
                ;;
            --skip-pull)
                SKIP_PULL=true
                shift
                ;;
            *)
                log_error "未知参数: $1"
                ;;
        esac
    done

    check_source

    if [ "$SKIP_PULL" = false ]; then
        pull_code
    fi

    if [ "$UPDATE_ALL" = true ] || [ "$UPDATE_USER_BACKEND" = true ]; then
        build_user_backend
    fi

    if [ "$UPDATE_ALL" = true ] || [ "$UPDATE_USER_FRONTEND" = true ]; then
        build_user_frontend
    fi

    if [ "$UPDATE_ALL" = true ] || [ "$UPDATE_ADMIN_BACKEND" = true ]; then
        build_admin_backend
    fi

    if [ "$UPDATE_ALL" = true ] || [ "$UPDATE_ADMIN_FRONTEND" = true ]; then
        build_admin_frontend
    fi

    restart_services
    health_check
    show_info
}

main "$@"
