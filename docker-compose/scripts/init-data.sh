#!/bin/bash

# 数据初始化脚本
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

# 等待服务就绪
wait_for_service() {
    local service=$1
    local port=$2
    local max_attempts=30
    local attempt=1
    
    log_info "等待服务 $service 就绪..."
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s "http://localhost:$port" > /dev/null 2>&1; then
            log_success "$service 已就绪"
            return 0
        fi
        
        log_info "尝试 $attempt/$max_attempts: $service 未就绪，等待5秒..."
        sleep 5
        attempt=$((attempt + 1))
    done
    
    log_error "$service 启动超时"
    return 1
}

# 初始化MinIO
init_minio() {
    log_info "初始化MinIO..."
    
    # 等待MinIO就绪
    wait_for_service "MinIO" 9000
    
    # 创建bucket
    docker exec minio-client mc mb myminio/bigdata-lake 2>/dev/null || true
    docker exec minio-client mc mb myminio/ml-models 2>/dev/null || true
    docker exec minio-client mc mb myminio/checkpoints 2>/dev/null || true
    docker exec minio-client mc mb myminio/savepoints 2>/dev/null || true
    
    # 设置bucket策略
    docker exec minio-client mc policy set public myminio/bigdata-lake 2>/dev/null || true
    
    log_success "MinIO初始化完成"
}

# 初始化Kafka
init_kafka() {
    log_info "初始化Kafka..."
    
    # 等待Kafka就绪
    wait_for_service "Kafka" 9092
    
    # 创建主题
    docker exec kafka kafka-topics --create --bootstrap-server localhost:9092 --topic user-events --partitions 3 --replication-factor 1 2>/dev/null || true
    docker exec kafka kafka-topics --create --bootstrap-server localhost:9092 --topic data-stream --partitions 3 --replication-factor 1 2>/dev/null || true
    docker exec kafka kafka-topics --create --bootstrap-server localhost:9092 --topic ml-events --partitions 3 --replication-factor 1 2>/dev/null || true
    docker exec kafka kafka-topics --create --bootstrap-server localhost:9092 --topic word-count-input --partitions 3 --replication-factor 1 2>/dev/null || true
    
    # 生成测试数据
    log_info "生成Kafka测试数据..."
    docker exec kafka bash -c '
        for i in {1..100}; do
            echo "{\"user_id\": $i, \"event_type\": \"click\", \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%S.000Z)\", \"properties\": {\"page\": \"/home\", \"source\": \"web\"}}" | kafka-console-producer --bootstrap-server localhost:9092 --topic user-events
            echo "{\"word\": \"hello\", \"count\": 1, \"ts\": \"$(date -u +%Y-%m-%dT%H:%M:%S.000Z)\"}" | kafka-console-producer --bootstrap-server localhost:9092 --topic word-count-input
            echo "{\"word\": \"world\", \"count\": 1, \"ts\": \"$(date -u +%Y-%m-%dT%H:%M:%S.000Z)\"}" | kafka-console-producer --bootstrap-server localhost:9092 --topic word-count-input
            sleep 1
        done
    ' &
    
    log_success "Kafka初始化完成"
}

# 初始化Doris
init_doris() {
    log_info "初始化Doris..."
    
    # 等待Doris FE就绪
    wait_for_service "Doris FE" 8030
    
    # 等待Doris BE就绪
    wait_for_service "Doris BE" 8040
    
    # 创建数据库和表
    docker exec doris-fe mysql -h localhost -P 9030 -u root -e "
        CREATE DATABASE IF NOT EXISTS bigdata_platform;
        USE bigdata_platform;
        
        CREATE TABLE IF NOT EXISTS user_events (
            user_id BIGINT,
            event_type VARCHAR(50),
            event_time DATETIME,
            properties JSON
        ) DUPLICATE KEY(user_id, event_time)
        DISTRIBUTED BY HASH(user_id) BUCKETS 10
        PROPERTIES (
            'replication_num' = '1'
        );
        
        CREATE TABLE IF NOT EXISTS word_count (
            word VARCHAR(100),
            count BIGINT,
            window_start DATETIME,
            window_end DATETIME
        ) DUPLICATE KEY(word, window_start)
        DISTRIBUTED BY HASH(word) BUCKETS 10
        PROPERTIES (
            'replication_num' = '1'
        );
        
        CREATE TABLE IF NOT EXISTS sales_data (
            id BIGINT,
            product_name VARCHAR(100),
            category VARCHAR(50),
            price DECIMAL(10,2),
            quantity INT,
            sale_date DATE,
            region VARCHAR(50)
        ) DUPLICATE KEY(id, sale_date)
        DISTRIBUTED BY HASH(id) BUCKETS 10
        PROPERTIES (
            'replication_num' = '1'
        );
    " 2>/dev/null || true
    
    # 插入测试数据
    log_info "插入Doris测试数据..."
    docker exec doris-fe mysql -h localhost -P 9030 -u root -e "
        USE bigdata_platform;
        
        INSERT INTO sales_data VALUES
        (1, 'Laptop', 'Electronics', 999.99, 2, '2024-01-01', 'North'),
        (2, 'Phone', 'Electronics', 599.99, 5, '2024-01-02', 'South'),
        (3, 'Book', 'Education', 29.99, 10, '2024-01-03', 'East'),
        (4, 'Chair', 'Furniture', 199.99, 3, '2024-01-04', 'West'),
        (5, 'Table', 'Furniture', 299.99, 1, '2024-01-05', 'North');
    " 2>/dev/null || true
    
    log_success "Doris初始化完成"
}

# 初始化Redis
init_redis() {
    log_info "初始化Redis..."
    
    # 等待Redis就绪
    wait_for_service "Redis" 6379
    
    # 插入测试数据
    docker exec redis redis-cli -a redis123 SET "app:config:version" "1.0.0" 2>/dev/null || true
    docker exec redis redis-cli -a redis123 SET "app:stats:users:total" "1000" 2>/dev/null || true
    docker exec redis redis-cli -a redis123 SET "app:stats:orders:total" "5000" 2>/dev/null || true
    
    # 创建列表
    docker exec redis redis-cli -a redis123 LPUSH "recent_events" "user_login" "user_logout" "order_created" 2>/dev/null || true
    
    # 创建集合
    docker exec redis redis-cli -a redis123 SADD "active_users" "user1" "user2" "user3" 2>/dev/null || true
    
    log_success "Redis初始化完成"
}

# 初始化Airflow
init_airflow() {
    log_info "初始化Airflow..."
    
    # 等待Airflow就绪
    wait_for_service "Airflow" 8080
    
    # 创建示例DAG
    cat > /tmp/sample_dag.py << 'EOF'
from airflow import DAG
from airflow.operators.python_operator import PythonOperator
from airflow.operators.bash_operator import BashOperator
from datetime import datetime, timedelta
import requests
import json

default_args = {
    'owner': 'data-team',
    'depends_on_past': False,
    'start_date': datetime(2024, 1, 1),
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

dag = DAG(
    'data_pipeline_demo',
    default_args=default_args,
    description='数据管道演示',
    schedule_interval=timedelta(hours=1),
    catchup=False,
)

def extract_data():
    """提取数据"""
    print("开始提取数据...")
    # 模拟从Kafka提取数据
    return {"message": "数据提取完成", "count": 100}

def transform_data(**context):
    """转换数据"""
    print("开始转换数据...")
    # 模拟数据处理
    return {"message": "数据转换完成", "processed_count": 95}

def load_data(**context):
    """加载数据"""
    print("开始加载数据...")
    # 模拟数据加载到Doris
    return {"message": "数据加载完成", "loaded_count": 90}

def check_health():
    """健康检查"""
    print("执行健康检查...")
    services = ['minio:9000', 'kafka:9092', 'doris-fe:8030', 'redis:6379']
    for service in services:
        try:
            response = requests.get(f"http://{service}", timeout=5)
            print(f"{service} 健康检查通过")
        except:
            print(f"{service} 健康检查失败")

extract_task = PythonOperator(
    task_id='extract_data',
    python_callable=extract_data,
    dag=dag,
)

transform_task = PythonOperator(
    task_id='transform_data',
    python_callable=transform_data,
    dag=dag,
)

load_task = PythonOperator(
    task_id='load_data',
    python_callable=load_data,
    dag=dag,
)

health_check_task = PythonOperator(
    task_id='health_check',
    python_callable=check_health,
    dag=dag,
)

# 任务依赖
extract_task >> transform_task >> load_task
health_check_task >> extract_task
EOF

    # 复制DAG文件
    docker cp /tmp/sample_dag.py airflow-webserver:/opt/airflow/dags/
    
    log_success "Airflow初始化完成"
}

# 初始化Superset
init_superset() {
    log_info "初始化Superset..."
    
    # 等待Superset就绪
    wait_for_service "Superset" 8088
    
    log_info "Superset初始化完成，请手动配置数据源"
    log_info "访问地址: http://localhost:8088"
    log_info "默认账号: admin/admin123"
}

# 初始化JupyterHub
init_jupyterhub() {
    log_info "初始化JupyterHub..."
    
    # 等待JupyterHub就绪
    wait_for_service "JupyterHub" 8000
    
    log_info "JupyterHub初始化完成"
    log_info "访问地址: http://localhost:8000"
    log_info "默认账号: admin/jupyter123"
}

# 初始化Paimon
init_paimon() {
    log_info "初始化Paimon数据湖..."
    
    # 等待Flink就绪
    wait_for_service "Flink JobManager" 8081
    
    # 等待Paimon Catalog服务就绪
    sleep 30
    
    # 检查Paimon Catalog是否已初始化
    if docker exec paimon-catalog ls /opt/flink/lib/paimon-flink-1.17-*.jar > /dev/null 2>&1; then
        log_success "Paimon已初始化"
    else
        log_info "Paimon初始化中，请稍候..."
        sleep 60
    fi
    
    log_info "Paimon数据湖初始化完成"
    log_info "访问Flink Web UI: http://localhost:8081"
    log_info "Paimon Catalog: paimon"
    log_info "数据仓库: s3://bigdata-lake/paimon"
}

# 创建示例数据文件
create_sample_data() {
    log_info "创建示例数据文件..."
    
    # 创建CSV示例数据
    cat > /tmp/sample_sales.csv << 'EOF'
id,product_name,category,price,quantity,sale_date,region
1,Laptop,Electronics,999.99,2,2024-01-01,North
2,Phone,Electronics,599.99,5,2024-01-02,South
3,Book,Education,29.99,10,2024-01-03,East
4,Chair,Furniture,199.99,3,2024-01-04,West
5,Table,Furniture,299.99,1,2024-01-05,North
6,Monitor,Electronics,299.99,4,2024-01-06,South
7,Desk,Furniture,399.99,2,2024-01-07,East
8,Keyboard,Electronics,79.99,8,2024-01-08,West
9,Mouse,Electronics,49.99,12,2024-01-09,North
10,Notebook,Education,9.99,20,2024-01-10,South
EOF

    # 上传到MinIO
    docker cp /tmp/sample_sales.csv minio-client:/tmp/
    docker exec minio-client mc cp /tmp/sample_sales.csv myminio/bigdata-lake/
    
    log_success "示例数据文件创建完成"
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
    echo "  Paimon Data Lake:  s3://bigdata-lake/paimon"
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

# 主函数
main() {
    log_info "开始初始化大数据AI平台数据..."
    
    # 等待所有服务启动
    sleep 30
    
    # 初始化各个服务
    init_minio
    init_kafka
    init_doris
    init_redis
    init_airflow
    init_superset
    init_jupyterhub
    init_paimon
    create_sample_data
    
    # 显示访问信息
    show_access_info
    
    log_success "数据初始化完成！"
    log_info "所有服务已就绪，可以开始使用平台"
}

# 执行主函数
main "$@" 