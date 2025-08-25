#!/bin/bash

# K8s大数据AI平台 - 故障排查脚本
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

# 显示帮助信息
show_help() {
    echo ""
    echo "K8s大数据AI平台 - 故障排查工具"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -a, --all              执行所有检查"
    echo "  -n, --nodes            检查节点状态"
    echo "  -p, --pods             检查Pod状态"
    echo "  -s, --services         检查服务状态"
    echo "  -e, --events           检查事件"
    echo "  -l, --logs             查看组件日志"
    echo "  -r, --resources        检查资源使用"
    echo "  -n, --network          检查网络连接"
    echo "  -c, --component <name> 检查特定组件"
    echo "  -h, --help             显示此帮助信息"
    echo ""
    echo "组件名称:"
    echo "  flink, doris, minio, kafka, kubeflow, airflow, superset, monitoring"
    echo ""
}

# 检查节点状态
check_nodes() {
    log_info "检查节点状态..."
    
    echo ""
    echo "=== 节点状态 ==="
    kubectl get nodes -o wide
    
    echo ""
    echo "=== 节点资源使用 ==="
    kubectl top nodes 2>/dev/null || echo "Metrics Server未安装或不可用"
    
    echo ""
    echo "=== 节点事件 ==="
    kubectl get events --field-selector involvedObject.kind=Node --sort-by='.lastTimestamp' | tail -10
    
    # 检查节点问题
    NOT_READY_NODES=$(kubectl get nodes --no-headers | grep -v "Ready" | wc -l)
    if [ "$NOT_READY_NODES" -gt 0 ]; then
        log_error "发现 $NOT_READY_NODES 个节点状态异常"
        kubectl get nodes --no-headers | grep -v "Ready"
    else
        log_success "所有节点状态正常"
    fi
}

# 检查Pod状态
check_pods() {
    log_info "检查Pod状态..."
    
    echo ""
    echo "=== 所有Pod状态 ==="
    kubectl get pods --all-namespaces | grep -E "(Pending|Error|CrashLoopBackOff|ImagePullBackOff|ErrImagePull)"
    
    echo ""
    echo "=== 命名空间Pod统计 ==="
    for ns in monitoring bigdata ai-ml data-pipeline storage; do
        if kubectl get namespace $ns &>/dev/null; then
            TOTAL=$(kubectl get pods -n $ns --no-headers 2>/dev/null | wc -l)
            RUNNING=$(kubectl get pods -n $ns --no-headers 2>/dev/null | grep "Running" | wc -l)
            echo "$ns: $RUNNING/$TOTAL Running"
        fi
    done
    
    # 检查问题Pod
    PROBLEM_PODS=$(kubectl get pods --all-namespaces --no-headers | grep -E "(Pending|Error|CrashLoopBackOff|ImagePullBackOff|ErrImagePull)" | wc -l)
    if [ "$PROBLEM_PODS" -gt 0 ]; then
        log_error "发现 $PROBLEM_PODS 个问题Pod"
    else
        log_success "所有Pod状态正常"
    fi
}

# 检查服务状态
check_services() {
    log_info "检查服务状态..."
    
    echo ""
    echo "=== 服务状态 ==="
    kubectl get services --all-namespaces | grep -E "(LoadBalancer|NodePort)"
    
    echo ""
    echo "=== 端点状态 ==="
    kubectl get endpoints --all-namespaces | grep -v "None"
    
    # 检查服务连接
    echo ""
    echo "=== 服务连接测试 ==="
    for ns in bigdata storage; do
        if kubectl get namespace $ns &>/dev/null; then
            kubectl get services -n $ns --no-headers | while read name type clusterip externalip ports age; do
                if [ "$type" = "ClusterIP" ] && [ "$clusterip" != "None" ]; then
                    echo "测试 $ns/$name ($clusterip)"
                    kubectl run -it --rm --restart=Never --image=busybox:1.28 test-$name-$ns -- nslookup $name.$ns.svc.cluster.local 2>/dev/null || echo "  DNS解析失败"
                fi
            done
        fi
    done
}

# 检查事件
check_events() {
    log_info "检查集群事件..."
    
    echo ""
    echo "=== 最近事件 ==="
    kubectl get events --all-namespaces --sort-by='.lastTimestamp' | tail -20
    
    echo ""
    echo "=== 错误事件 ==="
    kubectl get events --all-namespaces --sort-by='.lastTimestamp' | grep -i "error\|failed\|backoff" | tail -10
    
    echo ""
    echo "=== 警告事件 ==="
    kubectl get events --all-namespaces --sort-by='.lastTimestamp' | grep -i "warning" | tail -10
}

# 查看组件日志
check_logs() {
    log_info "检查组件日志..."
    
    echo ""
    echo "=== 关键组件日志 ==="
    
    # 检查Flink日志
    if kubectl get pods -n bigdata -l app=flink-jobmanager &>/dev/null; then
        echo "Flink JobManager日志:"
        kubectl logs -n bigdata -l app=flink-jobmanager --tail=10 2>/dev/null || echo "  无法获取日志"
    fi
    
    # 检查Doris日志
    if kubectl get pods -n bigdata -l app=doris-fe &>/dev/null; then
        echo "Doris FE日志:"
        kubectl logs -n bigdata -l app=doris-fe --tail=10 2>/dev/null || echo "  无法获取日志"
    fi
    
    # 检查MinIO日志
    if kubectl get pods -n storage -l app.kubernetes.io/name=minio &>/dev/null; then
        echo "MinIO日志:"
        kubectl logs -n storage -l app.kubernetes.io/name=minio --tail=10 2>/dev/null || echo "  无法获取日志"
    fi
    
    # 检查Kafka日志
    if kubectl get pods -n bigdata -l app.kubernetes.io/name=kafka &>/dev/null; then
        echo "Kafka日志:"
        kubectl logs -n bigdata -l app.kubernetes.io/name=kafka --tail=10 2>/dev/null || echo "  无法获取日志"
    fi
}

# 检查资源使用
check_resources() {
    log_info "检查资源使用..."
    
    echo ""
    echo "=== 节点资源使用 ==="
    kubectl top nodes 2>/dev/null || echo "Metrics Server未安装"
    
    echo ""
    echo "=== Pod资源使用 ==="
    kubectl top pods --all-namespaces 2>/dev/null || echo "Metrics Server未安装"
    
    echo ""
    echo "=== 资源配额 ==="
    kubectl get resourcequota --all-namespaces 2>/dev/null || echo "未配置资源配额"
    
    echo ""
    echo "=== 持久化卷 ==="
    kubectl get pv,pvc --all-namespaces
    
    # 检查资源不足
    echo ""
    echo "=== 资源不足检查 ==="
    kubectl get events --all-namespaces | grep -i "insufficient\|outofmemory\|outofcpu" | tail -5
}

# 检查网络连接
check_network() {
    log_info "检查网络连接..."
    
    echo ""
    echo "=== 网络策略 ==="
    kubectl get networkpolicies --all-namespaces
    
    echo ""
    echo "=== 服务DNS解析 ==="
    kubectl run -it --rm --restart=Never --image=busybox:1.28 dns-test -- nslookup kubernetes.default 2>/dev/null || echo "DNS解析失败"
    
    echo ""
    echo "=== 跨命名空间连接测试 ==="
    # 测试bigdata到storage的连接
    kubectl run -it --rm --restart=Never --image=busybox:1.28 network-test -- nslookup minio.storage.svc.cluster.local 2>/dev/null || echo "MinIO连接失败"
    
    # 测试bigdata到bigdata的连接
    kubectl run -it --rm --restart=Never --image=busybox:1.28 network-test -- nslookup kafka.bigdata.svc.cluster.local 2>/dev/null || echo "Kafka连接失败"
}

# 检查特定组件
check_component() {
    local component=$1
    
    log_info "检查组件: $component"
    
    case $component in
        flink)
            echo ""
            echo "=== Flink状态 ==="
            kubectl get flinkdeployments -n bigdata 2>/dev/null || echo "Flink未部署"
            kubectl get pods -n bigdata -l app=flink-jobmanager 2>/dev/null || echo "Flink JobManager未运行"
            kubectl get pods -n bigdata -l app=flink-taskmanager 2>/dev/null || echo "Flink TaskManager未运行"
            kubectl get services -n bigdata -l app=flink-jobmanager 2>/dev/null || echo "Flink服务未创建"
            ;;
        doris)
            echo ""
            echo "=== Doris状态 ==="
            kubectl get statefulset -n bigdata doris-fe 2>/dev/null || echo "Doris FE未部署"
            kubectl get statefulset -n bigdata doris-be 2>/dev/null || echo "Doris BE未部署"
            kubectl get pods -n bigdata -l app=doris-fe 2>/dev/null || echo "Doris FE未运行"
            kubectl get pods -n bigdata -l app=doris-be 2>/dev/null || echo "Doris BE未运行"
            kubectl get services -n bigdata -l app=doris-fe 2>/dev/null || echo "Doris服务未创建"
            ;;
        minio)
            echo ""
            echo "=== MinIO状态 ==="
            kubectl get deployment -n storage minio 2>/dev/null || echo "MinIO未部署"
            kubectl get pods -n storage -l app.kubernetes.io/name=minio 2>/dev/null || echo "MinIO未运行"
            kubectl get services -n storage -l app.kubernetes.io/name=minio 2>/dev/null || echo "MinIO服务未创建"
            ;;
        kafka)
            echo ""
            echo "=== Kafka状态 ==="
            kubectl get statefulset -n bigdata kafka 2>/dev/null || echo "Kafka未部署"
            kubectl get pods -n bigdata -l app.kubernetes.io/name=kafka 2>/dev/null || echo "Kafka未运行"
            kubectl get services -n bigdata -l app.kubernetes.io/name=kafka 2>/dev/null || echo "Kafka服务未创建"
            ;;
        kubeflow)
            echo ""
            echo "=== KubeFlow状态 ==="
            kubectl get pods -n ai-ml -l app.kubernetes.io/part-of=kubeflow 2>/dev/null || echo "KubeFlow未部署"
            kubectl get services -n ai-ml -l app.kubernetes.io/part-of=kubeflow 2>/dev/null || echo "KubeFlow服务未创建"
            ;;
        airflow)
            echo ""
            echo "=== Airflow状态 ==="
            kubectl get deployment -n data-pipeline airflow-webserver 2>/dev/null || echo "Airflow未部署"
            kubectl get pods -n data-pipeline -l app.kubernetes.io/name=airflow 2>/dev/null || echo "Airflow未运行"
            kubectl get services -n data-pipeline -l app.kubernetes.io/name=airflow 2>/dev/null || echo "Airflow服务未创建"
            ;;
        superset)
            echo ""
            echo "=== Superset状态 ==="
            kubectl get deployment -n bigdata superset 2>/dev/null || echo "Superset未部署"
            kubectl get pods -n bigdata -l app.kubernetes.io/name=superset 2>/dev/null || echo "Superset未运行"
            kubectl get services -n bigdata -l app.kubernetes.io/name=superset 2>/dev/null || echo "Superset服务未创建"
            ;;
        monitoring)
            echo ""
            echo "=== 监控状态 ==="
            kubectl get pods -n monitoring -l app=prometheus 2>/dev/null || echo "Prometheus未部署"
            kubectl get pods -n monitoring -l app=grafana 2>/dev/null || echo "Grafana未部署"
            kubectl get services -n monitoring -l app=prometheus 2>/dev/null || echo "Prometheus服务未创建"
            kubectl get services -n monitoring -l app=grafana 2>/dev/null || echo "Grafana服务未创建"
            ;;
        *)
            log_error "未知组件: $component"
            echo "支持的组件: flink, doris, minio, kafka, kubeflow, airflow, superset, monitoring"
            ;;
    esac
}

# 生成诊断报告
generate_report() {
    log_info "生成诊断报告..."
    
    REPORT_FILE="diagnostic-report-$(date +%Y%m%d-%H%M%S).txt"
    
    {
        echo "K8s大数据AI平台诊断报告"
        echo "生成时间: $(date)"
        echo "=================================="
        echo ""
        
        echo "集群信息:"
        kubectl cluster-info
        echo ""
        
        echo "节点状态:"
        kubectl get nodes -o wide
        echo ""
        
        echo "命名空间:"
        kubectl get namespaces
        echo ""
        
        echo "Pod状态:"
        kubectl get pods --all-namespaces
        echo ""
        
        echo "服务状态:"
        kubectl get services --all-namespaces
        echo ""
        
        echo "事件:"
        kubectl get events --all-namespaces --sort-by='.lastTimestamp' | tail -20
        echo ""
        
        echo "资源使用:"
        kubectl top nodes 2>/dev/null || echo "Metrics Server未安装"
        kubectl top pods --all-namespaces 2>/dev/null || echo "Metrics Server未安装"
        echo ""
        
    } > "$REPORT_FILE"
    
    log_success "诊断报告已生成: $REPORT_FILE"
}

# 主函数
main() {
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -a|--all)
                check_nodes
                check_pods
                check_services
                check_events
                check_logs
                check_resources
                check_network
                generate_report
                exit 0
                ;;
            -n|--nodes)
                check_nodes
                ;;
            -p|--pods)
                check_pods
                ;;
            -s|--services)
                check_services
                ;;
            -e|--events)
                check_events
                ;;
            -l|--logs)
                check_logs
                ;;
            -r|--resources)
                check_resources
                ;;
            --network)
                check_network
                ;;
            -c|--component)
                if [ -n "$2" ]; then
                    check_component "$2"
                    shift
                else
                    log_error "请指定组件名称"
                    exit 1
                fi
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
        shift
    done
    
    # 如果没有参数，显示帮助
    if [ $# -eq 0 ]; then
        show_help
        exit 0
    fi
}

# 执行主函数
main "$@" 