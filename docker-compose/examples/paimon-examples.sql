-- Paimon数据湖使用示例
-- 作者: 云原生专家
-- 版本: 1.0.0

-- ==================== 1. 基础操作示例 ====================

-- 使用Paimon Catalog
USE CATALOG paimon;
USE default_database;

-- 查看所有表
SHOW TABLES;

-- 查看表结构
DESCRIBE user_events;
DESCRIBE sales_data;
DESCRIBE word_count;

-- ==================== 2. 数据查询示例 ====================

-- 查询用户事件数据
SELECT 
    user_id,
    event_type,
    event_time,
    properties
FROM user_events
WHERE event_date = '2024-01-01'
ORDER BY event_time;

-- 查询销售数据统计
SELECT 
    category,
    COUNT(*) as product_count,
    SUM(quantity) as total_quantity,
    SUM(price * quantity) as total_revenue
FROM sales_data
GROUP BY category
ORDER BY total_revenue DESC;

-- 查询词频统计
SELECT 
    word,
    SUM(count) as total_count,
    COUNT(*) as window_count
FROM word_count
GROUP BY word
ORDER BY total_count DESC
LIMIT 10;

-- ==================== 3. 流式数据处理示例 ====================

-- 创建Kafka数据源表
CREATE TABLE IF NOT EXISTS kafka_user_events (
    user_id BIGINT,
    event_type STRING,
    event_time TIMESTAMP(3),
    properties STRING,
    WATERMARK FOR event_time AS event_time - INTERVAL '5' SECOND
) WITH (
    'connector' = 'kafka',
    'topic' = 'user-events',
    'properties.bootstrap.servers' = 'kafka:29092',
    'properties.group.id' = 'paimon-user-events-group',
    'scan.startup.mode' = 'latest-offset',
    'format' = 'json'
);

-- 创建Kafka销售数据源表
CREATE TABLE IF NOT EXISTS kafka_sales_data (
    id BIGINT,
    product_name STRING,
    category STRING,
    price DECIMAL(10,2),
    quantity INT,
    sale_date DATE,
    region STRING,
    WATERMARK FOR sale_date AS CAST(sale_date AS TIMESTAMP(3)) - INTERVAL '1' DAY
) WITH (
    'connector' = 'kafka',
    'topic' = 'sales-data',
    'properties.bootstrap.servers' = 'kafka:29092',
    'properties.group.id' = 'paimon-sales-group',
    'scan.startup.mode' = 'latest-offset',
    'format' = 'json'
);

-- ==================== 4. 实时聚合示例 ====================

-- 用户事件实时聚合
INSERT INTO user_events
SELECT 
    user_id,
    event_type,
    event_time,
    properties
FROM kafka_user_events;

-- 销售数据实时聚合
INSERT INTO sales_data
SELECT 
    id,
    product_name,
    category,
    price,
    quantity,
    sale_date,
    region
FROM kafka_sales_data;

-- ==================== 5. 时间窗口聚合示例 ====================

-- 创建小时级用户事件聚合表
CREATE TABLE IF NOT EXISTS user_events_hourly (
    event_type STRING,
    event_hour TIMESTAMP(3),
    user_count BIGINT,
    event_count BIGINT,
    PRIMARY KEY (event_type, event_hour) NOT ENFORCED
) WITH (
    'bucket' = '4',
    'bucket-key' = 'event_type',
    'changelog-producer' = 'input',
    'merge-engine' = 'deduplicate',
    'file.format' = 'parquet',
    'compression' = 'snappy'
) PARTITIONED BY (event_hour);

-- 小时级用户事件聚合
INSERT INTO user_events_hourly
SELECT 
    event_type,
    TUMBLE_START(event_time, INTERVAL '1' HOUR) as event_hour,
    COUNT(DISTINCT user_id) as user_count,
    COUNT(*) as event_count
FROM kafka_user_events
GROUP BY event_type, TUMBLE(event_time, INTERVAL '1' HOUR);

-- ==================== 6. 数据湖查询示例 ====================

-- 跨表关联查询
SELECT 
    u.user_id,
    u.event_type,
    u.event_time,
    s.product_name,
    s.category,
    s.price
FROM user_events u
LEFT JOIN sales_data s ON u.user_id = s.id
WHERE u.event_type = 'purchase'
  AND u.event_date = s.sale_date;

-- 实时销售分析
SELECT 
    s.category,
    s.region,
    COUNT(DISTINCT s.id) as order_count,
    SUM(s.quantity) as total_quantity,
    SUM(s.price * s.quantity) as total_revenue,
    AVG(s.price) as avg_price
FROM sales_data s
WHERE s.sale_date >= CURRENT_DATE - INTERVAL '7' DAY
GROUP BY s.category, s.region
ORDER BY total_revenue DESC;

-- ==================== 7. 数据质量监控示例 ====================

-- 创建数据质量监控表
CREATE TABLE IF NOT EXISTS data_quality_metrics (
    table_name STRING,
    metric_date DATE,
    record_count BIGINT,
    null_count BIGINT,
    duplicate_count BIGINT,
    data_quality_score DECIMAL(5,2),
    PRIMARY KEY (table_name, metric_date) NOT ENFORCED
) WITH (
    'bucket' = '4',
    'bucket-key' = 'table_name',
    'changelog-producer' = 'input',
    'merge-engine' = 'deduplicate',
    'file.format' = 'parquet',
    'compression' = 'snappy'
) PARTITIONED BY (metric_date);

-- 用户事件数据质量监控
INSERT INTO data_quality_metrics
SELECT 
    'user_events' as table_name,
    CURRENT_DATE as metric_date,
    COUNT(*) as record_count,
    COUNT(CASE WHEN user_id IS NULL THEN 1 END) as null_count,
    COUNT(*) - COUNT(DISTINCT user_id) as duplicate_count,
    CASE 
        WHEN COUNT(*) > 0 THEN 
            (COUNT(*) - COUNT(CASE WHEN user_id IS NULL THEN 1 END)) * 100.0 / COUNT(*)
        ELSE 0 
    END as data_quality_score
FROM user_events
WHERE event_date = CURRENT_DATE;

-- ==================== 8. 数据湖优化示例 ====================

-- 创建优化后的销售汇总表
CREATE TABLE IF NOT EXISTS sales_summary (
    category STRING,
    region STRING,
    sale_date DATE,
    total_revenue DECIMAL(15,2),
    total_quantity BIGINT,
    order_count BIGINT,
    avg_price DECIMAL(10,2),
    PRIMARY KEY (category, region, sale_date) NOT ENFORCED
) WITH (
    'bucket' = '4',
    'bucket-key' = 'category',
    'changelog-producer' = 'input',
    'merge-engine' = 'deduplicate',
    'file.format' = 'parquet',
    'compression' = 'snappy'
) PARTITIONED BY (sale_date);

-- 销售数据汇总
INSERT INTO sales_summary
SELECT 
    category,
    region,
    sale_date,
    SUM(price * quantity) as total_revenue,
    SUM(quantity) as total_quantity,
    COUNT(*) as order_count,
    AVG(price) as avg_price
FROM sales_data
GROUP BY category, region, sale_date;

-- ==================== 9. 流式数据湖查询示例 ====================

-- 实时用户行为分析
SELECT 
    event_type,
    TUMBLE_START(event_time, INTERVAL '5' MINUTE) as window_start,
    TUMBLE_END(event_time, INTERVAL '5' MINUTE) as window_end,
    COUNT(DISTINCT user_id) as unique_users,
    COUNT(*) as total_events
FROM kafka_user_events
GROUP BY event_type, TUMBLE(event_time, INTERVAL '5' MINUTE);

-- 实时销售趋势分析
SELECT 
    category,
    TUMBLE_START(CAST(sale_date AS TIMESTAMP(3)), INTERVAL '1' HOUR) as hour_start,
    SUM(price * quantity) as hourly_revenue,
    COUNT(*) as hourly_orders
FROM kafka_sales_data
GROUP BY category, TUMBLE(CAST(sale_date AS TIMESTAMP(3)), INTERVAL '1' HOUR);

-- ==================== 10. 数据湖管理示例 ====================

-- 查看表快照信息
-- 注意：这需要在Flink SQL Client中执行
-- SHOW SNAPSHOTS FROM user_events;

-- 查看表文件信息
-- 注意：这需要在Flink SQL Client中执行
-- SHOW FILES FROM user_events;

-- 数据湖清理（删除过期数据）
-- 注意：这需要在Flink SQL Client中执行
-- DELETE FROM user_events WHERE event_date < CURRENT_DATE - INTERVAL '30' DAY;

-- ==================== 11. 性能优化示例 ====================

-- 创建分区索引表
CREATE TABLE IF NOT EXISTS user_events_indexed (
    user_id BIGINT,
    event_type STRING,
    event_time TIMESTAMP(3),
    properties STRING,
    event_date AS DATE(event_time),
    WATERMARK FOR event_time AS event_time - INTERVAL '5' SECOND
) WITH (
    'bucket' = '8',  -- 增加bucket数量
    'bucket-key' = 'user_id',
    'changelog-producer' = 'input',
    'merge-engine' = 'deduplicate',
    'file.format' = 'parquet',
    'compression' = 'snappy',
    'target-file-size' = '64MB',  -- 优化文件大小
    'write-buffer-size' = '128MB'  -- 优化写入缓冲区
) PARTITIONED BY (event_date);

-- ==================== 12. 数据湖监控示例 ====================

-- 创建监控指标表
CREATE TABLE IF NOT EXISTS paimon_metrics (
    table_name STRING,
    metric_time TIMESTAMP(3),
    metric_type STRING,
    metric_value BIGINT,
    PRIMARY KEY (table_name, metric_time, metric_type) NOT ENFORCED
) WITH (
    'bucket' = '4',
    'bucket-key' = 'table_name',
    'changelog-producer' = 'input',
    'merge-engine' = 'deduplicate',
    'file.format' = 'parquet',
    'compression' = 'snappy'
) PARTITIONED BY (metric_time);

-- 插入监控数据
INSERT INTO paimon_metrics
SELECT 
    'user_events' as table_name,
    CURRENT_TIMESTAMP as metric_time,
    'record_count' as metric_type,
    COUNT(*) as metric_value
FROM user_events
WHERE event_date = CURRENT_DATE;

-- ==================== 使用说明 ====================

/*
使用说明：

1. 执行环境：
   - 确保Flink JobManager和TaskManager已启动
   - 确保Paimon Catalog已创建
   - 使用Flink SQL Client执行：/opt/flink/bin/sql-client.sh

2. 数据源：
   - Kafka主题：user-events, sales-data, word-count-input
   - MinIO存储：s3://bigdata-lake/paimon

3. 主要功能：
   - 流式数据湖存储
   - 实时数据处理
   - 时间窗口聚合
   - 数据质量监控
   - 性能优化

4. 监控访问：
   - Flink Web UI: http://localhost:8081
   - MinIO Console: http://localhost:9001
   - Kafka UI: http://localhost:8082

5. 注意事项：
   - 所有表都支持流式读写
   - 支持ACID事务
   - 支持时间旅行查询
   - 支持增量查询
*/ 