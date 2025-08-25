#!/bin/bash

# Paimon初始化脚本
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

# 等待Flink就绪
wait_for_flink() {
    log_info "等待Flink JobManager就绪..."
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s "http://flink-jobmanager:8081" > /dev/null 2>&1; then
            log_success "Flink JobManager已就绪"
            return 0
        fi
        
        log_info "尝试 $attempt/$max_attempts: Flink未就绪，等待10秒..."
        sleep 10
        attempt=$((attempt + 1))
    done
    
    log_error "Flink启动超时"
    return 1
}

# 下载Paimon JAR包
download_paimon_jars() {
    log_info "下载Paimon JAR包..."
    
    # 创建lib目录
    mkdir -p /opt/flink/lib
    
    # 下载Paimon JAR包
    cd /opt/flink/lib
    
    # 下载Paimon Flink 1.17 JAR包
    wget -q https://repo1.maven.org/maven2/org/apache/paimon/paimon-flink-1.17/0.6.0-incubating/paimon-flink-1.17-0.6.0-incubating.jar
    
    # 下载Paimon Hive Catalog JAR包
    wget -q https://repo1.maven.org/maven2/org/apache/paimon/paimon-hive-catalog/0.6.0-incubating/paimon-hive-catalog-0.6.0-incubating.jar
    
    # 下载Paimon Filesystem JAR包
    wget -q https://repo1.maven.org/maven2/org/apache/paimon/paimon-filesystem/0.6.0-incubating/paimon-filesystem-0.6.0-incubating.jar
    
    # 下载Paimon S3 JAR包
    wget -q https://repo1.maven.org/maven2/org/apache/paimon/paimon-s3/0.6.0-incubating/paimon-s3-0.6.0-incubating.jar
    
    log_success "Paimon JAR包下载完成"
}

# 创建Paimon Catalog
create_paimon_catalog() {
    log_info "创建Paimon Catalog..."
    
    # 等待Flink SQL客户端就绪
    sleep 10
    
    # 创建Catalog SQL
    cat > /tmp/create_catalog.sql << 'EOF'
-- 创建Paimon Catalog
CREATE CATALOG paimon WITH (
    'type' = 'paimon',
    'warehouse' = 's3://bigdata-lake/paimon',
    's3.endpoint' = 'http://minio:9000',
    's3.access-key' = 'admin',
    's3.secret-key' = 'minio123',
    's3.path.style' = 'true',
    's3.region' = 'us-east-1'
);

-- 使用Paimon Catalog
USE CATALOG paimon;

-- 创建默认数据库
CREATE DATABASE IF NOT EXISTS default_database;
USE default_database;
EOF

    # 执行SQL
    /opt/flink/bin/sql-client.sh -f /tmp/create_catalog.sql
    
    log_success "Paimon Catalog创建完成"
}

# 创建Paimon表
create_paimon_tables() {
    log_info "创建Paimon表..."
    
    # 用户事件表
    cat > /tmp/create_user_events_table.sql << 'EOF'
-- 创建用户事件表
CREATE TABLE IF NOT EXISTS user_events (
    user_id BIGINT,
    event_type STRING,
    event_time TIMESTAMP(3),
    properties STRING,
    event_date AS DATE(event_time),
    WATERMARK FOR event_time AS event_time - INTERVAL '5' SECOND
) WITH (
    'bucket' = '4',
    'bucket-key' = 'user_id',
    'changelog-producer' = 'input',
    'merge-engine' = 'deduplicate',
    'file.format' = 'parquet',
    'compression' = 'snappy'
) PARTITIONED BY (event_date);
EOF

    # 销售数据表
    cat > /tmp/create_sales_table.sql << 'EOF'
-- 创建销售数据表
CREATE TABLE IF NOT EXISTS sales_data (
    id BIGINT,
    product_name STRING,
    category STRING,
    price DECIMAL(10,2),
    quantity INT,
    sale_date DATE,
    region STRING,
    sale_timestamp AS CAST(sale_date AS TIMESTAMP(3)),
    WATERMARK FOR sale_timestamp AS sale_timestamp - INTERVAL '1' DAY
) WITH (
    'bucket' = '4',
    'bucket-key' = 'id',
    'changelog-producer' = 'input',
    'merge-engine' = 'deduplicate',
    'file.format' = 'parquet',
    'compression' = 'snappy'
) PARTITIONED BY (sale_date);
EOF

    # 词频统计表
    cat > /tmp/create_word_count_table.sql << 'EOF'
-- 创建词频统计表
CREATE TABLE IF NOT EXISTS word_count (
    word STRING,
    count BIGINT,
    window_start TIMESTAMP(3),
    window_end TIMESTAMP(3),
    window_date AS DATE(window_start),
    WATERMARK FOR window_start AS window_start - INTERVAL '5' SECOND
) WITH (
    'bucket' = '4',
    'bucket-key' = 'word',
    'changelog-producer' = 'input',
    'merge-engine' = 'deduplicate',
    'file.format' = 'parquet',
    'compression' = 'snappy'
) PARTITIONED BY (window_date);
EOF

    # 执行SQL
    /opt/flink/bin/sql-client.sh -f /tmp/create_user_events_table.sql
    /opt/flink/bin/sql-client.sh -f /tmp/create_sales_table.sql
    /opt/flink/bin/sql-client.sh -f /tmp/create_word_count_table.sql
    
    log_success "Paimon表创建完成"
}

# 创建示例数据
create_sample_data() {
    log_info "创建示例数据..."
    
    # 插入用户事件数据
    cat > /tmp/insert_user_events.sql << 'EOF'
-- 插入用户事件示例数据
INSERT INTO user_events VALUES
(1, 'click', TIMESTAMP '2024-01-01 10:00:00', '{"page": "/home", "source": "web"}'),
(2, 'purchase', TIMESTAMP '2024-01-01 10:05:00', '{"product_id": "123", "amount": 99.99}'),
(3, 'view', TIMESTAMP '2024-01-01 10:10:00', '{"page": "/product", "duration": 30}'),
(4, 'click', TIMESTAMP '2024-01-01 10:15:00', '{"page": "/cart", "source": "mobile"}'),
(5, 'logout', TIMESTAMP '2024-01-01 10:20:00', '{"session_duration": 1200}');
EOF

    # 插入销售数据
    cat > /tmp/insert_sales_data.sql << 'EOF'
-- 插入销售数据示例
INSERT INTO sales_data VALUES
(1, 'Laptop', 'Electronics', 999.99, 2, DATE '2024-01-01', 'North'),
(2, 'Phone', 'Electronics', 599.99, 5, DATE '2024-01-02', 'South'),
(3, 'Book', 'Education', 29.99, 10, DATE '2024-01-03', 'East'),
(4, 'Chair', 'Furniture', 199.99, 3, DATE '2024-01-04', 'West'),
(5, 'Table', 'Furniture', 299.99, 1, DATE '2024-01-05', 'North');
EOF

    # 执行插入
    /opt/flink/bin/sql-client.sh -f /tmp/insert_user_events.sql
    /opt/flink/bin/sql-client.sh -f /tmp/insert_sales_data.sql
    
    log_success "示例数据创建完成"
}

# 创建Flink作业
create_flink_jobs() {
    log_info "创建Flink作业..."
    
    # 词频统计作业
    cat > /tmp/word_count_job.sql << 'EOF'
-- 词频统计流处理作业
CREATE TABLE word_count_input (
    word STRING,
    count BIGINT,
    ts TIMESTAMP(3),
    WATERMARK FOR ts AS ts - INTERVAL '5' SECOND
) WITH (
    'connector' = 'kafka',
    'topic' = 'word-count-input',
    'properties.bootstrap.servers' = 'kafka:29092',
    'properties.group.id' = 'word-count-group',
    'scan.startup.mode' = 'latest-offset',
    'format' = 'json'
);

-- 创建词频统计作业
INSERT INTO word_count
SELECT 
    word,
    SUM(count) as count,
    TUMBLE_START(ts, INTERVAL '1' MINUTE) as window_start,
    TUMBLE_END(ts, INTERVAL '1' MINUTE) as window_end
FROM word_count_input
GROUP BY word, TUMBLE(ts, INTERVAL '1' MINUTE);
EOF

    # 用户事件聚合作业
    cat > /tmp/user_events_job.sql << 'EOF'
-- 用户事件聚合作业
CREATE TABLE user_events_kafka (
    user_id BIGINT,
    event_type STRING,
    event_time TIMESTAMP(3),
    properties STRING,
    WATERMARK FOR event_time AS event_time - INTERVAL '5' SECOND
) WITH (
    'connector' = 'kafka',
    'topic' = 'user-events',
    'properties.bootstrap.servers' = 'kafka:29092',
    'properties.group.id' = 'user-events-group',
    'scan.startup.mode' = 'latest-offset',
    'format' = 'json'
);

-- 用户事件聚合
INSERT INTO user_events
SELECT 
    user_id,
    event_type,
    event_time,
    properties
FROM user_events_kafka;
EOF

    # 提交作业
    /opt/flink/bin/sql-client.sh -f /tmp/word_count_job.sql
    /opt/flink/bin/sql-client.sh -f /tmp/user_events_job.sql
    
    log_success "Flink作业创建完成"
}

# 验证Paimon功能
verify_paimon() {
    log_info "验证Paimon功能..."
    
    # 查询表列表
    cat > /tmp/verify_tables.sql << 'EOF'
-- 查看所有表
SHOW TABLES;

-- 查询用户事件数据
SELECT COUNT(*) as user_events_count FROM user_events;

-- 查询销售数据
SELECT COUNT(*) as sales_count FROM sales_data;

-- 查询词频统计
SELECT COUNT(*) as word_count_records FROM word_count;
EOF

    /opt/flink/bin/sql-client.sh -f /tmp/verify_tables.sql
    
    log_success "Paimon功能验证完成"
}

# 显示Paimon信息
show_paimon_info() {
    log_info "=== Paimon数据湖信息 ==="
    echo ""
    echo "📊 Paimon Catalog: paimon"
    echo "🏠 数据仓库: s3://bigdata-lake/paimon"
    echo "🔗 S3端点: http://minio:9000"
    echo ""
    echo "📋 已创建的表:"
    echo "  • user_events - 用户事件表"
    echo "  • sales_data - 销售数据表"
    echo "  • word_count - 词频统计表"
    echo ""
    echo "🚀 Flink作业:"
    echo "  • 词频统计流处理作业"
    echo "  • 用户事件聚合作业"
    echo ""
    echo "🔧 访问方式:"
    echo "  • Flink SQL Client: /opt/flink/bin/sql-client.sh"
    echo "  • Flink Web UI: http://localhost:8081"
    echo "  • MinIO Console: http://localhost:9001"
    echo ""
}

# 主函数
main() {
    log_info "开始初始化Paimon数据湖..."
    
    # 等待Flink就绪
    wait_for_flink
    
    # 下载Paimon JAR包
    download_paimon_jars
    
    # 创建Paimon Catalog
    create_paimon_catalog
    
    # 创建Paimon表
    create_paimon_tables
    
    # 创建示例数据
    create_sample_data
    
    # 创建Flink作业
    create_flink_jobs
    
    # 验证Paimon功能
    verify_paimon
    
    # 显示信息
    show_paimon_info
    
    log_success "Paimon数据湖初始化完成！"
    log_info "Paimon已与Flink深度集成，支持流式数据湖功能"
}

# 执行主函数
main "$@" 