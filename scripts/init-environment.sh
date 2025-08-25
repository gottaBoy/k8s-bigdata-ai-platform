#!/bin/bash

# K8s大数据AI平台 - 环境初始化脚本
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

# 检查命令是否存在
check_command() {
    if ! command -v $1 &> /dev/null; then
        log_error "$1 未安装，请先安装 $1"
        exit 1
    fi
}

# 检查K8s集群连接
check_k8s_connection() {
    log_info "检查Kubernetes集群连接..."
    
    if ! kubectl cluster-info &> /dev/null; then
        log_error "无法连接到Kubernetes集群，请检查kubeconfig配置"
        exit 1
    fi
    
    # 检查集群版本
    K8S_VERSION=$(kubectl version --short --client | cut -d' ' -f3 | cut -d'v' -f2)
    log_info "Kubernetes版本: $K8S_VERSION"
    
    # 检查节点状态
    log_info "检查节点状态..."
    kubectl get nodes
    
    # 检查存储类
    log_info "检查存储类..."
    kubectl get storageclass
    
    # 检查默认存储类
    DEFAULT_SC=$(kubectl get storageclass -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}')
    if [ -z "$DEFAULT_SC" ]; then
        log_warning "未找到默认存储类，请手动设置"
    else
        log_success "默认存储类: $DEFAULT_SC"
    fi
}

# 检查Helm
check_helm() {
    log_info "检查Helm安装..."
    
    if ! helm version &> /dev/null; then
        log_error "Helm未安装，请先安装Helm"
        exit 1
    fi
    
    HELM_VERSION=$(helm version --short)
    log_success "Helm版本: $HELM_VERSION"
    
    # 添加必要的Helm仓库
    log_info "添加Helm仓库..."
    helm repo add bitnami https://charts.bitnami.com/bitnami
    helm repo add apache-airflow https://airflow.apache.org/charts
    helm repo add grafana https://grafana.github.io/helm-charts
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo add jetstack https://charts.jetstack.io
    helm repo add kubeflow https://github.com/kubeflow/manifests/raw/master/kustomize
    helm repo update
}

# 创建命名空间
create_namespaces() {
    log_info "创建必要的命名空间..."
    
    NAMESPACES=(
        "monitoring"
        "logging"
        "bigdata"
        "ai-ml"
        "data-pipeline"
        "storage"
        "security"
    )
    
    for ns in "${NAMESPACES[@]}"; do
        if ! kubectl get namespace $ns &> /dev/null; then
            kubectl create namespace $ns
            log_success "创建命名空间: $ns"
        else
            log_info "命名空间已存在: $ns"
        fi
    done
}

# 安装CRD
install_crds() {
    log_info "安装自定义资源定义(CRD)..."
    
    # 安装Cert-Manager CRD
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.12.0/cert-manager.crds.yaml
    
    # 安装Istio CRD
    kubectl apply -f https://raw.githubusercontent.com/istio/istio/1.18.0/manifests/charts/base/crds/crd-all.gen.yaml
    
    # 安装KubeFlow CRD
    kubectl apply -f https://raw.githubusercontent.com/kubeflow/manifests/master/kustomize/application/crds/base/crds.yaml
    
    log_success "CRD安装完成"
}

# 配置RBAC
setup_rbac() {
    log_info "配置RBAC权限..."
    
    # 创建集群角色
    cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: bigdata-platform-admin
rules:
- apiGroups: [""]
  resources: ["pods", "services", "endpoints", "persistentvolumeclaims", "events", "configmaps", "secrets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["apps"]
  resources: ["deployments", "daemonsets", "replicasets", "statefulsets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["networking.k8s.io"]
  resources: ["ingresses", "networkpolicies"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["storage.k8s.io"]
  resources: ["storageclasses", "persistentvolumes"]
  verbs: ["get", "list", "watch"]
EOF

    # 创建集群角色绑定
    cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: bigdata-platform-admin-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: bigdata-platform-admin
subjects:
- kind: ServiceAccount
  name: default
  namespace: bigdata
- kind: ServiceAccount
  name: default
  namespace: ai-ml
- kind: ServiceAccount
  name: default
  namespace: data-pipeline
EOF

    log_success "RBAC配置完成"
}

# 配置网络策略
setup_network_policies() {
    log_info "配置网络策略..."
    
    # 创建默认拒绝策略
    cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: bigdata
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
EOF

    cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: ai-ml
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
EOF

    log_success "网络策略配置完成"
}

# 检查资源配额
check_resource_quota() {
    log_info "检查集群资源..."
    
    # 获取节点资源信息
    NODE_COUNT=$(kubectl get nodes --no-headers | wc -l)
    TOTAL_CPU=$(kubectl get nodes -o jsonpath='{.items[*].status.allocatable.cpu}' | tr ' ' '\n' | awk '{sum += $1} END {print sum}')
    TOTAL_MEMORY=$(kubectl get nodes -o jsonpath='{.items[*].status.allocatable.memory}' | tr ' ' '\n' | awk '{sum += $1} END {print sum}')
    
    log_info "节点数量: $NODE_COUNT"
    log_info "总CPU: $TOTAL_CPU"
    log_info "总内存: ${TOTAL_MEMORY}Ki"
    
    # 检查资源是否足够
    if [ "$NODE_COUNT" -lt 3 ]; then
        log_warning "建议至少3个节点用于生产环境"
    fi
    
    # 检查CPU和内存是否足够
    if [ "$TOTAL_CPU" -lt 16 ]; then
        log_warning "建议总CPU至少16核"
    fi
    
    if [ "$TOTAL_MEMORY" -lt 33554432 ]; then  # 32GB in KiB
        log_warning "建议总内存至少32GB"
    fi
}

# 创建配置文件
create_config_files() {
    log_info "创建配置文件..."
    
    # 创建配置目录
    mkdir -p ../config/{flink,doris,minio,kafka,monitoring}
    
    # 创建环境变量模板
    cat > ../config/env.template <<EOF
# K8s大数据AI平台环境配置

# 集群配置
CLUSTER_NAME="bigdata-platform"
CLUSTER_DOMAIN="your-domain.com"

# 存储配置
STORAGE_CLASS="default"
STORAGE_SIZE="100Gi"

# 资源限制
CPU_LIMIT="4"
MEMORY_LIMIT="8Gi"
CPU_REQUEST="1"
MEMORY_REQUEST="2Gi"

# 组件版本
FLINK_VERSION="1.17.1"
DORIS_VERSION="2.0.2"
MINIO_VERSION="2023.11.15"
KAFKA_VERSION="3.5.1"
PAIMON_VERSION="0.6.0"

# 监控配置
PROMETHEUS_RETENTION="15d"
GRAFANA_ADMIN_PASSWORD="admin123"

# 安全配置
ENABLE_TLS="true"
ENABLE_INGRESS="true"
EOF

    log_success "配置文件创建完成"
}

# 主函数
main() {
    log_info "开始初始化K8s大数据AI平台环境..."
    
    # 检查必要命令
    check_command kubectl
    check_command helm
    
    # 检查K8s连接
    check_k8s_connection
    
    # 检查Helm
    check_helm
    
    # 检查资源配额
    check_resource_quota
    
    # 创建命名空间
    create_namespaces
    
    # 安装CRD
    install_crds
    
    # 配置RBAC
    setup_rbac
    
    # 配置网络策略
    setup_network_policies
    
    # 创建配置文件
    create_config_files
    
    log_success "环境初始化完成！"
    log_info "下一步：运行 ./scripts/deploy-platform.sh 部署平台组件"
}

# 执行主函数
main "$@" 