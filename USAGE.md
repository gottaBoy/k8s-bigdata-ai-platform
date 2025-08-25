# K8s大数据AI平台 - 使用指南

## 🚀 快速开始

### 1. 一键部署

```bash
# 克隆项目
git clone <repository-url>
cd k8s-bigdata-ai-platform

# 一键部署
./quick-start.sh
```

### 2. 分步部署

```bash
# 初始化环境
make init

# 部署平台
make deploy

# 验证部署
make verify

# 查看访问信息
make access-info
```

## 📋 平台组件

### 核心组件

| 组件 | 功能 | 访问地址 | 默认账号 |
|------|------|----------|----------|
| **Flink** | 流处理引擎 | http://flink.your-domain.com | - |
| **Doris** | 数据仓库 | http://doris.your-domain.com | root/root |
| **MinIO** | 对象存储 | http://minio.your-domain.com | admin/minio123 |
| **Kafka** | 消息队列 | kafka:9092 | - |
| **KubeFlow** | 机器学习 | http://jupyter.your-domain.com | 首次访问创建 |
| **Airflow** | 工作流调度 | http://airflow.your-domain.com | admin/admin123 |
| **Superset** | 数据可视化 | http://superset.your-domain.com | admin/admin123 |

### 监控组件

| 组件 | 功能 | 访问地址 | 默认账号 |
|------|------|----------|----------|
| **Grafana** | 监控面板 | http://grafana.your-domain.com | admin/admin123 |
| **Prometheus** | 指标收集 | http://prometheus.your-domain.com | - |
| **Jaeger** | 链路追踪 | http://jaeger.your-domain.com | - |

## 🔧 常用操作

### 查看状态

```bash
# 查看所有组件状态
make status

# 查看特定组件状态
kubectl get pods -n bigdata
kubectl get pods -n storage
kubectl get pods -n ai-ml
kubectl get pods -n data-pipeline
kubectl get pods -n monitoring
```

### 查看日志

```bash
# 查看所有组件日志
make logs

# 查看特定组件日志
kubectl logs -f deployment/flink-jobmanager -n bigdata
kubectl logs -f deployment/doris-fe -n bigdata
kubectl logs -f deployment/minio -n storage
kubectl logs -f deployment/kafka -n bigdata
```

### 故障排查

```bash
# 执行完整故障排查
make troubleshoot

# 检查特定组件
./scripts/troubleshoot.sh --component flink
./scripts/troubleshoot.sh --component doris
./scripts/troubleshoot.sh --component minio
```

### 扩容组件

```bash
# 扩容Flink TaskManager
kubectl scale deployment flink-taskmanager --replicas=4 -n bigdata

# 扩容Doris BE
kubectl scale statefulset doris-be --replicas=5 -n bigdata

# 扩容Kafka
kubectl scale statefulset kafka --replicas=5 -n bigdata
```

## 📊 数据操作

### Flink流处理

```bash
# 提交Flink作业
kubectl apply -f examples/flink-streaming/word-count-job.yaml

# 查看作业状态
kubectl get flinkdeployments -n bigdata

# 查看作业日志
kubectl logs -f deployment/word-count-job -n bigdata
```

### Doris数据仓库

```bash
# 连接Doris
mysql -h doris-fe.bigdata.svc.cluster.local -P 9030 -u root -p

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

### MinIO对象存储

```bash
# 使用MinIO客户端
kubectl run --rm -i --restart=Never --image=minio/mc:latest mc --namespace storage -- \
    mc alias set myminio http://minio:9000 admin minio123

# 创建bucket
kubectl run --rm -i --restart=Never --image=minio/mc:latest mc --namespace storage -- \
    mc mb myminio/data-lake

# 上传文件
kubectl run --rm -i --restart=Never --image=minio/mc:latest mc --namespace storage -- \
    mc cp /path/to/file myminio/data-lake/
```

### Kafka消息队列

```bash
# 创建主题
kubectl run --rm -i --restart=Never --image=bitnami/kafka:latest kafka-client --namespace bigdata -- \
    kafka-topics.sh --create --bootstrap-server kafka:9092 --topic user-events --partitions 3 --replication-factor 3

# 发送消息
kubectl run --rm -i --restart=Never --image=bitnami/kafka:latest kafka-client --namespace bigdata -- \
    kafka-console-producer.sh --bootstrap-server kafka:9092 --topic user-events

# 消费消息
kubectl run --rm -i --restart=Never --image=bitnami/kafka:latest kafka-client --namespace bigdata -- \
    kafka-console-consumer.sh --bootstrap-server kafka:9092 --topic user-events --from-beginning
```

## 🤖 AI/ML操作

### KubeFlow机器学习

```bash
# 访问JupyterHub
# 浏览器访问: http://jupyter.your-domain.com

# 创建Notebook
# 在JupyterHub界面中创建新的Notebook

# 运行机器学习任务
# 在Notebook中编写和运行ML代码
```

### 模型训练示例

```python
# 在Jupyter Notebook中运行
import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score

# 加载数据
data = pd.read_csv('s3://data-lake/dataset.csv')

# 数据预处理
X = data.drop('target', axis=1)
y = data['target']

# 训练模型
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2)
model = RandomForestClassifier(n_estimators=100)
model.fit(X_train, y_train)

# 评估模型
y_pred = model.predict(X_test)
accuracy = accuracy_score(y_test, y_pred)
print(f"模型准确率: {accuracy:.4f}")
```

## 🔄 工作流调度

### Airflow DAG示例

```python
# 在Airflow中创建DAG
from airflow import DAG
from airflow.operators.python_operator import PythonOperator
from datetime import datetime, timedelta

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
    'data_pipeline',
    default_args=default_args,
    description='数据处理管道',
    schedule_interval=timedelta(hours=1),
)

def extract_data():
    # 从Kafka提取数据
    pass

def transform_data():
    # 使用Flink处理数据
    pass

def load_data():
    # 加载到Doris
    pass

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

extract_task >> transform_task >> load_task
```

## 📈 数据可视化

### Superset仪表板

```bash
# 访问Superset
# 浏览器访问: http://superset.your-domain.com

# 连接数据源
# 1. 点击 "Data" -> "Databases"
# 2. 点击 "Add Database"
# 3. 选择 "MySQL" 连接类型
# 4. 输入Doris连接信息:
#    Host: doris-fe.bigdata.svc.cluster.local
#    Port: 9030
#    Database: bigdata_platform
#    Username: root
#    Password: root

# 创建图表
# 1. 点击 "Charts" -> "Add Chart"
# 2. 选择数据源和表
# 3. 配置图表类型和字段
# 4. 保存图表

# 创建仪表板
# 1. 点击 "Dashboards" -> "Add Dashboard"
# 2. 添加已创建的图表
# 3. 调整布局和样式
# 4. 保存仪表板
```

## 🔍 监控告警

### Grafana监控

```bash
# 访问Grafana
# 浏览器访问: http://grafana.your-domain.com

# 添加数据源
# 1. 点击 "Configuration" -> "Data Sources"
# 2. 添加 Prometheus 数据源
# 3. URL: http://prometheus.monitoring.svc.cluster.local:9090

# 创建仪表板
# 1. 点击 "Create" -> "Dashboard"
# 2. 添加面板
# 3. 选择数据源和指标
# 4. 配置查询和可视化

# 设置告警
# 1. 在面板中点击 "Alert" 标签
# 2. 配置告警规则
# 3. 设置通知渠道
```

### 关键监控指标

```yaml
# Flink指标
flink_jobmanager_job_uptime_seconds
flink_taskmanager_job_task_uptime_seconds
flink_taskmanager_job_task_buffers_inPoolUsage
flink_taskmanager_job_task_buffers_outPoolUsage

# Doris指标
doris_fe_query_total
doris_fe_query_duration_seconds
doris_be_tablet_count
doris_be_data_size_bytes

# Kafka指标
kafka_server_brokertopicmetrics_messagesin_total
kafka_server_brokertopicmetrics_bytesin_total
kafka_server_brokertopicmetrics_bytesout_total

# MinIO指标
minio_bucket_usage_object_total
minio_bucket_usage_bytes_total
minio_s3_requests_total
```

## 🛠️ 运维操作

### 备份和恢复

```bash
# 备份平台数据
make backup

# 恢复平台数据
make restore

# 备份特定组件
kubectl get all -n bigdata -o yaml > bigdata-backup.yaml
kubectl get all -n storage -o yaml > storage-backup.yaml
```

### 升级组件

```bash
# 升级所有组件
make upgrade

# 升级特定组件
helm upgrade flink-operator apache/flink-kubernetes-operator -n bigdata
helm upgrade minio bitnami/minio -n storage
helm upgrade kafka bitnami/kafka -n bigdata
```

### 清理资源

```bash
# 清理平台
make clean

# 清理特定组件
kubectl delete namespace bigdata --ignore-not-found=true
kubectl delete namespace storage --ignore-not-found=true
kubectl delete namespace ai-ml --ignore-not-found=true
```

## 🆘 故障排查

### 常见问题

1. **Pod启动失败**
   ```bash
   # 查看Pod事件
   kubectl describe pod <pod-name> -n <namespace>
   
   # 查看Pod日志
   kubectl logs <pod-name> -n <namespace>
   
   # 检查资源配额
   kubectl describe resourcequota -n <namespace>
   ```

2. **服务无法访问**
   ```bash
   # 检查服务状态
   kubectl get services -n <namespace>
   
   # 检查端点
   kubectl get endpoints -n <namespace>
   
   # 测试网络连接
   kubectl run -it --rm --restart=Never --image=busybox:1.28 test -- nslookup <service-name>
   ```

3. **存储问题**
   ```bash
   # 检查PVC状态
   kubectl get pvc --all-namespaces
   
   # 检查PV状态
   kubectl get pv
   
   # 检查存储类
   kubectl get storageclass
   ```

### 性能优化

1. **资源调优**
   ```bash
   # 查看资源使用
   kubectl top nodes
   kubectl top pods --all-namespaces
   
   # 调整资源限制
   kubectl patch deployment <deployment-name> -n <namespace> -p '{"spec":{"template":{"spec":{"containers":[{"name":"<container-name>","resources":{"limits":{"memory":"4Gi","cpu":"2"},"requests":{"memory":"2Gi","cpu":"1"}}}]}}}}'
   ```

2. **网络优化**
   ```bash
   # 检查网络策略
   kubectl get networkpolicies --all-namespaces
   
   # 优化网络配置
   kubectl patch networkpolicy <policy-name> -n <namespace> -p '{"spec":{"egress":[{"to":[{"namespaceSelector":{"matchLabels":{"name":"storage"}}}],"ports":[{"protocol":"TCP","port":9000}]}]}}'
   ```

## 📚 更多资源

- [详细文档](./docs/)
- [配置说明](./config/)
- [使用示例](./examples/)
- [故障排查](./scripts/troubleshoot.sh)
- [API文档](https://kubernetes.io/docs/)
- [Helm文档](https://helm.sh/docs/)

## 🤝 获取帮助

- **文档**: [完整文档](./docs/)
- **Issues**: [GitHub Issues](https://github.com/your-repo/issues)
- **讨论**: [GitHub Discussions](https://github.com/your-repo/discussions)
- **邮件**: support@your-domain.com

---

**注意**: 这是一个生产级别的平台，建议在测试环境充分验证后再部署到生产环境。 