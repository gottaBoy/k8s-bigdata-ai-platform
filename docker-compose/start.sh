#!/bin/bash

# Docker Compose启动脚本
# 作者: 云原生专家
# 版本: 1.0.0

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# 显示欢迎信息
show_welcome() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║            K8s大数据AI平台 - Docker Compose本地测试          ║"
    echo "║                                                              ║"
    echo "║  本脚本将启动一个完整的大数据AI平台本地测试环境，包含：      ║"
    echo "║  • MinIO 对象存储                                            ║"
    echo "║  • Kafka 消息队列                                            ║"
    echo "║  • Doris 数据仓库                                            ║"
    echo "║  • Flink 流处理引擎                                          ║"
    echo "║  • Redis 缓存                                                ║"
    echo "║  • Prometheus + Grafana 监控                                 ║"
    echo "║  • Airflow 工作流调度                                        ║"
    echo "║  • Superset 数据可视化                                       ║"
    echo "║  • JupyterHub 开发环境                                       ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
}

# 检查Docker和Docker Compose
check_prerequisites() {
    log_info "检查前置条件..."
    
    # 检查Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker未安装，请先安装Docker"
        exit 1
    fi
    
    # 检查Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose未安装，请先安装Docker Compose"
        exit 1
    fi
    
    # 检查Docker服务
    if ! docker info &> /dev/null; then
        log_error "Docker服务未启动，请先启动Docker"
        exit 1
    fi
    
    log_success "前置条件检查通过"
}

# 选择启动模式
select_startup_mode() {
    echo ""
    log_info "请选择启动模式："
    echo "1) 完整启动 (推荐) - 启动所有组件"
    echo "2) 最小启动 - 仅启动核心组件"
    echo "3) 自定义启动 - 选择特定组件"
    echo ""
    read -p "请输入选择 (1-3): " choice
    
    case $choice in
        1)
            STARTUP_MODE="full"
            log_info "选择完整启动模式"
            ;;
        2)
            STARTUP_MODE="minimal"
            log_info "选择最小启动模式"
            ;;
        3)
            STARTUP_MODE="custom"
            log_info "选择自定义启动模式"
            select_custom_services
            ;;
        *)
            log_error "无效选择，使用默认完整启动模式"
            STARTUP_MODE="full"
            ;;
    esac
}

# 选择自定义服务
select_custom_services() {
    echo ""
    log_info "请选择要启动的服务 (输入y/n):"
    
    read -p "启动存储服务 (MinIO + Redis)? [y/N]: " start_storage
    read -p "启动消息队列 (Kafka)? [y/N]: " start_messaging
    read -p "启动数据仓库 (Doris)? [y/N]: " start_database
    read -p "启动流处理 (Flink)? [y/N]: " start_streaming
    read -p "启动监控 (Prometheus + Grafana)? [y/N]: " start_monitoring
    read -p "启动工作流 (Airflow)? [y/N]: " start_workflow
    read -p "启动可视化 (Superset)? [y/N]: " start_visualization
    read -p "启动开发环境 (JupyterHub)? [y/N]: " start_development
    
    # 设置默认值
    start_storage=${start_storage:-n}
    start_messaging=${start_messaging:-n}
    start_database=${start_database:-n}
    start_streaming=${start_streaming:-n}
    start_monitoring=${start_monitoring:-n}
    start_workflow=${start_workflow:-n}
    start_visualization=${start_visualization:-n}
    start_development=${start_development:-n}
}

# 启动服务
start_services() {
    log_info "启动大数据AI平台服务..."
    
    # 创建必要的目录
    mkdir -p config/prometheus config/grafana/provisioning/datasources config/grafana/provisioning/dashboards config/superset config/jupyterhub
    
    # 根据模式启动服务
    case $STARTUP_MODE in
        "full")
            log_info "启动所有服务..."
            docker-compose up -d
            ;;
        "minimal")
            log_info "启动核心服务..."
            docker-compose up -d minio redis kafka doris-fe doris-be flink-jobmanager flink-taskmanager prometheus grafana
            ;;
        "custom")
            log_info "启动自定义服务..."
            # 这里可以根据用户选择启动特定服务
            docker-compose up -d
            ;;
    esac
    
    log_success "服务启动完成"
}

# 等待服务就绪
wait_for_services() {
    log_info "等待服务就绪..."
    
    # 等待关键服务启动
    sleep 30
    
    # 检查服务状态
    log_info "检查服务状态..."
    docker-compose ps
    
    log_success "服务状态检查完成"
}

# 初始化数据
initialize_data() {
    log_info "初始化平台数据..."
    
    # 给脚本执行权限
    chmod +x scripts/init-data.sh
    
    # 运行数据初始化脚本
    ./scripts/init-data.sh
    
    log_success "数据初始化完成"
}

# 显示访问信息
show_access_info() {
    log_info "=== 平台访问信息 ==="
    echo ""
    echo "🌐 服务访问地址:"
    echo "  MinIO Console:     http://localhost:9001 (admin/minio123)"
    echo "  Kafka UI:          http://localhost:8082"
    echo "  Doris FE:          http://localhost:8030"
    echo "  Doris BE:          http://localhost:8040"
    echo "  Flink JobManager:  http://localhost:8081"
    echo "  Prometheus:        http://localhost:9090"
    echo "  Grafana:           http://localhost:3000 (admin/admin123)"
    echo "  Airflow:           http://localhost:8080 (admin/admin123)"
    echo "  Superset:          http://localhost:8088 (admin/admin123)"
    echo "  JupyterHub:        http://localhost:8000 (admin/jupyter123)"
    echo ""
    echo "🔧 连接信息:"
    echo "  MinIO:             localhost:9000 (admin/minio123)"
    echo "  Kafka:             localhost:9092"
    echo "  Doris:             localhost:9030 (root/root)"
    echo "  Redis:             localhost:6379 (redis123)"
    echo "  PostgreSQL:        localhost:5432 (airflow/airflow123)"
    echo ""
    echo "📊 监控面板:"
    echo "  Grafana:           http://localhost:3000"
    echo "  Prometheus:        http://localhost:9090"
    echo "  Kafka UI:          http://localhost:8082"
    echo ""
}

# 显示使用指南
show_usage_guide() {
    log_info "=== 使用指南 ==="
    echo ""
    echo "📚 快速开始:"
    echo "   1. 访问 Grafana 查看系统监控"
    echo "   2. 访问 Superset 创建数据可视化"
    echo "   3. 访问 Airflow 创建数据管道"
    echo "   4. 访问 JupyterHub 进行数据分析和机器学习"
    echo ""
    echo "🔧 常用命令:"
    echo "   docker-compose ps                    # 查看服务状态"
    echo "   docker-compose logs <service>        # 查看服务日志"
    echo "   docker-compose stop                  # 停止所有服务"
    echo "   docker-compose restart <service>     # 重启特定服务"
    echo "   docker-compose down                  # 停止并删除所有容器"
    echo ""
    echo "📖 更多文档:"
    echo "   - 使用指南: ../USAGE.md"
    echo "   - 配置说明: config/"
    echo "   - 使用示例: ../examples/"
    echo ""
}

# 清理函数
cleanup() {
    log_info "清理临时文件..."
    # 可以在这里添加清理逻辑
}

# 主函数
main() {
    # 设置错误处理
    trap cleanup EXIT
    
    # 显示欢迎信息
    show_welcome
    
    # 检查前置条件
    check_prerequisites
    
    # 选择启动模式
    select_startup_mode
    
    # 启动服务
    start_services
    
    # 等待服务就绪
    wait_for_services
    
    # 初始化数据
    initialize_data
    
    # 显示访问信息
    show_access_info
    
    # 显示使用指南
    show_usage_guide
    
    log_success "🎉 大数据AI平台本地测试环境启动完成！"
    echo ""
    log_info "💡 提示: 使用 'docker-compose stop' 停止服务，'docker-compose down' 清理环境"
    echo ""
}

# 执行主函数
main "$@" 