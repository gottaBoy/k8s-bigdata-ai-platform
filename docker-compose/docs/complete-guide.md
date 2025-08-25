# 大数据AI平台完整使用指南

## 📋 概述

这是一个基于Docker Compose的完整大数据AI平台，集成了Paimon数据湖、Flink流处理、Kafka消息队列、Doris数据仓库、MinIO对象存储等核心组件，提供从数据采集、存储、处理到可视化的完整解决方案。

## 🏗️ 平台架构

```
┌─────────────────────────────────────────────────────────────┐
│                    大数据AI平台架构                          │
├─────────────────────────────────────────────────────────────┤
│ 应用层: Superset + Grafana + JupyterHub + Airflow          │
├─────────────────────────────────────────────────────────────┤
│ 计算层: Flink流处理引擎 + Paimon数据湖                      │
├─────────────────────────────────────────────────────────────┤
│ 存储层: MinIO对象存储 + Doris数据仓库 + Redis缓存           │
├─────────────────────────────────────────────────────────────┤
│ 消息层: Kafka消息队列 + Zookeeper协调服务                   │
├─────────────────────────────────────────────────────────────┤
│ 监控层: Prometheus指标收集 + Grafana可视化                  │
├─────────────────────────────────────────────────────────────┤
│ 基础设施: Docker + Docker Compose                          │
└─────────────────────────────────────────────────────────────┘
```

## 🚀 快速开始

### 1. 环境准备

#### 系统要求
- **操作系统**: macOS 10.15+, Ubuntu 18.04+, CentOS 7+
- **Docker**: 20.10+
- **Docker Compose**: 2.0+
- **系统资源**: 
  - CPU: 4核+
  - 内存: 8GB+
  - 存储: 20GB+

#### 安装Docker
```bash
# macOS
brew install docker docker-compose

# Ubuntu
sudo apt update
sudo apt install docker.io docker-compose

# CentOS
sudo yum install docker docker-compose
```

### 2. 启动平台

```bash
# 克隆项目
git clone <repository-url>
cd k8s-bigdata-ai-platform/docker-compose

# 一键启动
./start.sh

# 或使用Makefile
make start
```

### 3. 验证部署

```bash
# 健康检查
make health-check

# 快速测试
make test

# 查看状态
make status
```

## 📊 服务访问

### 核心服务

| 服务 | 功能 | 访问地址 | 默认账号 | 说明 |
|------|------|----------|----------|------|
| **MinIO** | 对象存储 | http://localhost:9001 | admin/minio123 | S3兼容的对象存储 |
| **Kafka UI** | 消息队列管理 | http://localhost:8082 | - | Kafka主题和消息管理 |
| **Doris FE** | 数据仓库前端 | http://localhost:8030 | - | Doris查询界面 |
| **Doris BE** | 数据仓库后端 | http://localhost:8040 | - | Doris存储节点 |
| **Flink** | 流处理引擎 | http://localhost:8081 | - | Flink作业管理 |
| **Paimon** | 数据湖存储 | s3://bigdata-lake/paimon | - | 流式数据湖 |

### 应用服务

| 服务 | 功能 | 访问地址 | 默认账号 | 说明 |
|------|------|----------|----------|------|
| **Grafana** | 监控面板 | http://localhost:3000 | admin/admin123 | 系统监控和告警 |
| **Prometheus** | 指标收集 | http://localhost:9090 | - | 时序数据收集 |
| **Airflow** | 工作流调度 | http://localhost:8080 | admin/admin123 | 数据管道编排 |
| **Superset** | 数据可视化 | http://localhost:8088 | admin/admin123 | 商业智能分析 |
| **JupyterHub** | 开发环境 | http://localhost:8000 | admin/jupyter123 | 数据科学工作台 |

### 连接信息

| 服务 | 连接地址 | 账号密码 | 说明 |
|------|----------|----------|------|
| **MinIO** | localhost:9000 | admin/minio123 | S3 API端点 |
| **Kafka** | localhost:9092 | - | 消息队列端点 |
| **Doris** | localhost:9030 | root/root | MySQL协议端点 |
| **Redis** | localhost:6379 | redis123 | 缓存服务端点 |
| **PostgreSQL** | localhost:5432 | airflow/airflow123 | 元数据存储 |

## 🔧 常用操作

### 服务管理

```bash
# 启动所有服务
make start

# 启动特定服务
make start-storage      # 存储服务
make start-messaging    # 消息队列
make start-database     # 数据仓库
make start-streaming    # 流处理
make start-monitoring   # 监控服务
make start-apps         # 应用服务

# 停止服务
make stop

# 重启服务
make restart

# 查看状态
make status

# 查看日志
make logs
```

### 数据操作

```bash
# 初始化数据
make init-data

# 备份数据
make backup

# 恢复数据
make restore

# 数据压缩
make compact

# 数据清理
make cleanup
```

### 监控和健康检查

```bash
# 健康检查
make health-check

# 性能监控
make monitor

# 快速测试
make test

# 性能基准测试
make benchmark
```

### 优化和维护

```bash
# 性能优化
make optimize

# 升级服务
make upgrade

# 安全扫描
make security-scan

# 故障排查
make troubleshoot
```

## 📝 使用示例

### 1. MinIO对象存储

```bash
# 访问MinIO控制台
# 浏览器打开: http://localhost:9001

# 使用MinIO客户端
docker exec -it minio-client mc ls myminio/
docker exec -it minio-client mc cp /tmp/file.txt myminio/bigdata-lake/
docker exec -it minio-client mc policy set public myminio/bigdata-lake
```

### 2. Kafka消息队列

```bash
# 访问Kafka UI
# 浏览器打开: http://localhost:8082

# 创建主题
docker exec -it kafka kafka-topics --create --bootstrap-server localhost:9092 --topic test-topic --partitions 3 --replication-factor 1

# 发送消息
docker exec -it kafka kafka-console-producer --bootstrap-server localhost:9092 --topic test-topic

# 消费消息
docker exec -it kafka kafka-console-consumer --bootstrap-server localhost:9092 --topic test-topic --from-beginning
```

### 3. Doris数据仓库

```bash
# 连接Doris
docker exec -it doris-fe mysql -h localhost -P 9030 -u root -p

# 创建数据库
CREATE DATABASE bigdata_platform;

# 创建表
USE bigdata_platform;
CREATE TABLE user_events (
    user_id BIGINT,
    event_type VARCHAR(50),
    event_time DATETIME,
    properties JSON
) DUPLICATE KEY(user_id, event_time)
DISTRIBUTED BY HASH(user_id) BUCKETS 10;
```

### 4. Flink流处理 + Paimon数据湖

```bash
# 访问Flink Web UI
# 浏览器打开: http://localhost:8081

# 使用Paimon数据湖
docker exec -it flink-jobmanager /opt/flink/bin/sql-client.sh

# 在SQL Client中执行
USE CATALOG paimon;
SHOW TABLES;
SELECT * FROM user_events LIMIT 10;

# 提交Flink作业
docker exec -it flink-jobmanager flink run /opt/flink/examples/streaming/WordCount.jar
```

### 5. Airflow工作流

```bash
# 访问Airflow Web UI
# 浏览器打开: http://localhost:8080

# 查看DAG
docker exec -it airflow-webserver airflow dags list

# 触发DAG
docker exec -it airflow-webserver airflow dags trigger data_pipeline_demo
```

### 6. Superset可视化

```bash
# 访问Superset
# 浏览器打开: http://localhost:8088

# 配置数据源
# 1. 点击 "Data" -> "Databases"
# 2. 添加Doris数据源: mysql+pymysql://root:root@doris-fe:9030/bigdata_platform
# 3. 创建图表和仪表板
```

### 7. JupyterHub开发环境

```bash
# 访问JupyterHub
# 浏览器打开: http://localhost:8000

# 创建Notebook
# 在JupyterLab中编写和运行代码
```

## 🔍 监控和告警

### Grafana仪表板

平台预置了多个监控仪表板：

1. **Flink Streaming Dashboard**: Flink作业监控
2. **Paimon Data Lake Dashboard**: Paimon数据湖监控
3. **System Overview**: 系统整体监控

### 关键指标

- **Flink作业**: 作业状态、处理速率、延迟
- **Paimon数据湖**: 表数量、存储使用、文件操作
- **系统资源**: CPU、内存、磁盘使用率
- **网络流量**: 数据传输速率、连接数

### 告警配置

```bash
# 查看告警规则
docker exec -it prometheus cat /etc/prometheus/prometheus.yml

# 配置告警
# 编辑 config/prometheus/prometheus.yml
```

## 🛠️ 配置优化

### Flink配置优化

```bash
# 编辑Flink配置
vim config/flink/flink-conf.yaml

# 关键配置项
taskmanager.numberOfTaskSlots: 4
parallelism.default: 4
execution.checkpointing.interval: 60s
```

### Paimon配置优化

```bash
# 编辑Paimon配置
vim config/paimon/paimon-catalog.conf

# 关键配置项
bucket: 4
target-file-size: 64MB
write-buffer-size: 128MB
```

### 系统资源优化

```bash
# 调整Docker资源限制
# 编辑 docker-compose.yml
services:
  flink-taskmanager:
    deploy:
      resources:
        limits:
          memory: 4G
          cpus: '2.0'
```

## 🔧 故障排查

### 常见问题

1. **服务启动失败**
   ```bash
   # 查看服务日志
   docker-compose logs <service-name>
   
   # 检查端口占用
   netstat -tulpn | grep :8080
   
   # 重启服务
   docker-compose restart <service-name>
   ```

2. **数据连接失败**
   ```bash
   # 检查网络连接
   docker network ls
   docker network inspect bigdata-network
   
   # 测试服务连通性
   docker exec -it <container-name> ping <service-name>
   ```

3. **资源不足**
   ```bash
   # 查看资源使用
   docker stats
   
   # 调整资源限制
   # 编辑docker-compose.yml中的resources配置
   ```

### 诊断工具

```bash
# 健康检查
make health-check

# 故障排查
make troubleshoot

# 性能基准测试
make benchmark

# 安全扫描
make security-scan
```

## 📈 性能优化

### 存储优化

1. **MinIO优化**
   - 启用压缩
   - 配置生命周期策略
   - 使用SSD存储

2. **Paimon优化**
   - 调整bucket数量
   - 优化文件大小
   - 配置合并策略

3. **Doris优化**
   - 合理设置分桶数
   - 优化索引
   - 配置缓存

### 计算优化

1. **Flink优化**
   - 调整并行度
   - 优化检查点配置
   - 配置状态后端

2. **内存优化**
   - 调整JVM参数
   - 配置堆内存大小
   - 优化GC策略

### 网络优化

1. **容器网络**
   - 使用host网络模式
   - 配置网络策略
   - 优化DNS解析

## 🔒 安全配置

### 访问控制

1. **服务认证**
   - 配置用户名密码
   - 启用SSL/TLS
   - 设置访问权限

2. **网络安全**
   - 配置防火墙规则
   - 使用VPN访问
   - 限制端口访问

### 数据安全

1. **数据加密**
   - 传输加密
   - 存储加密
   - 密钥管理

2. **备份策略**
   - 定期备份
   - 异地备份
   - 恢复测试

## 📚 最佳实践

### 开发实践

1. **代码管理**
   - 使用版本控制
   - 代码审查
   - 自动化测试

2. **部署实践**
   - 蓝绿部署
   - 滚动更新
   - 回滚策略

### 运维实践

1. **监控告警**
   - 设置关键指标
   - 配置告警规则
   - 建立响应流程

2. **容量规划**
   - 资源评估
   - 扩容策略
   - 成本优化

### 数据管理

1. **数据治理**
   - 数据质量监控
   - 元数据管理
   - 数据血缘追踪

2. **生命周期管理**
   - 数据归档
   - 清理策略
   - 合规要求

## 🤝 获取帮助

### 文档资源

- **官方文档**: [项目文档](../README.md)
- **快速入门**: [Paimon指南](paimon-quickstart.md)
- **使用示例**: [examples目录](../examples/)

### 社区支持

- **GitHub Issues**: [问题反馈](https://github.com/your-repo/issues)
- **GitHub Discussions**: [技术讨论](https://github.com/your-repo/discussions)
- **邮件列表**: [邮件支持](mailto:support@example.com)

### 商业支持

- **技术支持**: 7x24小时技术支持
- **培训服务**: 定制化培训课程
- **咨询服务**: 架构设计和优化

---

**注意**: 本指南基于最新版本编写，请根据实际版本调整配置参数。如有问题，请参考官方文档或联系技术支持。 