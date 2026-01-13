#!/bin/bash
################################################################################
# RoyalBot Portal 一键更新脚本
# 用途: 快速更新前端代码和服务
# 使用: ./update.sh
################################################################################

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# 项目目录
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

# 版本
VERSION="1.7.0"

# 检测 Docker Compose 命令
if docker compose version &> /dev/null; then
    DOCKER_COMPOSE="docker compose"
else
    DOCKER_COMPOSE="docker-compose"
fi

# 日志函数
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

print_header() {
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}========================================${NC}"
}

# 显示帮助
show_help() {
  echo ""
  echo -e "${BOLD}RoyalBot Portal 一键更新脚本 v${VERSION}${NC}"
  echo ""
  echo -e "${BOLD}用法:${NC}"
  echo "  $0 [选项]"
  echo ""
  echo -e "${BOLD}选项:${NC}"
  echo "  --no-cache      构建时不使用缓存"
  echo "  --clean         清理旧镜像"
  echo "  -h, --help      显示帮助信息"
  echo ""
  echo -e "${BOLD}示例:${NC}"
  echo "  $0              # 标准更新"
  echo "  $0 --clean      # 更新并清理旧镜像"
  echo ""
}

# 解析参数
NO_CACHE=""
CLEAN=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --no-cache) NO_CACHE="--no-cache"; shift ;;
    --clean) CLEAN="yes"; shift ;;
    -h|--help) show_help; exit 0 ;;
    *) echo -e "${RED}未知选项: $1${NC}"; show_help; exit 1 ;;
  esac
done

# 检查环境
check_environment() {
  log_info "检查部署环境..."
  if ! command -v docker &> /dev/null; then
    log_error "Docker 未安装"
    exit 1
  fi
  if ! $DOCKER_COMPOSE version &> /dev/null; then
    log_error "Docker Compose 未安装"
    exit 1
  fi
  log_success "环境检查通过"
}

# 备份当前版本
backup_current() {
  print_header "备份当前版本"
  if [ -d "user_frontend/dist" ]; then
    BACKUP_DIR="backups/frontend_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    cp -r user_frontend/dist "$BACKUP_DIR/"
    log_success "已备份到: $BACKUP_DIR"
  else
    log_warning "没有找到 user_frontend/dist，跳过备份"
  fi
}

# 构建前端
build_frontend() {
  print_header "构建前端"
  log_info "开始构建 user_frontend 镜像..."
  
  if [ -n "$NO_CACHE" ]; then
    $DOCKER_COMPOSE build $NO_CACHE user_frontend
  else
    $DOCKER_COMPOSE build user_frontend
  fi

  if [ $? -eq 0 ]; then
    log_success "user_frontend 镜像构建完成"
  else
    log_error "user_frontend 镜像构建失败"
    exit 1
  fi
}

# 重启服务
restart_services() {
  print_header "重启服务"
  log_info "重启 user_frontend 服务..."
  $DOCKER_COMPOSE up -d user_frontend
  sleep 5

  if docker ps --format '{{.Names}}' | grep -q "^royalbot_user_frontend$"; then
    log_success "user_frontend 服务已启动"
  else
    log_error "user_frontend 服务未启动"
    exit 1
  fi
}

# 清理旧镜像
cleanup_images() {
  print_header "清理旧镜像"
  log_info "清理未使用的镜像..."
  docker image prune -f
  log_success "清理完成"
}

# 显示状态
show_status() {
  print_header "服务状态"
  docker ps --filter "name=royalbot" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
}

# 主函数
main() {
  echo ""
  echo "=========================================="
  echo "  RoyalBot Portal 一键更新脚本 v${VERSION}"
  echo "=========================================="
  echo ""

  check_environment
  backup_current
  build_frontend
  restart_services

  if [ -n "$CLEAN" ]; then
    cleanup_images
  fi

  show_status
  echo ""
  log_success "更新完成！"
  echo ""
}

main
