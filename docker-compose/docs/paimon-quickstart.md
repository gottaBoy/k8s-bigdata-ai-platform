# Paimon数据湖快速入门指南

## 📋 概述

Paimon是一个流式数据湖存储系统，与Apache Flink深度集成，提供高性能的流式读写、ACID事务、时间旅行查询等功能。本指南将帮助您快速上手Paimon数据湖。

## 🏗️ 架构特点

```
┌─────────────────────────────────────────────────────────────┐
│                    Paimon数据湖架构                          │
├─────────────────────────────────────────────────────────────┤
│ 应用层: Flink SQL + 流处理作业                              │
├─────────────────────────────────────────────────────────────┤
│ 存储层: Paimon Catalog + S3/MinIO                           │
├─────────────────────────────────────────────────────────────┤
│ 文件格式: Parquet + 增量文件                                │
├─────────────────────────────────────────────────────────────┤
│ 元数据: 快照 + 清单文件                                     │
└─────────────────────────────────────────────────────────────┘
```

## 🚀 快速开始

### 1. 环境准备

确保Docker Compose环境已启动：

```bash
cd docker-compose
./start.sh
```

### 2. 访问Flink SQL Client

```bash
# 进入Flink JobManager容器
docker exec -it flink-jobmanager bash

# 启动SQL Client
/opt/flink/bin/sql-client.sh
```

### 3. 基础操作

#### 3.1 使用Paimon Catalog

```sql
-- 使用Paimon Catalog
USE CATALOG paimon;

-- 查看数据库
SHOW DATABASES;

-- 使用默认数据库
USE default_database;

-- 查看表
SHOW TABLES;
```

#### 3.2 创建表

```sql
-- 创建用户事件表
CREATE TABLE user_events (
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
```

#### 3.3 插入数据

```sql
-- 插入示例数据
INSERT INTO user_events VALUES
(1, 'click', TIMESTAMP '2024-01-01 10:00:00', '{"page": "/home"}'),
(2, 'purchase', TIMESTAMP '2024-01-01 10:05:00', '{"product_id": "123"}'),
(3, 'view', TIMESTAMP '2024-01-01 10:10:00', '{"page": "/product"}');
```

#### 3.4 查询数据

```sql
-- 查询用户事件
SELECT * FROM user_events WHERE event_date = '2024-01-01';

-- 统计事件类型
SELECT event_type, COUNT(*) as count 
FROM user_events 
GROUP BY event_type;
```

## 📊 流式数据处理

### 1. 创建Kafka数据源

```sql
-- 创建Kafka用户事件源表
CREATE TABLE kafka_user_events (
    user_id BIGINT,
    event_type STRING,
    event_time TIMESTAMP(3),
    properties STRING,
    WATERMARK FOR event_time AS event_time - INTERVAL '5' SECOND
) WITH (
    'connector' = 'kafka',
    'topic' = 'user-events',
    'properties.bootstrap.servers' = 'kafka:29092',
    'properties.group.id' = 'paimon-group',
    'scan.startup.mode' = 'latest-offset',
    'format' = 'json'
);
```

### 2. 流式写入Paimon

```sql
-- 从Kafka流式写入Paimon
INSERT INTO user_events
SELECT user_id, event_type, event_time, properties
FROM kafka_user_events;
```

### 3. 实时聚合

```sql
-- 创建小时级聚合表
CREATE TABLE user_events_hourly (
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

-- 小时级聚合
INSERT INTO user_events_hourly
SELECT 
    event_type,
    TUMBLE_START(event_time, INTERVAL '1' HOUR) as event_hour,
    COUNT(DISTINCT user_id) as user_count,
    COUNT(*) as event_count
FROM kafka_user_events
GROUP BY event_type, TUMBLE(event_time, INTERVAL '1' HOUR);
```

## 🔍 高级功能

### 1. 时间旅行查询

```sql
-- 查看表快照
SHOW SNAPSHOTS FROM user_events;

-- 时间旅行查询（查询特定时间点的数据）
SELECT * FROM user_events FOR SYSTEM_TIME AS OF '2024-01-01 10:00:00';
```

### 2. 增量查询

```sql
-- 增量查询（查询指定快照范围的数据）
SELECT * FROM user_events FOR SYSTEM_VERSION AS OF 1;
SELECT * FROM user_events FOR SYSTEM_VERSION AS OF 2;
```

### 3. 数据湖优化

```sql
-- 创建优化表
CREATE TABLE user_events_optimized (
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
```

## 📈 监控和管理

### 1. 查看表信息

```sql
-- 查看表结构
DESCRIBE user_events;

-- 查看表文件
SHOW FILES FROM user_events;

-- 查看表统计信息
SHOW STATISTICS FROM user_events;
```

### 2. 数据湖管理

```sql
-- 删除过期数据
DELETE FROM user_events WHERE event_date < CURRENT_DATE - INTERVAL '30' DAY;

-- 清理快照
-- 注意：这需要在Flink SQL Client中执行
-- CALL paimon.system.cleanup('user_events', '30d');
```

### 3. 性能监控

```sql
-- 创建监控表
CREATE TABLE paimon_metrics (
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
```

## 🔧 配置优化

### 1. 存储配置

```sql
-- 优化存储配置
CREATE TABLE optimized_table (
    id BIGINT,
    data STRING,
    ts TIMESTAMP(3)
) WITH (
    'bucket' = '8',                    -- 增加并行度
    'bucket-key' = 'id',               -- 分区键
    'changelog-producer' = 'input',    -- 变更日志生产者
    'merge-engine' = 'deduplicate',    -- 合并引擎
    'file.format' = 'parquet',         -- 文件格式
    'compression' = 'snappy',          -- 压缩格式
    'target-file-size' = '64MB',       -- 目标文件大小
    'write-buffer-size' = '128MB',     -- 写入缓冲区大小
    'read.buffer.size' = '32MB',       -- 读取缓冲区大小
    'file.expiration' = '7d',          -- 文件过期时间
    'snapshot.expire.duration' = '7d'  -- 快照过期时间
) PARTITIONED BY (ts);
```

### 2. 性能调优

```sql
-- 设置Flink配置
SET 'table.exec.mini-batch.enabled' = 'true';
SET 'table.exec.mini-batch.size' = '1000';
SET 'table.exec.mini-batch.allow-latency' = '1s';
SET 'table.optimizer.agg-phase-strategy' = 'TWO_PHASE';
```

## 📝 最佳实践

### 1. 表设计

- **分区策略**: 按时间分区，提高查询性能
- **Bucket数量**: 根据数据量和并行度设置
- **主键设计**: 选择高基数字段作为主键
- **文件格式**: 使用Parquet格式，支持列式存储

### 2. 数据写入

- **批量写入**: 使用批量插入提高性能
- **流式写入**: 支持实时数据流写入
- **事务保证**: 支持ACID事务

### 3. 查询优化

- **分区裁剪**: 利用分区提高查询效率
- **列裁剪**: 只查询需要的列
- **谓词下推**: 利用索引加速查询

### 4. 运维管理

- **定期清理**: 清理过期数据和快照
- **监控告警**: 监控表大小和查询性能
- **备份恢复**: 定期备份重要数据

## 🚨 常见问题

### 1. 连接问题

**问题**: 无法连接到Paimon Catalog
**解决**: 检查Flink配置和S3连接

```sql
-- 检查Catalog配置
SHOW CATALOGS;
USE CATALOG paimon;
```

### 2. 性能问题

**问题**: 查询速度慢
**解决**: 优化表结构和查询

```sql
-- 查看表统计信息
SHOW STATISTICS FROM table_name;

-- 优化查询
EXPLAIN SELECT * FROM table_name WHERE partition_col = 'value';
```

### 3. 存储问题

**问题**: 存储空间不足
**解决**: 清理过期数据和快照

```sql
-- 删除过期数据
DELETE FROM table_name WHERE date_col < CURRENT_DATE - INTERVAL '30' DAY;
```

## 📚 更多资源

- [Paimon官方文档](https://paimon.apache.org/docs/)
- [Flink SQL文档](https://nightlies.apache.org/flink/flink-docs-stable/docs/dev/table/sql/)
- [流式数据湖最佳实践](https://paimon.apache.org/docs/master/best-practices/)

## 🤝 获取帮助

- **文档**: [完整文档](../README.md)
- **示例**: [Paimon示例](../examples/paimon-examples.sql)
- **配置**: [Paimon配置](../config/paimon/)

---

**注意**: 本指南基于Paimon 0.6.0版本，请根据实际版本调整配置参数。 