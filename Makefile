# K8s大数据AI平台 - Makefile
# 作者: 云原生专家
# 版本: 1.0.0

.PHONY: help init deploy verify clean logs status troubleshoot

# 默认目标
help:
	@echo "K8s大数据AI平台 - 可用命令"
	@echo ""
	@echo "基础操作:"
	@echo "  make init          - 初始化环境"
	@echo "  make deploy        - 部署平台"
	@echo "  make verify        - 验证部署"
	@echo "  make status        - 查看状态"
	@echo "  make logs          - 查看日志"
	@echo "  make troubleshoot  - 故障排查"
	@echo "  make clean         - 清理平台"
	@echo ""
	@echo "组件操作:"
	@echo "  make deploy-flink     - 部署Flink"
	@echo "  make deploy-doris     - 部署Doris"
	@echo "  make deploy-minio     - 部署MinIO"
	@echo "  make deploy-kafka     - 部署Kafka"
	@echo "  make deploy-kubeflow  - 部署KubeFlow"
	@echo "  make deploy-airflow   - 部署Airflow"
	@echo "  make deploy-superset  - 部署Superset"
	@echo ""
	@echo "监控操作:"
	@echo "  make deploy-monitoring - 部署监控"
	@echo "  make check-metrics     - 检查指标"
	@echo ""
	@echo "示例操作:"
	@echo "  make deploy-examples   - 部署示例"
	@echo "  make run-wordcount     - 运行WordCount示例"
	@echo ""

# 初始化环境
init:
	@echo "初始化K8s大数据AI平台环境..."
	@chmod +x scripts/init-environment.sh
	@./scripts/init-environment.sh

# 部署平台
deploy:
	@echo "部署K8s大数据AI平台..."
	@chmod +x scripts/deploy-platform.sh
	@./scripts/deploy-platform.sh

# 验证部署
verify:
	@echo "验证平台部署状态..."
	@kubectl get pods --all-namespaces
	@kubectl get services --all-namespaces
	@kubectl get ingress --all-namespaces

# 查看状态
status:
	@echo "=== 节点状态 ==="
	@kubectl get nodes -o wide
	@echo ""
	@echo "=== Pod状态 ==="
	@kubectl get pods --all-namespaces
	@echo ""
	@echo "=== 服务状态 ==="
	@kubectl get services --all-namespaces
	@echo ""
	@echo "=== 存储状态 ==="
	@kubectl get pv,pvc --all-namespaces

# 查看日志
logs:
	@echo "查看关键组件日志..."
	@echo "=== Flink日志 ==="
	@kubectl logs -n bigdata -l app=flink-jobmanager --tail=20 2>/dev/null || echo "Flink未运行"
	@echo ""
	@echo "=== Doris日志 ==="
	@kubectl logs -n bigdata -l app=doris-fe --tail=20 2>/dev/null || echo "Doris未运行"
	@echo ""
	@echo "=== MinIO日志 ==="
	@kubectl logs -n storage -l app.kubernetes.io/name=minio --tail=20 2>/dev/null || echo "MinIO未运行"
	@echo ""
	@echo "=== Kafka日志 ==="
	@kubectl logs -n bigdata -l app.kubernetes.io/name=kafka --tail=20 2>/dev/null || echo "Kafka未运行"

# 故障排查
troubleshoot:
	@echo "执行故障排查..."
	@chmod +x scripts/troubleshoot.sh
	@./scripts/troubleshoot.sh --all

# 清理平台
clean:
	@echo "清理K8s大数据AI平台..."
	@echo "警告: 这将删除所有平台组件和数据！"
	@read -p "确认删除? (y/N): " confirm && [ "$$confirm" = "y" ] || exit 1
	@kubectl delete namespace monitoring --ignore-not-found=true
	@kubectl delete namespace bigdata --ignore-not-found=true
	@kubectl delete namespace ai-ml --ignore-not-found=true
	@kubectl delete namespace data-pipeline --ignore-not-found=true
	@kubectl delete namespace storage --ignore-not-found=true
	@kubectl delete namespace logging --ignore-not-found=true
	@kubectl delete namespace security --ignore-not-found=true
	@echo "平台清理完成"

# 部署监控
deploy-monitoring:
	@echo "部署监控体系..."
	@helm install prometheus prometheus-community/kube-prometheus-stack \
		--namespace monitoring \
		--create-namespace \
		--set prometheus.prometheusSpec.retention=15d \
		--set grafana.adminPassword=admin123 \
		--set grafana.persistence.enabled=true \
		--set grafana.persistence.size=10Gi \
		--wait --timeout=10m
	@helm install jaeger jaegertracing/jaeger \
		--namespace monitoring \
		--set storage.type=elasticsearch \
		--set storage.options.es.server-urls=http://elasticsearch-master:9200 \
		--wait --timeout=5m
	@helm install elasticsearch elastic/elasticsearch \
		--namespace monitoring \
		--set replicas=3 \
		--set minimumMasterNodes=2 \
		--set resources.requests.memory=2Gi \
		--set resources.limits.memory=4Gi \
		--wait --timeout=10m

# 部署Flink
deploy-flink:
	@echo "部署Flink..."
	@helm install flink-operator apache/flink-kubernetes-operator \
		--namespace bigdata \
		--set operator.replicaCount=1 \
		--wait --timeout=5m
	@kubectl apply -f config/flink/flink-config.yaml

# 部署Doris
deploy-doris:
	@echo "部署Doris..."
	@kubectl apply -f config/doris/doris-fe.yaml
	@kubectl apply -f config/doris/doris-be.yaml
	@echo "等待Doris启动..."
	@kubectl wait --for=condition=ready pod -l app=doris-fe -n bigdata --timeout=600s
	@kubectl wait --for=condition=ready pod -l app=doris-be -n bigdata --timeout=600s

# 部署MinIO
deploy-minio:
	@echo "部署MinIO..."
	@helm install minio bitnami/minio \
		--namespace storage \
		--create-namespace \
		--set auth.rootUser=admin \
		--set auth.rootPassword=minio123 \
		--set persistence.enabled=true \
		--set persistence.size=100Gi \
		--set persistence.storageClass=default \
		--set service.type=ClusterIP \
		--wait --timeout=10m

# 部署Kafka
deploy-kafka:
	@echo "部署Kafka..."
	@helm install kafka bitnami/kafka \
		--namespace bigdata \
		--create-namespace \
		--set replicaCount=3 \
		--set persistence.enabled=true \
		--set persistence.size=20Gi \
		--set persistence.storageClass=default \
		--set zookeeper.persistence.enabled=true \
		--set zookeeper.persistence.size=10Gi \
		--set zookeeper.persistence.storageClass=default \
		--set deleteTopicEnable=true \
		--set autoCreateTopicsEnable=true \
		--wait --timeout=15m

# 部署KubeFlow
deploy-kubeflow:
	@echo "部署KubeFlow..."
	@helm install kubeflow kubeflow/kubeflow \
		--namespace ai-ml \
		--create-namespace \
		--set jupyterhub.enabled=true \
		--set jupyterhub.singleuser.image.name=jupyter/tensorflow-notebook \
		--set jupyterhub.singleuser.image.tag=latest \
		--set jupyterhub.singleuser.storage.dynamic.storageClass=default \
		--set jupyterhub.singleuser.storage.dynamic.requests.storage=10Gi \
		--set katib.enabled=true \
		--set pipelines.enabled=true \
		--set profiles.enabled=true \
		--set centraldashboard.enabled=true \
		--set notebook-controller.enabled=true \
		--wait --timeout=20m

# 部署Airflow
deploy-airflow:
	@echo "部署Airflow..."
	@helm install airflow apache-airflow/airflow \
		--namespace data-pipeline \
		--create-namespace \
		--set webserver.defaultUser.enabled=true \
		--set webserver.defaultUser.username=admin \
		--set webserver.defaultUser.password=admin123 \
		--set webserver.defaultUser.email=admin@example.com \
		--set webserver.defaultUser.firstName=Admin \
		--set webserver.defaultUser.lastName=User \
		--set webserver.defaultUser.role=Admin \
		--set executor=CeleryExecutor \
		--set redis.enabled=true \
		--set postgresql.enabled=true \
		--set postgresql.persistence.enabled=true \
		--set postgresql.persistence.size=10Gi \
		--set postgresql.persistence.storageClass=default \
		--set persistence.enabled=true \
		--set persistence.size=10Gi \
		--set persistence.storageClass=default \
		--set dags.persistence.enabled=true \
		--set dags.persistence.size=5Gi \
		--set dags.persistence.storageClass=default \
		--wait --timeout=15m

# 部署Superset
deploy-superset:
	@echo "部署Superset..."
	@helm install superset apache/superset \
		--namespace bigdata \
		--set webserver.persistence.enabled=true \
		--set webserver.persistence.size=10Gi \
		--set webserver.persistence.storageClass=default \
		--set init.adminUser=admin \
		--set init.adminPassword=admin123 \
		--set init.adminEmail=admin@example.com \
		--set init.adminFirstName=Admin \
		--set init.adminLastName=User \
		--set postgresql.enabled=true \
		--set postgresql.persistence.enabled=true \
		--set postgresql.persistence.size=10Gi \
		--set postgresql.persistence.storageClass=default \
		--set redis.enabled=true \
		--wait --timeout=10m

# 检查指标
check-metrics:
	@echo "检查监控指标..."
	@kubectl top nodes 2>/dev/null || echo "Metrics Server未安装"
	@kubectl top pods --all-namespaces 2>/dev/null || echo "Metrics Server未安装"

# 部署示例
deploy-examples:
	@echo "部署示例应用..."
	@kubectl apply -f examples/flink-streaming/word-count-job.yaml
	@kubectl apply -f examples/spark-batch/sample-job.yaml
	@kubectl apply -f examples/data-lake/sample-pipeline.yaml

# 运行WordCount示例
run-wordcount:
	@echo "运行Flink WordCount示例..."
	@kubectl apply -f examples/flink-streaming/word-count-job.yaml
	@echo "等待作业启动..."
	@kubectl wait --for=condition=ready pod -l app=word-count-job -n bigdata --timeout=300s
	@echo "WordCount作业已启动，查看日志:"
	@kubectl logs -f -l app=word-count-job -n bigdata

# 快速开始
quick-start:
	@echo "快速开始部署..."
	@chmod +x quick-start.sh
	@./quick-start.sh

# 备份数据
backup:
	@echo "备份平台数据..."
	@mkdir -p backups/$(shell date +%Y%m%d-%H%M%S)
	@kubectl get all --all-namespaces -o yaml > backups/$(shell date +%Y%m%d-%H%M%S)/all-resources.yaml
	@kubectl get configmaps --all-namespaces -o yaml > backups/$(shell date +%Y%m%d-%H%M%S)/configmaps.yaml
	@kubectl get secrets --all-namespaces -o yaml > backups/$(shell date +%Y%m%d-%H%M%S)/secrets.yaml
	@echo "备份完成: backups/$(shell date +%Y%m%d-%H%M%S)/"

# 恢复数据
restore:
	@echo "恢复平台数据..."
	@read -p "输入备份目录: " backup_dir && \
	kubectl apply -f $$backup_dir/all-resources.yaml && \
	kubectl apply -f $$backup_dir/configmaps.yaml && \
	kubectl apply -f $$backup_dir/secrets.yaml
	@echo "恢复完成"

# 升级平台
upgrade:
	@echo "升级平台组件..."
	@helm repo update
	@helm upgrade prometheus prometheus-community/kube-prometheus-stack -n monitoring
	@helm upgrade minio bitnami/minio -n storage
	@helm upgrade kafka bitnami/kafka -n bigdata
	@helm upgrade airflow apache-airflow/airflow -n data-pipeline
	@helm upgrade superset apache/superset -n bigdata
	@echo "升级完成"

# 扩容组件
scale:
	@echo "扩容组件..."
	@read -p "输入组件名称: " component && \
	read -p "输入副本数: " replicas && \
	kubectl scale deployment $$component --replicas=$$replicas -n bigdata
	@echo "扩容完成"

# 查看访问信息
access-info:
	@echo "=== 平台访问信息 ==="
	@INGRESS_IP=$$(kubectl get service ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "localhost") && \
	echo "Ingress IP: $$INGRESS_IP" && \
	echo "" && \
	echo "访问地址:" && \
	echo "  Grafana:     http://grafana.$$INGRESS_IP.nip.io" && \
	echo "  Superset:    http://superset.$$INGRESS_IP.nip.io" && \
	echo "  Airflow:     http://airflow.$$INGRESS_IP.nip.io" && \
	echo "  JupyterHub:  http://jupyter.$$INGRESS_IP.nip.io" && \
	echo "" && \
	echo "默认账号:" && \
	echo "  Grafana:     admin/admin123" && \
	echo "  Superset:    admin/admin123" && \
	echo "  Airflow:     admin/admin123" && \
	echo "  JupyterHub:  首次访问创建账号" 