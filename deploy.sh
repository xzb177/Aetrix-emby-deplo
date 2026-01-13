#!/bin/bash
################################################################################
# RoyalBot Portal 一键部署脚本
# 用途: 快速部署/更新 RoyalBot Portal 服务
# 使用: ./deploy.sh [命令]
#
# 选项:
#   --build           强制重新构建镜像
#   --no-cache        构建时不使用缓存
#   --backend         仅部署后端服务 (admin + user)
#   --admin-backend   仅部署管理后台后端
#   --user-backend    仅部署用户端后端
#   --frontend        仅部署前端服务 (admin + user)
#   --admin-frontend  仅部署管理后台前端
#   --user-frontend   仅部署用户端前端
#   --admin           仅部署管理后台 (backend + frontend)
#   --user            仅部署用户端 (backend + frontend)
#   --bot             仅部署 Telegram Bot
#   --all             部署所有服务
#   --rollback        回滚到上一版本
#   --status          显示服务状态
#   --logs            显示服务日志
#   --update          更新代码并部署
#   --build-fe        构建前端
#   --backup          备份数据库
#   --restore         恢复数据库
#   --menu            显示交互式菜单
#   -h, --help        显示帮助信息
################################################################################

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# 项目目录
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

# 版本
VERSION="1.7.0"

# 默认选项
BUILD_FLAG=""
CACHE_FLAG="--pull"
SERVICES=""
ACTION="deploy"

# 检测 Docker Compose 命令
if docker compose version &> /dev/null; then
    DOCKER_COMPOSE="docker compose"
else
    DOCKER_COMPOSE="docker-compose"
fi

# 解析命令行参数
while [[ $# -gt 0 ]]; do
  case $1 in
    --build)
      BUILD_FLAG="--build --force-recreate"
      shift
      ;;
    --no-cache)
      CACHE_FLAG="--no-cache"
      shift
      ;;
    --backend)
      SERVICES="admin_backend user_backend"
      shift
      ;;
    --admin-backend)
      SERVICES="admin_backend"
      shift
      ;;
    --user-backend)
      SERVICES="user_backend"
      shift
      ;;
    --frontend)
      SERVICES="admin_frontend user_frontend"
      shift
      ;;
    --admin-frontend)
      SERVICES="admin_frontend"
      shift
      ;;
    --user-frontend)
      SERVICES="user_frontend"
      shift
      ;;
    --user)
      SERVICES="user_backend user_frontend"
      shift
      ;;
    --admin)
      SERVICES="admin_backend admin_frontend"
      shift
      ;;
    --bot)
      SERVICES="telegram_login_bot"
      shift
      ;;
    --all)
      SERVICES=""
      shift
      ;;
    --rollback)
      ACTION="rollback"
      shift
      ;;
    --status)
      ACTION="status"
      shift
      ;;
    --logs)
      ACTION="logs"
      shift
      ;;
    --update)
      ACTION="update"
      shift
      ;;
    --build-fe)
      ACTION="build-fe"
      shift
      ;;
    --backup)
      ACTION="backup"
      shift
      ;;
    --restore)
      ACTION="restore"
      shift
      ;;
    --menu)
      ACTION="menu"
      shift
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    *)
      echo -e "${RED}未知选项: $1${NC}"
      echo "使用 -h 或 --help 查看帮助"
      exit 1
      ;;
  esac
done

# 日志函数
log_info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}========================================${NC}"
}

# 检查环境
check_environment() {
  log_info "检查部署环境..."

  # 检查 Docker
  if ! command -v docker &> /dev/null; then
    log_error "Docker 未安装"
    exit 1
  fi

  # 检查 docker compose
  if ! $DOCKER_COMPOSE version &> /dev/null; then
    log_error "Docker Compose 未安装"
    exit 1
  fi

  # 检查 .env 文件
  if [ ! -f "$PROJECT_DIR/.env" ]; then
    log_warning ".env 文件不存在，将从 .env.example 复制"
    if [ -f "$PROJECT_DIR/.env.example" ]; then
      cp "$PROJECT_DIR/.env.example" "$PROJECT_DIR/.env"

      # 生成随机密码
      POSTGRES_PASSWORD=$(openssl rand -base64 16 | tr -d '/+=')
      REDIS_PASSWORD=$(openssl rand -base64 16 | tr -d '/+=')
      JWT_SECRET_KEY=$(openssl rand -base64 32 | tr -d '/+=')
      CRYPTO_KEY=$(openssl rand -base64 32 | tr -d '/+=')
      CRON_SECRET=$(openssl rand -base64 16 | tr -d '/+=')
      DEFAULT_ADMIN_PASSWORD=$(openssl rand -base64 12 | tr -d '/+=')
      GRAFANA_ADMIN_PASSWORD=$(openssl rand -base64 12 | tr -d '/+=')

      sed -i "s/POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=${POSTGRES_PASSWORD}/" .env
      sed -i "s/REDIS_PASSWORD=.*/REDIS_PASSWORD=${REDIS_PASSWORD}/" .env
      sed -i "s/JWT_SECRET_KEY=.*/JWT_SECRET_KEY=${JWT_SECRET_KEY}/" .env
      sed -i "s/CRYPTO_KEY=.*/CRYPTO_KEY=${CRYPTO_KEY}/" .env
      sed -i "s/CRON_SECRET=.*/CRON_SECRET=${CRON_SECRET}/" .env
      sed -i "s/DEFAULT_ADMIN_PASSWORD=.*/DEFAULT_ADMIN_PASSWORD=${DEFAULT_ADMIN_PASSWORD}/" .env
      sed -i "s/GRAFANA_ADMIN_PASSWORD=.*/GRAFANA_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD}/" .env

      log_success "已生成随机密码并保存到 .env"
      log_warning "请编辑 .env 文件配置其他必要的环境变量！"
    else
      log_error ".env.example 文件不存在"
      exit 1
    fi
  fi

  log_success "环境检查通过"
}

# 更新代码
update_code() {
  log_info "更新代码..."

  # 检查是否是 git 仓库
  if [ -d ".git" ]; then
    # 保存当前 commit
    CURRENT_COMMIT=$(git rev-parse HEAD)

    # 拉取最新代码
    git fetch origin
    git pull origin main

    NEW_COMMIT=$(git rev-parse HEAD)

    if [ "$CURRENT_COMMIT" != "$NEW_COMMIT" ]; then
      log_success "代码已更新: $CURRENT_COMMIT -> $NEW_COMMIT"
      git log --oneline -1
    else
      log_info "代码已是最新版本"
    fi
  else
    log_warning "不是 Git 仓库，跳过代码更新"
  fi
}

# 构建前端
build_frontend() {
    print_header "构建前端"

    # 构建用户前端
    log_info "构建用户前端..."
    if [ -d "user_frontend" ] && [ -f "user_frontend/package.json" ]; then
        cd user_frontend
        npm install --legacy-peer-deps
        npm run build
        cd ..
        log_success "用户前端构建完成"
    else
        log_warning "user_frontend 不存在或缺少 package.json，跳过"
    fi

    # 构建管理前端
    log_info "构建管理前端..."
    if [ -d "admin_frontend" ] && [ -f "admin_frontend/package.json" ]; then
        cd admin_frontend
        npm install --legacy-peer-deps
        npm run build
        cd ..
        log_success "管理前端构建完成"
    else
        log_warning "admin_frontend 不存在或缺少 package.json，跳过"
    fi
}

# 构建镜像
build_images() {
  log_info "构建 Docker 镜像..."

  if [ -z "$SERVICES" ]; then
    # 默认构建所有服务
    $DOCKER_COMPOSE build $CACHE_FLAG
  else
    # 根据指定的服务构建
    for service in $SERVICES; do
      case $service in
        admin_backend|admin_frontend|user_backend|user_frontend|telegram_login_bot)
          $DOCKER_COMPOSE build $CACHE_FLAG $service
          ;;
        *)
          log_warning "未知服务: $service，跳过构建"
          ;;
      esac
    done
  fi

  log_success "镜像构建完成"
}

# 部署服务
deploy_services() {
  log_info "部署服务..."

  if [ -z "$SERVICES" ]; then
    SERVICES="admin_backend admin_frontend user_backend user_frontend nginx"
  fi

  # 启动服务
  log_info "启动服务: $SERVICES"
  $DOCKER_COMPOSE up -d $BUILD_FLAG $SERVICES

  # 等待服务健康检查
  log_info "等待服务启动..."
  sleep 5

  # 检查服务状态
  for service in $SERVICES; do
    CONTAINER_NAME="royalbot_${service}"
    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
      STATUS=$(docker inspect --format='{{.State.Status}}' "$CONTAINER_NAME" 2>/dev/null)
      HEALTH_STATUS=$(docker inspect --format='{{.State.Health.Status}}' "$CONTAINER_NAME" 2>/dev/null || echo "no healthcheck")

      if [ "$HEALTH_STATUS" = "healthy" ] || [ "$HEALTH_STATUS" = "no healthcheck" ]; then
        log_success "$service 服务运行正常"
      elif [ "$HEALTH_STATUS" = "starting" ]; then
        log_warning "$service 服务正在启动..."
      else
        log_warning "$service 服务健康检查: $HEALTH_STATUS"
      fi
    else
      log_warning "$service 服务未启动（可能未定义）"
    fi
  done

  log_success "服务部署完成"
}

# 回滚
rollback() {
  log_warning "开始回滚到上一版本..."

  if [ ! -d ".git" ]; then
    log_error "不是 Git 仓库，无法回滚"
    exit 1
  fi

  # 保存当前 commit
  CURRENT_COMMIT=$(git rev-parse HEAD)

  # 回滚到上一个 commit
  log_info "回滚到上一个 commit..."
  git reset --hard HEAD~1

  # 重新构建并部署
  build_images
  deploy_services

  log_success "回滚完成 (从 $CURRENT_COMMIT)"
}

# 显示状态
show_status() {
  print_header "服务状态"
  $DOCKER_COMPOSE ps
  echo ""

  # 显示访问地址
  echo -e "${BOLD}访问地址:${NC}"
  echo "  用户端: http://localhost/"
  echo "  管理后台: http://localhost/admin"
  echo "  用户 API: http://localhost:8001/docs"
  echo "  管理 API: http://localhost:8080/docs"

  # 显示镜像信息
  echo ""
  log_info "最近构建的镜像:"
  docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.CreatedAt}}\t{{.Size}}" | grep -E "REPOSITORY|royalbot"
}

# 显示日志
show_logs() {
  if [ -z "$SERVICES" ]; then
    $DOCKER_COMPOSE logs -f --tail=100
  else
    $DOCKER_COMPOSE logs -f --tail=100 $SERVICES
  fi
}

# 健康检查
health_check() {
  log_info "执行健康检查..."

  # 检查后端健康
  if curl -f -s http://localhost:8080/health > /dev/null 2>&1; then
    log_success "admin_backend 健康检查通过"
  else
    log_warning "admin_backend 健康检查失败"
  fi

  if curl -f -s http://localhost:8001/health > /dev/null 2>&1; then
    log_success "user_backend 健康检查通过"
  else
    log_warning "user_backend 健康检查失败"
  fi

  # 检查前端
  if curl -f -s http://localhost/ > /dev/null 2>&1; then
    log_success "nginx 健康检查通过"
  else
    log_warning "nginx 健康检查失败"
  fi

  # 外部检查
  EXTERNAL_URL="${API_URL:-https://login.laodaemby.xyz}"
  if curl -f -s "$EXTERNAL_URL/health" > /dev/null 2>&1; then
    log_success "外部健康检查通过 ($EXTERNAL_URL)"
  else
    log_warning "外部健康检查失败 ($EXTERNAL_URL)"
  fi
}

# 清理旧镜像
cleanup() {
  log_info "清理旧镜像..."
  docker image prune -af --filter "until=24h" || true
  log_success "清理完成"
}

# 备份数据库
backup_database() {
    print_header "备份数据库"

    mkdir -p backups

    timestamp=$(date +%Y%m%d_%H%M%S)
    backup_file="backups/royalbot_backup_${timestamp}.sql"

    log_info "正在备份数据库..."

    $DOCKER_COMPOSE exec -T postgres pg_dump -U royalbot royalbot > "$backup_file" 2>/dev/null || {
        log_error "备份失败，请确保 postgres 服务正在运行"
        exit 1
    }

    log_success "备份完成: $backup_file"

    # 压缩备份
    gzip "$backup_file"
    log_success "已压缩: ${backup_file}.gz"

    # 显示备份列表
    echo ""
    log_info "备份文件列表:"
    ls -lh backups/*.gz 2>/dev/null | tail -5
}

# 恢复数据库
restore_database() {
    print_header "恢复数据库"

    # 检查备份目录
    if [ ! -d "backups" ]; then
        log_error "backups 目录不存在"
        exit 1
    fi

    # 显示可用备份
    echo ""
    log_info "可用备份文件:"
    ls -th backups/*.gz 2>/dev/null || ls -th backups/*.sql 2>/dev/null || {
        log_error "没有找到备份文件"
        exit 1
    }

    echo ""
    echo -n "请输入要恢复的备份文件名: "
    read backup_file

    if [ ! -f "backups/$backup_file" ]; then
        log_error "文件不存在: backups/$backup_file"
        exit 1
    fi

    log_warning "恢复数据库将覆盖现有数据！"
    read -p "确认继续? (y/N): " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo "操作已取消"
        exit 0
    fi

    log_info "正在恢复数据库..."

    if [[ "$backup_file" == *.gz ]]; then
        gunzip -c "backups/$backup_file" | $DOCKER_COMPOSE exec -T postgres psql -U royalbot royalbot
    else
        cat "backups/$backup_file" | $DOCKER_COMPOSE exec -T postgres psql -U royalbot royalbot
    fi

    if [ $? -eq 0 ]; then
        log_success "恢复完成"
    else
        log_error "恢复失败"
    fi
}

# 启动监控服务
start_monitoring() {
    log_info "启动监控服务..."
    $DOCKER_COMPOSE --profile monitoring up -d
    log_success "监控服务已启动"
    echo ""
    echo "  Prometheus: http://localhost:9090"
    echo "  Grafana: http://localhost:3002"
}

# 启动备份服务
start_backup_service() {
    log_info "启动自动备份服务..."
    $DOCKER_COMPOSE --profile backup up -d
    log_success "备份服务已启动"
}

# 启动 Telegram Bot
start_bot() {
    log_info "启动 Telegram Bot..."
    $DOCKER_COMPOSE --profile bot up -d
    log_success "Telegram Bot 已启动"
}

# 显示帮助
show_help() {
  cat << EOF
${BOLD}RoyalBot Portal 一键部署脚本 v${VERSION}${NC}

${BOLD}用法:${NC}
  $0 [选项]

${BOLD}部署选项:${NC}
  ${CYAN}--build${NC}           强制重新构建镜像
  ${CYAN}--no-cache${NC}        构建时不使用缓存
  ${CYAN}--backend${NC}         仅部署后端服务 (admin + user)
  ${CYAN}--admin-backend${NC}   仅部署管理后台后端
  ${CYAN}--user-backend${NC}    仅部署用户端后端
  ${CYAN}--frontend${NC}        仅部署前端服务 (admin + user)
  ${CYAN}--admin-frontend${NC}  仅部署管理后台前端
  ${CYAN}--user-frontend${NC}   仅部署用户端前端
  ${CYAN}--admin${NC}           仅部署管理后台 (backend + frontend)
  ${CYAN}--user${NC}            仅部署用户端 (backend + frontend)
  ${CYAN}--bot${NC}             仅部署 Telegram Bot
  ${CYAN}--all${NC}             部署所有服务

${BOLD}操作选项:${NC}
  ${CYAN}--update${NC}          更新代码并部署
  ${CYAN}--rollback${NC}        回滚到上一版本
  ${CYAN}--status${NC}          显示服务状态
  ${CYAN}--logs${NC}            显示服务日志
  ${CYAN}--build-fe${NC}        构建前端
  ${CYAN}--backup${NC}          备份数据库
  ${CYAN}--restore${NC}         恢复数据库
  ${CYAN}--menu${NC}            显示交互式菜单
  ${CYAN}-h, --help${NC}        显示帮助信息

${BOLD}示例:${NC}
  $0                  # 部署默认服务
  $0 --build          # 强制重新构建并部署
  $0 --update         # 更新代码并部署
  $0 --admin          # 仅部署管理后台
  $0 --status         # 显示服务状态
  $0 --backup         # 备份数据库
  $0 --menu           # 交互式菜单

${BOLD}文件:${NC}
  docker-compose.yml         生产环境配置
  docker-compose.dev.yml     开发环境配置
  .env                       环境变量配置

EOF
}

# 交互式菜单
show_interactive_menu() {
    while true; do
        clear
        print_header "RoyalBot Portal 部署工具 v${VERSION}"
        echo ""
        echo -e "${BOLD}部署选项:${NC}"
        echo "  1. 生产环境部署"
        echo "  2. 开发模式部署"
        echo ""
        echo -e "${BOLD}服务控制:${NC}"
        echo "  3. 启动服务"
        echo "  4. 停止服务"
        echo "  5. 重启服务"
        echo "  6. 更新服务"
        echo "  7. 查看状态"
        echo "  8. 查看日志"
        echo ""
        echo -e "${BOLD}数据管理:${NC}"
        echo "  9. 备份数据库"
        echo " 10. 恢复数据库"
        echo ""
        echo -e "${BOLD}附加服务:${NC}"
        echo " 11. 启动监控"
        echo " 12. 启动备份服务"
        echo " 13. 启动 Telegram Bot"
        echo ""
        echo -e "${BOLD}其他:${NC}"
        echo " 14. 构建前端"
        echo " 15. 清理所有服务"
        echo "  0. 退出"
        echo ""
        echo -n "请选择 [0-15]: "

        read -r choice

        case $choice in
            1)
                check_environment
                build_images
                deploy_services
                health_check
                read -p "按回车继续..."
                ;;
            2)
                ./dev.sh
                read -p "按回车继续..."
                ;;
            3)
                $DOCKER_COMPOSE up -d
                health_check
                read -p "按回车继续..."
                ;;
            4)
                $DOCKER_COMPOSE stop
                read -p "按回车继续..."
                ;;
            5)
                $DOCKER_COMPOSE restart
                health_check
                read -p "按回车继续..."
                ;;
            6)
                update_code
                build_images
                deploy_services
                cleanup
                health_check
                read -p "按回车继续..."
                ;;
            7)
                show_status
                read -p "按回车继续..."
                ;;
            8)
                $DOCKER_COMPOSE logs -f
                ;;
            9)
                backup_database
                read -p "按回车继续..."
                ;;
            10)
                restore_database
                read -p "按回车继续..."
                ;;
            11)
                start_monitoring
                read -p "按回车继续..."
                ;;
            12)
                start_backup_service
                read -p "按回车继续..."
                ;;
            13)
                start_bot
                read -p "按回车继续..."
                ;;
            14)
                build_frontend
                read -p "按回车继续..."
                ;;
            15)
                echo -e "${RED}警告: 此操作将停止并删除所有容器、网络和匿名卷！${NC}"
                read -p "确认继续? (y/N): " confirm
                if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
                    $DOCKER_COMPOSE down -v
                    log_success "清理完成"
                fi
                read -p "按回车继续..."
                ;;
            0)
                echo "退出"
                exit 0
                ;;
            *)
                log_error "无效选项"
                sleep 1
                ;;
        esac
    done
}

# 主函数
main() {
  echo ""
  echo "=========================================="
  echo "  RoyalBot Portal 部署脚本 v${VERSION}"
  echo "=========================================="
  echo ""

  check_environment

  case $ACTION in
    update)
      update_code
      build_images
      deploy_services
      cleanup
      health_check
      ;;
    rollback)
      rollback
      health_check
      ;;
    status)
      show_status
      ;;
    logs)
      show_logs
      ;;
    build-fe)
      build_frontend
      ;;
    backup)
      backup_database
      ;;
    restore)
      restore_database
      ;;
    menu)
      show_interactive_menu
      ;;
    deploy)
      build_images
      deploy_services
      cleanup
      health_check
      ;;
  esac

  echo ""
  log_success "操作完成！"
  echo ""
}

# 执行主函数
main
