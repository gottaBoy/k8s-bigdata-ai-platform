# Docker Compose本地测试环境

## 📋 概述

这是一个基于Docker Compose的大数据AI平台本地测试环境，让您可以在本地快速体验完整的大数据AI平台功能，无需复杂的K8s集群部署。

## 🏗️ 架构组件

```
┌─────────────────────────────────────────────────────────────┐
│                Docker Compose本地测试环境                    │
├─────────────────────────────────────────────────────────────┤
│ 前端层: Superset + Grafana + JupyterHub                     │
├─────────────────────────────────────────────────────────────┤
│ 计算层: Flink流处理引擎 + Paimon数据湖                       │
├─────────────────────────────────────────────────────────────┤
│ 存储层: MinIO + Doris + Redis + Paimon                      │
├─────────────────────────────────────────────────────────────┤
│ 消息层: Kafka + Zookeeper                                   │
├─────────────────────────────────────────────────────────────┤
│ 调度层: Airflow工作流                                        │
├─────────────────────────────────────────────────────────────┤
│ 监控层: Prometheus + Grafana                                 │
├─────────────────────────────────────────────────────────────┤
│ 基础设施: Docker + Docker Compose                           │
└─────────────────────────────────────────────────────────────┘
```

## 🚀 快速开始

### 前置要求

- **Docker**: 20.10+
- **Docker Compose**: 2.0+
- **系统资源**: 
  - CPU: 4核+
  - 内存: 8GB+
  - 存储: 20GB+

### 一键启动

```bash
# 克隆项目
git clone <repository-url>
cd k8s-bigdata-ai-platform/docker-compose

# 一键启动
./start.sh
```

### 手动启动

```bash
# 1. 启动所有服务
docker-compose up -d

# 2. 查看服务状态
docker-compose ps

# 3. 初始化数据
./scripts/init-data.sh

# 4. 查看日志
docker-compose logs -f
```

## 📊 服务访问

### 核心服务

| 服务 | 功能 | 访问地址 | 默认账号 |
|------|------|----------|----------|
| **MinIO** | 对象存储 | http://localhost:9001 | admin/minio123 |
| **Kafka UI** | 消息队列管理 | http://localhost:8082 | - |
| **Doris FE** | 数据仓库前端 | http://localhost:8030 | - |
| **Doris BE** | 数据仓库后端 | http://localhost:8040 | - |
| **Flink** | 流处理引擎 | http://localhost:8081 | - |
| **Paimon** | 数据湖存储 | s3://bigdata-lake/paimon | - |

### 应用服务

| 服务 | 功能 | 访问地址 | 默认账号 |
|------|------|----------|----------|
| **Grafana** | 监控面板 | http://localhost:3000 | admin/admin123 |
| **Prometheus** | 指标收集 | http://localhost:9090 | - |
| **Airflow** | 工作流调度 | http://localhost:8080 | admin/admin123 |
| **Superset** | 数据可视化 | http://localhost:8088 | admin/admin123 |
| **JupyterHub** | 开发环境 | http://localhost:8000 | admin/jupyter123 |

### 连接信息

| 服务 | 连接地址 | 账号密码 |
|------|----------|----------|
| **MinIO** | localhost:9000 | admin/minio123 |
| **Kafka** | localhost:9092 | - |
| **Doris** | localhost:9030 | root/root |
| **Redis** | localhost:6379 | redis123 |
| **PostgreSQL** | localhost:5432 | airflow/airflow123 |

## 🔧 常用操作

### 服务管理

```bash
# 启动所有服务
docker-compose up -d

# 启动特定服务
docker-compose up -d minio kafka doris-fe

# 停止所有服务
docker-compose stop

# 停止特定服务
docker-compose stop airflow superset

# 重启服务
docker-compose restart flink-jobmanager

# 查看服务状态
docker-compose ps

# 查看服务日志
docker-compose logs -f minio
docker-compose logs -f kafka
docker-compose logs -f doris-fe
```

### 数据操作

```bash
# 初始化数据
./scripts/init-data.sh

# 连接MinIO
docker exec -it minio-client mc ls myminio/

# 连接Kafka
docker exec -it kafka kafka-topics --list --bootstrap-server localhost:9092

# 连接Doris
docker exec -it doris-fe mysql -h localhost -P 9030 -u root -p

# 连接Redis
docker exec -it redis redis-cli -a redis123
```

### 监控和日志

```bash
# 查看所有容器状态
docker-compose ps

# 查看资源使用
docker stats

# 查看服务日志
docker-compose logs -f

# 查看特定服务日志
docker-compose logs -f prometheus
docker-compose logs -f grafana
```

## 📝 使用示例

### 1. MinIO对象存储

```bash
# 访问MinIO控制台
# 浏览器打开: http://localhost:9001

# 使用MinIO客户端
docker exec -it minio-client mc ls myminio/
docker exec -it minio-client mc cp /tmp/file.txt myminio/bigdata-lake/
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

# 提交Flink作业
docker exec -it flink-jobmanager flink run /opt/flink/examples/streaming/WordCount.jar

# 使用Paimon数据湖
docker exec -it flink-jobmanager /opt/flink/bin/sql-client.sh

# 在SQL Client中执行Paimon操作
USE CATALOG paimon;
SHOW TABLES;
SELECT * FROM user_events LIMIT 10;
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

## 🛠️ 配置说明

### 环境变量

```bash
# 复制环境变量模板
cp .env.template .env

# 编辑配置
vim .env
```

### 服务配置

- **MinIO配置**: `config/minio/`
- **Kafka配置**: `config/kafka/`
- **Doris配置**: `config/doris/`
- **Flink配置**: `config/flink/`
- **Prometheus配置**: `config/prometheus/`
- **Grafana配置**: `config/grafana/`
- **Airflow配置**: `config/airflow/`
- **Superset配置**: `config/superset/`
- **JupyterHub配置**: `config/jupyterhub/`

## 🔍 故障排查

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
   docker network inspect docker-compose_bigdata-network
   
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

### 日志分析

```bash
# 查看所有日志
docker-compose logs

# 查看特定服务日志
docker-compose logs -f minio
docker-compose logs -f kafka
docker-compose logs -f doris-fe

# 查看错误日志
docker-compose logs | grep ERROR
```

## 📈 性能优化

### 资源调优

```yaml
# 在docker-compose.yml中调整资源配置
services:
  flink-jobmanager:
    deploy:
      resources:
        limits:
          memory: 2G
          cpus: '1.0'
        reservations:
          memory: 1G
          cpus: '0.5'
```

### 存储优化

```bash
# 使用本地存储
volumes:
  minio_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /data/minio
```

## 🧹 清理环境

```bash
# 停止所有服务
docker-compose stop

# 停止并删除容器
docker-compose down

# 删除所有数据卷
docker-compose down -v

# 删除所有镜像
docker-compose down --rmi all

# 清理未使用的资源
docker system prune -a
```

## 📚 更多资源

- [Docker Compose文档](https://docs.docker.com/compose/)
- [MinIO文档](https://docs.min.io/)
- [Kafka文档](https://kafka.apache.org/documentation/)
- [Doris文档](https://doris.apache.org/docs/)
- [Flink文档](https://flink.apache.org/docs/)
- [Airflow文档](https://airflow.apache.org/docs/)
- [Superset文档](https://superset.apache.org/docs/)
- [JupyterHub文档](https://jupyterhub.readthedocs.io/)

## 🤝 获取帮助

- **文档**: [完整文档](../README.md)
- **Issues**: [GitHub Issues](https://github.com/your-repo/issues)
- **讨论**: [GitHub Discussions](https://github.com/your-repo/discussions)

---

**注意**: 这是一个本地测试环境，适用于开发和测试。生产环境请使用K8s部署方案。 