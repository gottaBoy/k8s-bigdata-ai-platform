#!/bin/bash

# 健康检查脚本
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

# 检查服务健康状态
check_service_health() {
    local service=$1
    local port=$2
    local endpoint=$3
    local description=$4
    
    log_info "检查 $description 健康状态..."
    
    if curl -s -f "http://localhost:$port$endpoint" > /dev/null 2>&1; then
        log_success "$description 健康检查通过"
        return 0
    else
        log_error "$description 健康检查失败"
        return 1
    fi
}

# 检查容器状态
check_container_status() {
    local container=$1
    local description=$2
    
    log_info "检查 $description 容器状态..."
    
    if docker ps --format "table {{.Names}}\t{{.Status}}" | grep -q "$container.*Up"; then
        log_success "$description 容器运行正常"
        return 0
    else
        log_error "$description 容器状态异常"
        return 1
    fi
}

# 检查端口监听
check_port_listening() {
    local port=$1
    local description=$2
    
    log_info "检查 $description 端口监听..."
    
    if netstat -tuln 2>/dev/null | grep -q ":$port "; then
        log_success "$description 端口 $port 监听正常"
        return 0
    else
        log_error "$description 端口 $port 未监听"
        return 1
    fi
}

# 检查数据连接
check_data_connection() {
    local service=$1
    local description=$2
    
    log_info "检查 $description 数据连接..."
    
    case $service in
        "minio")
            if docker exec minio-client mc ls myminio/ > /dev/null 2>&1; then
                log_success "$description 数据连接正常"
                return 0
            else
                log_error "$description 数据连接失败"
                return 1
            fi
            ;;
        "kafka")
            if docker exec kafka kafka-topics --list --bootstrap-server localhost:9092 > /dev/null 2>&1; then
                log_success "$description 数据连接正常"
                return 0
            else
                log_error "$description 数据连接失败"
                return 1
            fi
            ;;
        "doris")
            if docker exec doris-fe mysql -h localhost -P 9030 -u root -e "SHOW DATABASES;" > /dev/null 2>&1; then
                log_success "$description 数据连接正常"
                return 0
            else
                log_error "$description 数据连接失败"
                return 1
            fi
            ;;
        "redis")
            if docker exec redis redis-cli -a redis123 ping > /dev/null 2>&1; then
                log_success "$description 数据连接正常"
                return 0
            else
                log_error "$description 数据连接失败"
                return 1
            fi
            ;;
        *)
            log_warning "未知服务: $service"
            return 1
            ;;
    esac
}

# 检查Flink作业状态
check_flink_jobs() {
    log_info "检查Flink作业状态..."
    
    # 检查Flink Web UI
    if curl -s "http://localhost:8081" > /dev/null 2>&1; then
        log_success "Flink Web UI 可访问"
        
        # 获取作业数量
        job_count=$(curl -s "http://localhost:8081/jobs" | grep -c "RUNNING" || echo "0")
        log_info "当前运行中的Flink作业数量: $job_count"
        
        return 0
    else
        log_error "Flink Web UI 无法访问"
        return 1
    fi
}

# 检查Paimon状态
check_paimon_status() {
    log_info "检查Paimon数据湖状态..."
    
    # 检查Paimon Catalog服务
    if docker ps | grep -q "paimon-catalog"; then
        log_success "Paimon Catalog 服务运行正常"
        
        # 检查Paimon JAR包
        if docker exec paimon-catalog ls /opt/flink/lib/paimon-flink-*.jar > /dev/null 2>&1; then
            log_success "Paimon JAR包已安装"
        else
            log_warning "Paimon JAR包未找到"
        fi
        
        return 0
    else
        log_error "Paimon Catalog 服务未运行"
        return 1
    fi
}

# 检查资源使用情况
check_resource_usage() {
    log_info "检查系统资源使用情况..."
    
    # CPU使用率
    cpu_usage=$(top -l 1 | grep "CPU usage" | awk '{print $3}' | sed 's/%//')
    log_info "CPU使用率: ${cpu_usage}%"
    
    # 内存使用率
    memory_usage=$(vm_stat | grep "Pages free" | awk '{print $3}' | sed 's/\.//')
    log_info "可用内存页数: $memory_usage"
    
    # 磁盘使用率
    disk_usage=$(df -h / | tail -1 | awk '{print $5}' | sed 's/%//')
    log_info "磁盘使用率: ${disk_usage}%"
    
    # Docker容器资源使用
    log_info "Docker容器资源使用情况:"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"
}

# 检查网络连接
check_network_connectivity() {
    log_info "检查网络连接..."
    
    # 检查容器间网络
    if docker network ls | grep -q "bigdata-network"; then
        log_success "Docker网络 bigdata-network 存在"
        
        # 检查网络中的容器
        container_count=$(docker network inspect bigdata-network --format='{{len .Containers}}')
        log_info "网络中的容器数量: $container_count"
        
        return 0
    else
        log_error "Docker网络 bigdata-network 不存在"
        return 1
    fi
}

# 检查日志错误
check_log_errors() {
    log_info "检查服务日志错误..."
    
    # 检查最近1小时的错误日志
    services=("minio" "kafka" "doris-fe" "doris-be" "flink-jobmanager" "flink-taskmanager" "prometheus" "grafana" "airflow-webserver" "superset" "jupyterhub")
    
    for service in "${services[@]}"; do
        if docker ps | grep -q "$service"; then
            error_count=$(docker logs --since 1h "$service" 2>&1 | grep -i "error\|exception\|failed" | wc -l)
            if [ "$error_count" -gt 0 ]; then
                log_warning "$service 最近1小时有 $error_count 个错误"
            else
                log_success "$service 最近1小时无错误"
            fi
        fi
    done
}

# 生成健康报告
generate_health_report() {
    local report_file="/tmp/health_report_$(date +%Y%m%d_%H%M%S).txt"
    
    log_info "生成健康检查报告: $report_file"
    
    {
        echo "=== 大数据AI平台健康检查报告 ==="
        echo "检查时间: $(date)"
        echo "检查主机: $(hostname)"
        echo ""
        
        echo "=== 容器状态 ==="
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        echo ""
        
        echo "=== 服务健康状态 ==="
        echo "MinIO: $(curl -s -o /dev/null -w "%{http_code}" http://localhost:9001 || echo "FAILED")"
        echo "Kafka UI: $(curl -s -o /dev/null -w "%{http_code}" http://localhost:8082 || echo "FAILED")"
        echo "Doris FE: $(curl -s -o /dev/null -w "%{http_code}" http://localhost:8030 || echo "FAILED")"
        echo "Flink: $(curl -s -o /dev/null -w "%{http_code}" http://localhost:8081 || echo "FAILED")"
        echo "Prometheus: $(curl -s -o /dev/null -w "%{http_code}" http://localhost:9090 || echo "FAILED")"
        echo "Grafana: $(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 || echo "FAILED")"
        echo "Airflow: $(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080 || echo "FAILED")"
        echo "Superset: $(curl -s -o /dev/null -w "%{http_code}" http://localhost:8088 || echo "FAILED")"
        echo "JupyterHub: $(curl -s -o /dev/null -w "%{http_code}" http://localhost:8000 || echo "FAILED")"
        echo ""
        
        echo "=== 资源使用情况 ==="
        docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"
        echo ""
        
        echo "=== 网络连接 ==="
        docker network ls
        echo ""
        
        echo "=== 端口监听 ==="
        netstat -tuln | grep -E ":(9000|9001|8082|8030|8040|8081|9090|3000|8080|8088|8000) "
        echo ""
        
    } > "$report_file"
    
    log_success "健康检查报告已生成: $report_file"
    echo "报告内容:"
    cat "$report_file"
}

# 主函数
main() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                大数据AI平台健康检查                          ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    
    local overall_status=0
    
    # 1. 检查容器状态
    log_info "=== 1. 容器状态检查 ==="
    check_container_status "minio" "MinIO" || overall_status=1
    check_container_status "kafka" "Kafka" || overall_status=1
    check_container_status "doris-fe" "Doris FE" || overall_status=1
    check_container_status "doris-be" "Doris BE" || overall_status=1
    check_container_status "flink-jobmanager" "Flink JobManager" || overall_status=1
    check_container_status "flink-taskmanager" "Flink TaskManager" || overall_status=1
    check_container_status "paimon-catalog" "Paimon Catalog" || overall_status=1
    check_container_status "prometheus" "Prometheus" || overall_status=1
    check_container_status "grafana" "Grafana" || overall_status=1
    check_container_status "airflow-webserver" "Airflow Webserver" || overall_status=1
    check_container_status "superset" "Superset" || overall_status=1
    check_container_status "jupyterhub" "JupyterHub" || overall_status=1
    echo ""
    
    # 2. 检查服务健康状态
    log_info "=== 2. 服务健康状态检查 ==="
    check_service_health "MinIO" 9001 "/minio/health/live" "MinIO Console" || overall_status=1
    check_service_health "Kafka UI" 8082 "/" "Kafka UI" || overall_status=1
    check_service_health "Doris FE" 8030 "/api/bootstrap" "Doris FE" || overall_status=1
    check_service_health "Doris BE" 8040 "/api/health" "Doris BE" || overall_status=1
    check_service_health "Flink" 8081 "/" "Flink Web UI" || overall_status=1
    check_service_health "Prometheus" 9090 "/-/healthy" "Prometheus" || overall_status=1
    check_service_health "Grafana" 3000 "/api/health" "Grafana" || overall_status=1
    check_service_health "Airflow" 8080 "/health" "Airflow" || overall_status=1
    check_service_health "Superset" 8088 "/health" "Superset" || overall_status=1
    check_service_health "JupyterHub" 8000 "/hub/api/health" "JupyterHub" || overall_status=1
    echo ""
    
    # 3. 检查数据连接
    log_info "=== 3. 数据连接检查 ==="
    check_data_connection "minio" "MinIO" || overall_status=1
    check_data_connection "kafka" "Kafka" || overall_status=1
    check_data_connection "doris" "Doris" || overall_status=1
    check_data_connection "redis" "Redis" || overall_status=1
    echo ""
    
    # 4. 检查Flink和Paimon
    log_info "=== 4. Flink和Paimon检查 ==="
    check_flink_jobs || overall_status=1
    check_paimon_status || overall_status=1
    echo ""
    
    # 5. 检查网络连接
    log_info "=== 5. 网络连接检查 ==="
    check_network_connectivity || overall_status=1
    echo ""
    
    # 6. 检查资源使用
    log_info "=== 6. 资源使用检查 ==="
    check_resource_usage
    echo ""
    
    # 7. 检查日志错误
    log_info "=== 7. 日志错误检查 ==="
    check_log_errors
    echo ""
    
    # 8. 生成健康报告
    log_info "=== 8. 生成健康报告 ==="
    generate_health_report
    echo ""
    
    # 总结
    if [ $overall_status -eq 0 ]; then
        log_success "🎉 所有健康检查通过！平台运行正常"
    else
        log_error "⚠️  部分健康检查失败，请查看详细报告"
    fi
    
    echo ""
    log_info "💡 提示:"
    echo "  - 查看详细报告: cat /tmp/health_report_*.txt"
    echo "  - 查看服务日志: docker logs <container_name>"
    echo "  - 重启服务: docker-compose restart <service_name>"
    echo "  - 查看资源使用: docker stats"
    echo ""
}

# 执行主函数
main "$@" 