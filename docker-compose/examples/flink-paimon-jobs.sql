-- Flink与Paimon集成作业示例
-- 作者: 云原生专家
-- 版本: 1.0.0

-- ==================== 1. 环境准备 ====================

-- 使用Paimon Catalog
USE CATALOG paimon;
USE default_database;

-- 设置执行模式
SET 'execution.runtime-mode' = 'streaming';
SET 'table.exec.mini-batch.enabled' = 'true';
SET 'table.exec.mini-batch.size' = '1000';
SET 'table.exec.mini-batch.allow-latency' = '1s';

-- ==================== 2. 创建Kafka数据源表 ====================

-- 用户行为数据源
CREATE TABLE kafka_user_behavior (
    user_id BIGINT,
    item_id BIGINT,
    category_id BIGINT,
    behavior STRING,
    ts TIMESTAMP(3),
    WATERMARK FOR ts AS ts - INTERVAL '5' SECOND
) WITH (
    'connector' = 'kafka',
    'topic' = 'user-behavior',
    'properties.bootstrap.servers' = 'kafka:29092',
    'properties.group.id' = 'user-behavior-group',
    'scan.startup.mode' = 'latest-offset',
    'format' = 'json'
);

-- 订单数据源
CREATE TABLE kafka_orders (
    order_id BIGINT,
    user_id BIGINT,
    product_id BIGINT,
    quantity INT,
    price DECIMAL(10,2),
    order_time TIMESTAMP(3),
    WATERMARK FOR order_time AS order_time - INTERVAL '10' SECOND
) WITH (
    'connector' = 'kafka',
    'topic' = 'orders',
    'properties.bootstrap.servers' = 'kafka:29092',
    'properties.group.id' = 'orders-group',
    'scan.startup.mode' = 'latest-offset',
    'format' = 'json'
);

-- 商品数据源
CREATE TABLE kafka_products (
    product_id BIGINT,
    product_name STRING,
    category STRING,
    price DECIMAL(10,2),
    update_time TIMESTAMP(3),
    WATERMARK FOR update_time AS update_time - INTERVAL '5' SECOND
) WITH (
    'connector' = 'kafka',
    'topic' = 'products',
    'properties.bootstrap.servers' = 'kafka:29092',
    'properties.group.id' = 'products-group',
    'scan.startup.mode' = 'latest-offset',
    'format' = 'json'
);

-- ==================== 3. 创建Paimon目标表 ====================

-- 用户行为汇总表
CREATE TABLE user_behavior_summary (
    user_id BIGINT,
    behavior_type STRING,
    behavior_count BIGINT,
    first_behavior_time TIMESTAMP(3),
    last_behavior_time TIMESTAMP(3),
    window_start TIMESTAMP(3),
    window_end TIMESTAMP(3),
    PRIMARY KEY (user_id, behavior_type, window_start) NOT ENFORCED
) WITH (
    'bucket' = '4',
    'bucket-key' = 'user_id',
    'changelog-producer' = 'input',
    'merge-engine' = 'deduplicate',
    'file.format' = 'parquet',
    'compression' = 'snappy',
    'target-file-size' = '64MB',
    'write-buffer-size' = '128MB'
) PARTITIONED BY (window_start);

-- 订单汇总表
CREATE TABLE order_summary (
    user_id BIGINT,
    total_orders BIGINT,
    total_amount DECIMAL(15,2),
    avg_order_value DECIMAL(10,2),
    first_order_time TIMESTAMP(3),
    last_order_time TIMESTAMP(3),
    window_start TIMESTAMP(3),
    window_end TIMESTAMP(3),
    PRIMARY KEY (user_id, window_start) NOT ENFORCED
) WITH (
    'bucket' = '4',
    'bucket-key' = 'user_id',
    'changelog-producer' = 'input',
    'merge-engine' = 'deduplicate',
    'file.format' = 'parquet',
    'compression' = 'snappy',
    'target-file-size' = '64MB',
    'write-buffer-size' = '128MB'
) PARTITIONED BY (window_start);

-- 商品销售统计表
CREATE TABLE product_sales_stats (
    product_id BIGINT,
    product_name STRING,
    category STRING,
    total_sales BIGINT,
    total_revenue DECIMAL(15,2),
    avg_price DECIMAL(10,2),
    window_start TIMESTAMP(3),
    window_end TIMESTAMP(3),
    PRIMARY KEY (product_id, window_start) NOT ENFORCED
) WITH (
    'bucket' = '4',
    'bucket-key' = 'product_id',
    'changelog-producer' = 'input',
    'merge-engine' = 'deduplicate',
    'file.format' = 'parquet',
    'compression' = 'snappy',
    'target-file-size' = '64MB',
    'write-buffer-size' = '128MB'
) PARTITIONED BY (window_start);

-- 实时用户画像表
CREATE TABLE user_profile (
    user_id BIGINT,
    total_behaviors BIGINT,
    total_orders BIGINT,
    total_spent DECIMAL(15,2),
    favorite_category STRING,
    last_activity_time TIMESTAMP(3),
    update_time TIMESTAMP(3),
    PRIMARY KEY (user_id) NOT ENFORCED
) WITH (
    'bucket' = '4',
    'bucket-key' = 'user_id',
    'changelog-producer' = 'input',
    'merge-engine' = 'deduplicate',
    'file.format' = 'parquet',
    'compression' = 'snappy',
    'target-file-size' = '64MB',
    'write-buffer-size' = '128MB'
);

-- ==================== 4. 流式处理作业 ====================

-- 作业1: 用户行为实时汇总
INSERT INTO user_behavior_summary
SELECT 
    user_id,
    behavior as behavior_type,
    COUNT(*) as behavior_count,
    MIN(ts) as first_behavior_time,
    MAX(ts) as last_behavior_time,
    TUMBLE_START(ts, INTERVAL '5' MINUTE) as window_start,
    TUMBLE_END(ts, INTERVAL '5' MINUTE) as window_end
FROM kafka_user_behavior
GROUP BY user_id, behavior, TUMBLE(ts, INTERVAL '5' MINUTE);

-- 作业2: 订单实时汇总
INSERT INTO order_summary
SELECT 
    user_id,
    COUNT(*) as total_orders,
    SUM(price * quantity) as total_amount,
    AVG(price * quantity) as avg_order_value,
    MIN(order_time) as first_order_time,
    MAX(order_time) as last_order_time,
    TUMBLE_START(order_time, INTERVAL '10' MINUTE) as window_start,
    TUMBLE_END(order_time, INTERVAL '10' MINUTE) as window_end
FROM kafka_orders
GROUP BY user_id, TUMBLE(order_time, INTERVAL '10' MINUTE);

-- 作业3: 商品销售统计
INSERT INTO product_sales_stats
SELECT 
    o.product_id,
    p.product_name,
    p.category,
    SUM(o.quantity) as total_sales,
    SUM(o.price * o.quantity) as total_revenue,
    AVG(o.price) as avg_price,
    TUMBLE_START(o.order_time, INTERVAL '15' MINUTE) as window_start,
    TUMBLE_END(o.order_time, INTERVAL '15' MINUTE) as window_end
FROM kafka_orders o
LEFT JOIN kafka_products p ON o.product_id = p.product_id
GROUP BY o.product_id, p.product_name, p.category, TUMBLE(o.order_time, INTERVAL '15' MINUTE);

-- 作业4: 实时用户画像更新
INSERT INTO user_profile
SELECT 
    u.user_id,
    u.behavior_count as total_behaviors,
    COALESCE(o.total_orders, 0) as total_orders,
    COALESCE(o.total_amount, 0) as total_spent,
    u.behavior_type as favorite_category,
    GREATEST(u.last_behavior_time, o.last_order_time) as last_activity_time,
    CURRENT_TIMESTAMP as update_time
FROM (
    SELECT 
        user_id,
        SUM(behavior_count) as behavior_count,
        MAX(last_behavior_time) as last_behavior_time,
        behavior_type
    FROM user_behavior_summary
    WHERE window_start >= CURRENT_TIMESTAMP - INTERVAL '1' HOUR
    GROUP BY user_id, behavior_type
) u
LEFT JOIN (
    SELECT 
        user_id,
        SUM(total_orders) as total_orders,
        SUM(total_amount) as total_amount,
        MAX(last_order_time) as last_order_time
    FROM order_summary
    WHERE window_start >= CURRENT_TIMESTAMP - INTERVAL '1' HOUR
    GROUP BY user_id
) o ON u.user_id = o.user_id;

-- ==================== 5. 高级分析作业 ====================

-- 创建实时推荐表
CREATE TABLE real_time_recommendations (
    user_id BIGINT,
    recommended_products ARRAY<BIGINT>,
    recommendation_score DECIMAL(5,4),
    recommendation_time TIMESTAMP(3),
    PRIMARY KEY (user_id) NOT ENFORCED
) WITH (
    'bucket' = '4',
    'bucket-key' = 'user_id',
    'changelog-producer' = 'input',
    'merge-engine' = 'deduplicate',
    'file.format' = 'parquet',
    'compression' = 'snappy'
);

-- 实时推荐作业
INSERT INTO real_time_recommendations
SELECT 
    up.user_id,
    ARRAY[ps.product_id] as recommended_products,
    CASE 
        WHEN up.total_spent > 1000 THEN 0.9
        WHEN up.total_spent > 500 THEN 0.7
        ELSE 0.5
    END as recommendation_score,
    CURRENT_TIMESTAMP as recommendation_time
FROM user_profile up
CROSS JOIN (
    SELECT DISTINCT product_id 
    FROM product_sales_stats 
    WHERE window_start >= CURRENT_TIMESTAMP - INTERVAL '1' HOUR
    ORDER BY total_revenue DESC 
    LIMIT 10
) ps
WHERE up.last_activity_time >= CURRENT_TIMESTAMP - INTERVAL '30' MINUTE;

-- ==================== 6. 数据质量监控作业 ====================

-- 创建数据质量监控表
CREATE TABLE data_quality_metrics (
    table_name STRING,
    metric_type STRING,
    metric_value BIGINT,
    quality_score DECIMAL(5,2),
    check_time TIMESTAMP(3),
    PRIMARY KEY (table_name, metric_type, check_time) NOT ENFORCED
) WITH (
    'bucket' = '4',
    'bucket-key' = 'table_name',
    'changelog-producer' = 'input',
    'merge-engine' = 'deduplicate',
    'file.format' = 'parquet',
    'compression' = 'snappy'
) PARTITIONED BY (check_time);

-- 数据质量监控作业
INSERT INTO data_quality_metrics
SELECT 
    'user_behavior_summary' as table_name,
    'record_count' as metric_type,
    COUNT(*) as metric_value,
    CASE 
        WHEN COUNT(*) > 0 THEN 100.0
        ELSE 0.0
    END as quality_score,
    CURRENT_TIMESTAMP as check_time
FROM user_behavior_summary
WHERE window_start >= CURRENT_TIMESTAMP - INTERVAL '1' HOUR
UNION ALL
SELECT 
    'order_summary' as table_name,
    'record_count' as metric_type,
    COUNT(*) as metric_value,
    CASE 
        WHEN COUNT(*) > 0 THEN 100.0
        ELSE 0.0
    END as quality_score,
    CURRENT_TIMESTAMP as check_time
FROM order_summary
WHERE window_start >= CURRENT_TIMESTAMP - INTERVAL '1' HOUR;

-- ==================== 7. 性能优化作业 ====================

-- 创建优化后的宽表
CREATE TABLE user_behavior_wide (
    user_id BIGINT,
    behavior_type STRING,
    behavior_count BIGINT,
    order_count BIGINT,
    total_spent DECIMAL(15,2),
    behavior_time TIMESTAMP(3),
    order_time TIMESTAMP(3),
    window_start TIMESTAMP(3),
    PRIMARY KEY (user_id, behavior_type, window_start) NOT ENFORCED
) WITH (
    'bucket' = '8',  -- 增加并行度
    'bucket-key' = 'user_id',
    'changelog-producer' = 'input',
    'merge-engine' = 'deduplicate',
    'file.format' = 'parquet',
    'compression' = 'snappy',
    'target-file-size' = '32MB',  -- 优化文件大小
    'write-buffer-size' = '64MB'   -- 优化写入缓冲区
) PARTITIONED BY (window_start);

-- 宽表数据同步作业
INSERT INTO user_behavior_wide
SELECT 
    ubs.user_id,
    ubs.behavior_type,
    ubs.behavior_count,
    COALESCE(os.total_orders, 0) as order_count,
    COALESCE(os.total_amount, 0) as total_spent,
    ubs.last_behavior_time as behavior_time,
    os.last_order_time as order_time,
    ubs.window_start
FROM user_behavior_summary ubs
LEFT JOIN order_summary os ON ubs.user_id = os.user_id 
    AND ubs.window_start = os.window_start;

-- ==================== 8. 时间窗口聚合作业 ====================

-- 创建小时级聚合表
CREATE TABLE hourly_aggregations (
    aggregation_type STRING,
    aggregation_key STRING,
    aggregation_value BIGINT,
    aggregation_time TIMESTAMP(3),
    PRIMARY KEY (aggregation_type, aggregation_key, aggregation_time) NOT ENFORCED
) WITH (
    'bucket' = '4',
    'bucket-key' = 'aggregation_type',
    'changelog-producer' = 'input',
    'merge-engine' = 'deduplicate',
    'file.format' = 'parquet',
    'compression' = 'snappy'
) PARTITIONED BY (aggregation_time);

-- 小时级聚合作业
INSERT INTO hourly_aggregations
SELECT 
    'user_behavior' as aggregation_type,
    behavior as aggregation_key,
    COUNT(*) as aggregation_value,
    TUMBLE_START(ts, INTERVAL '1' HOUR) as aggregation_time
FROM kafka_user_behavior
GROUP BY behavior, TUMBLE(ts, INTERVAL '1' HOUR)
UNION ALL
SELECT 
    'order_revenue' as aggregation_type,
    'total' as aggregation_key,
    SUM(price * quantity) as aggregation_value,
    TUMBLE_START(order_time, INTERVAL '1' HOUR) as aggregation_time
FROM kafka_orders
GROUP BY TUMBLE(order_time, INTERVAL '1' HOUR);

-- ==================== 9. 数据清理作业 ====================

-- 创建数据清理配置表
CREATE TABLE data_cleanup_config (
    table_name STRING,
    retention_days INT,
    cleanup_enabled BOOLEAN,
    last_cleanup_time TIMESTAMP(3),
    PRIMARY KEY (table_name) NOT ENFORCED
) WITH (
    'bucket' = '4',
    'bucket-key' = 'table_name',
    'changelog-producer' = 'input',
    'merge-engine' = 'deduplicate',
    'file.format' = 'parquet',
    'compression' = 'snappy'
);

-- 插入清理配置
INSERT INTO data_cleanup_config VALUES
('user_behavior_summary', 7, true, CURRENT_TIMESTAMP),
('order_summary', 30, true, CURRENT_TIMESTAMP),
('product_sales_stats', 90, true, CURRENT_TIMESTAMP),
('user_profile', 365, true, CURRENT_TIMESTAMP);

-- ==================== 10. 监控和告警作业 ====================

-- 创建系统监控表
CREATE TABLE system_monitoring (
    metric_name STRING,
    metric_value DECIMAL(10,2),
    metric_unit STRING,
    alert_threshold DECIMAL(10,2),
    alert_level STRING,
    check_time TIMESTAMP(3),
    PRIMARY KEY (metric_name, check_time) NOT ENFORCED
) WITH (
    'bucket' = '4',
    'bucket-key' = 'metric_name',
    'changelog-producer' = 'input',
    'merge-engine' = 'deduplicate',
    'file.format' = 'parquet',
    'compression' = 'snappy'
) PARTITIONED BY (check_time);

-- 系统监控作业
INSERT INTO system_monitoring
SELECT 
    'records_per_second' as metric_name,
    COUNT(*) / 60.0 as metric_value,
    'records/s' as metric_unit,
    1000.0 as alert_threshold,
    CASE 
        WHEN COUNT(*) / 60.0 > 1000 THEN 'HIGH'
        WHEN COUNT(*) / 60.0 > 500 THEN 'MEDIUM'
        ELSE 'LOW'
    END as alert_level,
    CURRENT_TIMESTAMP as check_time
FROM kafka_user_behavior
WHERE ts >= CURRENT_TIMESTAMP - INTERVAL '1' MINUTE;

-- ==================== 使用说明 ====================

/*
使用说明：

1. 执行环境：
   - 确保Flink JobManager和TaskManager已启动
   - 确保Paimon Catalog已创建
   - 确保Kafka主题已创建

2. 数据源：
   - user-behavior: 用户行为数据
   - orders: 订单数据
   - products: 商品数据

3. 主要功能：
   - 实时数据流处理
   - 多时间窗口聚合
   - 实时用户画像
   - 数据质量监控
   - 性能优化

4. 监控访问：
   - Flink Web UI: http://localhost:8081
   - Grafana: http://localhost:3000
   - Paimon数据: s3://bigdata-lake/paimon

5. 注意事项：
   - 所有表都支持流式读写
   - 支持ACID事务
   - 支持时间旅行查询
   - 支持增量查询
   - 支持数据清理和优化
*/ 