# K8s大数据AI平台 - 从0到1完整部署指南

## 📋 平台概述

这是一个基于Kubernetes的云原生大数据AI平台，集成了主流的大数据组件和AI工具，支持Flink、Paimon、Doris、MinIO等核心组件。

### 🎯 平台特性

- **云原生架构**：基于Kubernetes，支持弹性伸缩
- **组件丰富**：集成主流大数据和AI组件
- **一键部署**：Helm Chart + 脚本化部署
- **监控完善**：Prometheus + Grafana监控体系
- **安全可靠**：RBAC权限控制，数据加密传输

### 🏗️ 架构组件

```
┌─────────────────────────────────────────────────────────────┐
│                    K8s大数据AI平台架构                        │
├─────────────────────────────────────────────────────────────┤
│ 前端层: Superset + Grafana + JupyterHub                     │
├─────────────────────────────────────────────────────────────┤
│ 计算层: Flink + Spark + KubeFlow                           │
├─────────────────────────────────────────────────────────────┤
│ 存储层: MinIO + Doris + Paimon + Redis                     │
├─────────────────────────────────────────────────────────────┤
│ 消息层: Kafka + Pulsar                                     │
├─────────────────────────────────────────────────────────────┤
│ 调度层: Airflow + Argo Workflows                           │
├─────────────────────────────────────────────────────────────┤
│ 监控层: Prometheus + AlertManager + Jaeger                 │
├─────────────────────────────────────────────────────────────┤
│ 基础设施: Kubernetes + Istio + Cert-Manager                │
└─────────────────────────────────────────────────────────────┘
```

## 🚀 快速开始

### 前置要求

- **Kubernetes集群**：v1.20+ (推荐v1.24+)
- **Helm**：v3.8+ 
- **kubectl**：与K8s版本匹配
- **存储类**：支持动态供应
- **网络插件**：Calico/Flannel等
- **资源要求**：
  - CPU: 16核+
  - 内存: 32GB+
  - 存储: 100GB+

### 一键部署

```bash
# 1. 克隆项目
git clone <repository-url>
cd k8s-bigdata-ai-platform

# 2. 初始化环境
./scripts/init-environment.sh

# 3. 部署平台
./scripts/deploy-platform.sh

# 4. 验证部署
./scripts/verify-deployment.sh
```

## 📚 详细部署指南

### 第一阶段：环境准备
- [K8s集群搭建](./docs/01-k8s-setup.md)
- [存储配置](./docs/02-storage-setup.md)
- [网络配置](./docs/03-network-setup.md)

### 第二阶段：基础组件
- [Helm安装配置](./docs/04-helm-setup.md)
- [监控体系部署](./docs/05-monitoring-setup.md)
- [安全配置](./docs/06-security-setup.md)

### 第三阶段：大数据组件
- [MinIO对象存储](./docs/07-minio-deploy.md)
- [Kafka消息队列](./docs/08-kafka-deploy.md)
- [Flink流处理](./docs/09-flink-deploy.md)
- [Paimon数据湖](./docs/10-paimon-deploy.md)
- [Doris数据仓库](./docs/11-doris-deploy.md)

### 第四阶段：AI组件
- [KubeFlow机器学习](./docs/12-kubeflow-deploy.md)
- [JupyterHub开发环境](./docs/13-jupyter-deploy.md)
- [模型服务](./docs/14-model-serving.md)

### 第五阶段：应用层
- [Airflow工作流](./docs/15-airflow-deploy.md)
- [Superset可视化](./docs/16-superset-deploy.md)
- [数据管道](./docs/17-data-pipeline.md)

## 🔧 配置说明

### 环境变量配置
```bash
# 复制配置模板
cp config/env.template config/env.sh

# 编辑配置
vim config/env.sh
```

### 组件配置
- [Flink配置](./config/flink/)
- [Doris配置](./config/doris/)
- [MinIO配置](./config/minio/)
- [Kafka配置](./config/kafka/)

## 📊 监控和运维

### 监控面板
- **Grafana**: http://grafana.your-domain.com
- **Prometheus**: http://prometheus.your-domain.com
- **Jaeger**: http://jaeger.your-domain.com

### 应用面板
- **Superset**: http://superset.your-domain.com
- **JupyterHub**: http://jupyter.your-domain.com
- **Airflow**: http://airflow.your-domain.com

### 运维命令
```bash
# 查看所有Pod状态
./scripts/check-status.sh

# 查看组件日志
./scripts/view-logs.sh <component-name>

# 扩容组件
./scripts/scale-component.sh <component-name> <replicas>

# 备份数据
./scripts/backup-data.sh
```

## 🛠️ 故障排查

### 常见问题
- [Pod启动失败](./docs/troubleshooting/pod-startup.md)
- [存储问题](./docs/troubleshooting/storage-issues.md)
- [网络连接问题](./docs/troubleshooting/network-issues.md)
- [性能优化](./docs/troubleshooting/performance-tuning.md)

### 日志分析
```bash
# 查看组件日志
kubectl logs -f deployment/<component-name> -n <namespace>

# 查看事件
kubectl get events -n <namespace> --sort-by='.lastTimestamp'

# 查看资源使用
kubectl top pods -n <namespace>
```

## 📈 性能调优

### 资源配置建议
- [CPU和内存配置](./docs/performance/cpu-memory-tuning.md)
- [存储性能优化](./docs/performance/storage-tuning.md)
- [网络性能优化](./docs/performance/network-tuning.md)

### 监控指标
- [关键指标说明](./docs/monitoring/key-metrics.md)
- [告警规则配置](./docs/monitoring/alert-rules.md)
- [性能基准测试](./docs/performance/benchmark.md)

## 🔒 安全配置

### 访问控制
- [RBAC权限配置](./docs/security/rbac-setup.md)
- [网络策略](./docs/security/network-policies.md)
- [密钥管理](./docs/security/secret-management.md)

### 数据安全
- [数据加密](./docs/security/data-encryption.md)
- [备份策略](./docs/security/backup-strategy.md)
- [审计日志](./docs/security/audit-logs.md)

## 📝 使用示例

### 数据处理示例
- [Flink流处理示例](./examples/flink-streaming/)
- [Spark批处理示例](./examples/spark-batch/)
- [数据湖操作示例](./examples/data-lake/)

### AI/ML示例
- [KubeFlow Pipeline示例](./examples/kubeflow-pipeline/)
- [模型训练示例](./examples/model-training/)
- [模型部署示例](./examples/model-serving/)

## 🤝 贡献指南

欢迎贡献代码和文档！请查看[贡献指南](./CONTRIBUTING.md)。

## 📄 许可证

本项目采用 [Apache License 2.0](./LICENSE) 许可证。

## 🆘 获取帮助

- **文档**: [完整文档](./docs/)
- **Issues**: [GitHub Issues](https://github.com/your-repo/issues)
- **讨论**: [GitHub Discussions](https://github.com/your-repo/discussions)
- **邮件**: support@your-domain.com

---

**注意**: 这是一个生产级别的部署方案，建议在测试环境充分验证后再部署到生产环境。
