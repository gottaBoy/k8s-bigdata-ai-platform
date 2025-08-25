#!/bin/bash

# K8s大数据AI平台 - 快速开始脚本
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
    echo "║                K8s大数据AI平台 - 快速开始                    ║"
    echo "║                                                              ║"
    echo "║  本脚本将帮助您快速部署一个完整的大数据AI平台，包含：        ║"
    echo "║  • Flink 流处理引擎                                          ║"
    echo "║  • Doris 数据仓库                                            ║"
    echo "║  • MinIO 对象存储                                            ║"
    echo "║  • Kafka 消息队列                                            ║"
    echo "║  • Paimon 数据湖                                             ║"
    echo "║  • KubeFlow 机器学习平台                                      ║"
    echo "║  • Airflow 工作流调度                                        ║"
    echo "║  • Superset 数据可视化                                       ║"
    echo "║  • Prometheus + Grafana 监控                                 ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
}

# 检查前置条件
check_prerequisites() {
    log_info "检查前置条件..."
    
    # 检查kubectl
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl 未安装，请先安装 kubectl"
        exit 1
    fi
    
    # 检查helm
    if ! command -v helm &> /dev/null; then
        log_error "helm 未安装，请先安装 helm"
        exit 1
    fi
    
    # 检查K8s连接
    if ! kubectl cluster-info &> /dev/null; then
        log_error "无法连接到Kubernetes集群，请检查kubeconfig配置"
        exit 1
    fi
    
    # 检查集群资源
    NODE_COUNT=$(kubectl get nodes --no-headers | wc -l)
    if [ "$NODE_COUNT" -lt 2 ]; then
        log_warning "建议至少2个节点用于生产环境"
    fi
    
    log_success "前置条件检查通过"
}

# 选择部署模式
select_deployment_mode() {
    echo ""
    log_info "请选择部署模式："
    echo "1) 完整部署 (推荐) - 部署所有组件"
    echo "2) 最小部署 - 仅部署核心组件"
    echo "3) 自定义部署 - 选择特定组件"
    echo ""
    read -p "请输入选择 (1-3): " choice
    
    case $choice in
        1)
            DEPLOYMENT_MODE="full"
            log_info "选择完整部署模式"
            ;;
        2)
            DEPLOYMENT_MODE="minimal"
            log_info "选择最小部署模式"
            ;;
        3)
            DEPLOYMENT_MODE="custom"
            log_info "选择自定义部署模式"
            select_custom_components
            ;;
        *)
            log_error "无效选择，使用默认完整部署模式"
            DEPLOYMENT_MODE="full"
            ;;
    esac
}

# 选择自定义组件
select_custom_components() {
    echo ""
    log_info "请选择要部署的组件 (输入y/n):"
    
    read -p "部署监控体系 (Prometheus + Grafana)? [y/N]: " deploy_monitoring
    read -p "部署存储组件 (MinIO + Redis)? [y/N]: " deploy_storage
    read -p "部署消息队列 (Kafka)? [y/N]: " deploy_messaging
    read -p "部署Flink流处理? [y/N]: " deploy_flink
    read -p "部署Doris数据仓库? [y/N]: " deploy_doris
    read -p "部署KubeFlow机器学习? [y/N]: " deploy_kubeflow
    read -p "部署Airflow工作流? [y/N]: " deploy_airflow
    read -p "部署Superset可视化? [y/N]: " deploy_superset
    
    # 设置默认值
    deploy_monitoring=${deploy_monitoring:-n}
    deploy_storage=${deploy_storage:-n}
    deploy_messaging=${deploy_messaging:-n}
    deploy_flink=${deploy_flink:-n}
    deploy_doris=${deploy_doris:-n}
    deploy_kubeflow=${deploy_kubeflow:-n}
    deploy_airflow=${deploy_airflow:-n}
    deploy_superset=${deploy_superset:-n}
}

# 配置环境
configure_environment() {
    log_info "配置环境..."
    
    # 创建配置目录
    mkdir -p config
    
    # 检查是否存在配置文件
    if [ ! -f "config/env.sh" ]; then
        log_info "创建环境配置文件..."
        
        # 获取集群信息
        CLUSTER_NAME=$(kubectl config current-context)
        STORAGE_CLASS=$(kubectl get storageclass -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}')
        
        if [ -z "$STORAGE_CLASS" ]; then
            STORAGE_CLASS="default"
        fi
        
        # 创建配置文件
        cat > config/env.sh <<EOF
# K8s大数据AI平台环境配置

# 集群配置
CLUSTER_NAME="${CLUSTER_NAME}"
CLUSTER_DOMAIN="localhost"

# 存储配置
STORAGE_CLASS="${STORAGE_CLASS}"
STORAGE_SIZE="50Gi"

# 资源限制
CPU_LIMIT="2"
MEMORY_LIMIT="4Gi"
CPU_REQUEST="500m"
MEMORY_REQUEST="1Gi"

# 组件版本
FLINK_VERSION="1.17.1"
DORIS_VERSION="2.0.2"
MINIO_VERSION="2023.11.15"
KAFKA_VERSION="3.5.1"
PAIMON_VERSION="0.6.0"

# 监控配置
PROMETHEUS_RETENTION="7d"
GRAFANA_ADMIN_PASSWORD="admin123"

# 安全配置
ENABLE_TLS="false"
ENABLE_INGRESS="true"

# 部署模式
DEPLOYMENT_MODE="${DEPLOYMENT_MODE}"
EOF
        
        log_success "环境配置文件创建完成"
    else
        log_info "使用现有环境配置文件"
    fi
}

# 初始化环境
init_environment() {
    log_info "初始化环境..."
    
    # 运行初始化脚本
    if [ -f "scripts/init-environment.sh" ]; then
        chmod +x scripts/init-environment.sh
        ./scripts/init-environment.sh
    else
        log_error "初始化脚本不存在"
        exit 1
    fi
}

# 部署平台
deploy_platform() {
    log_info "开始部署平台..."
    
    # 运行部署脚本
    if [ -f "scripts/deploy-platform.sh" ]; then
        chmod +x scripts/deploy-platform.sh
        ./scripts/deploy-platform.sh
    else
        log_error "部署脚本不存在"
        exit 1
    fi
}

# 验证部署
verify_deployment() {
    log_info "验证部署状态..."
    
    # 检查关键Pod状态
    echo ""
    log_info "检查Pod状态..."
    kubectl get pods --all-namespaces | grep -E "(Running|Pending|Error)"
    
    # 检查服务状态
    echo ""
    log_info "检查服务状态..."
    kubectl get services --all-namespaces | grep -E "(ClusterIP|LoadBalancer)"
    
    # 检查Ingress状态
    echo ""
    log_info "检查Ingress状态..."
    kubectl get ingress --all-namespaces
    
    log_success "部署验证完成"
}

# 显示访问信息
show_access_info() {
    log_info "=== 平台访问信息 ==="
    
    # 获取Ingress IP
    INGRESS_IP=$(kubectl get service ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
    if [ -z "$INGRESS_IP" ]; then
        INGRESS_IP=$(kubectl get service ingress-nginx-controller -n ingress-nginx -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
    fi
    
    if [ -z "$INGRESS_IP" ]; then
        INGRESS_IP="localhost"
    fi
    
    echo ""
    echo "🌐 访问地址:"
    echo "   Grafana:     http://grafana.${INGRESS_IP}.nip.io"
    echo "   Superset:    http://superset.${INGRESS_IP}.nip.io"
    echo "   Airflow:     http://airflow.${INGRESS_IP}.nip.io"
    echo "   JupyterHub:  http://jupyter.${INGRESS_IP}.nip.io"
    echo ""
    echo "🔑 默认账号:"
    echo "   Grafana:     admin / admin123"
    echo "   Superset:    admin / admin123"
    echo "   Airflow:     admin / admin123"
    echo "   JupyterHub:  首次访问创建账号"
    echo ""
    echo "🔧 组件端口:"
    echo "   Doris FE:    ${INGRESS_IP}:8030"
    echo "   Doris BE:    ${INGRESS_IP}:8040"
    echo "   Flink JM:    ${INGRESS_IP}:8081"
    echo "   Kafka:       ${INGRESS_IP}:9092"
    echo "   MinIO:       ${INGRESS_IP}:9000"
    echo ""
    echo "📊 监控面板:"
    echo "   Prometheus:  http://prometheus.${INGRESS_IP}.nip.io"
    echo "   Jaeger:      http://jaeger.${INGRESS_IP}.nip.io"
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
    echo "   kubectl get pods --all-namespaces          # 查看所有Pod"
    echo "   kubectl logs -f <pod-name> -n <namespace>  # 查看Pod日志"
    echo "   kubectl describe pod <pod-name> -n <namespace>  # 查看Pod详情"
    echo "   kubectl top nodes                          # 查看节点资源使用"
    echo "   kubectl top pods                           # 查看Pod资源使用"
    echo ""
    echo "📖 更多文档:"
    echo "   - 详细部署指南: docs/"
    echo "   - 配置说明: config/"
    echo "   - 使用示例: examples/"
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
    
    # 选择部署模式
    select_deployment_mode
    
    # 配置环境
    configure_environment
    
    # 初始化环境
    init_environment
    
    # 部署平台
    deploy_platform
    
    # 验证部署
    verify_deployment
    
    # 显示访问信息
    show_access_info
    
    # 显示使用指南
    show_usage_guide
    
    log_success "🎉 K8s大数据AI平台部署完成！"
    echo ""
    log_info "💡 提示: 如果遇到问题，请查看日志或运行 ./scripts/troubleshoot.sh"
    echo ""
}

# 执行主函数
main "$@" 