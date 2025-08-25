#!/bin/bash

# K8s大数据AI平台 - 主部署脚本
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

# 加载环境变量
load_env() {
    if [ -f "../config/env.sh" ]; then
        source ../config/env.sh
    else
        log_warning "未找到环境配置文件，使用默认配置"
        export CLUSTER_NAME="bigdata-platform"
        export STORAGE_CLASS="default"
        export STORAGE_SIZE="100Gi"
    fi
}

# 等待Pod就绪
wait_for_pod() {
    local namespace=$1
    local label=$2
    local timeout=${3:-300}
    
    log_info "等待 $namespace/$label Pod就绪..."
    
    kubectl wait --for=condition=ready pod -l $label -n $namespace --timeout=${timeout}s
    
    if [ $? -eq 0 ]; then
        log_success "$namespace/$label Pod已就绪"
    else
        log_error "$namespace/$label Pod启动超时"
        exit 1
    fi
}

# 部署监控体系
deploy_monitoring() {
    log_info "开始部署监控体系..."
    
    # 部署Prometheus
    log_info "部署Prometheus..."
    helm install prometheus prometheus-community/kube-prometheus-stack \
        --namespace monitoring \
        --create-namespace \
        --set prometheus.prometheusSpec.retention=${PROMETHEUS_RETENTION:-15d} \
        --set grafana.adminPassword=${GRAFANA_ADMIN_PASSWORD:-admin123} \
        --set grafana.persistence.enabled=true \
        --set grafana.persistence.size=10Gi \
        --wait --timeout=10m
    
    # 部署Jaeger
    log_info "部署Jaeger..."
    helm install jaeger jaegertracing/jaeger \
        --namespace monitoring \
        --set storage.type=elasticsearch \
        --set storage.options.es.server-urls=http://elasticsearch-master:9200 \
        --wait --timeout=5m
    
    # 部署Elasticsearch
    log_info "部署Elasticsearch..."
    helm install elasticsearch elastic/elasticsearch \
        --namespace monitoring \
        --set replicas=3 \
        --set minimumMasterNodes=2 \
        --set resources.requests.memory=2Gi \
        --set resources.limits.memory=4Gi \
        --wait --timeout=10m
    
    log_success "监控体系部署完成"
}

# 部署存储组件
deploy_storage() {
    log_info "开始部署存储组件..."
    
    # 部署MinIO
    log_info "部署MinIO对象存储..."
    helm install minio bitnami/minio \
        --namespace storage \
        --create-namespace \
        --set auth.rootUser=admin \
        --set auth.rootPassword=minio123 \
        --set persistence.enabled=true \
        --set persistence.size=${STORAGE_SIZE} \
        --set persistence.storageClass=${STORAGE_CLASS} \
        --set service.type=ClusterIP \
        --wait --timeout=10m
    
    # 创建MinIO bucket
    log_info "创建MinIO bucket..."
    kubectl run --rm -i --restart=Never --image=minio/mc:latest mc --namespace storage -- \
        mc alias set myminio http://minio:9000 admin minio123
    
    kubectl run --rm -i --restart=Never --image=minio/mc:latest mc --namespace storage -- \
        mc mb myminio/bigdata-lake
    
    kubectl run --rm -i --restart=Never --image=minio/mc:latest mc --namespace storage -- \
        mc mb myminio/ml-models
    
    # 部署Redis
    log_info "部署Redis缓存..."
    helm install redis bitnami/redis \
        --namespace storage \
        --set auth.enabled=true \
        --set auth.password=redis123 \
        --set master.persistence.enabled=true \
        --set master.persistence.size=10Gi \
        --set replica.persistence.enabled=true \
        --set replica.persistence.size=10Gi \
        --set replica.replicaCount=2 \
        --wait --timeout=10m
    
    log_success "存储组件部署完成"
}

# 部署消息队列
deploy_messaging() {
    log_info "开始部署消息队列..."
    
    # 部署Kafka
    log_info "部署Kafka..."
    helm install kafka bitnami/kafka \
        --namespace bigdata \
        --create-namespace \
        --set replicaCount=3 \
        --set persistence.enabled=true \
        --set persistence.size=20Gi \
        --set persistence.storageClass=${STORAGE_CLASS} \
        --set zookeeper.persistence.enabled=true \
        --set zookeeper.persistence.size=10Gi \
        --set zookeeper.persistence.storageClass=${STORAGE_CLASS} \
        --set deleteTopicEnable=true \
        --set autoCreateTopicsEnable=true \
        --wait --timeout=15m
    
    # 创建Kafka主题
    log_info "创建Kafka主题..."
    kubectl run --rm -i --restart=Never --image=bitnami/kafka:latest kafka-client --namespace bigdata -- \
        kafka-topics.sh --create --bootstrap-server kafka:9092 --topic data-stream --partitions 3 --replication-factor 3
    
    kubectl run --rm -i --restart=Never --image=bitnami/kafka:latest kafka-client --namespace bigdata -- \
        kafka-topics.sh --create --bootstrap-server kafka:9092 --topic ml-events --partitions 3 --replication-factor 3
    
    log_success "消息队列部署完成"
}

# 部署Flink
deploy_flink() {
    log_info "开始部署Flink..."
    
    # 部署Flink Operator
    helm install flink-operator apache/flink-kubernetes-operator \
        --namespace bigdata \
        --set operator.replicaCount=1 \
        --wait --timeout=5m
    
    # 部署Flink Session Cluster
    cat <<EOF | kubectl apply -f -
apiVersion: flink.apache.org/v1beta1
kind: FlinkDeployment
metadata:
  name: flink-session-cluster
  namespace: bigdata
spec:
  image: flink:${FLINK_VERSION:-1.17.1}
  flinkVersion: v1_17
  flinkConfiguration:
    taskmanager.numberOfTaskSlots: "4"
    state.backend: filesystem
    state.checkpoints.dir: s3://bigdata-lake/checkpoints
    state.savepoints.dir: s3://bigdata-lake/savepoints
    s3.endpoint: http://minio.storage.svc.cluster.local:9000
    s3.access-key: admin
    s3.secret-key: minio123
    s3.path.style: "true"
  jobManager:
    resource:
      memory: "2048m"
      cpu: 1
    replicas: 1
  taskManager:
    resource:
      memory: "4096m"
      cpu: 2
    replicas: 2
  podTemplate:
    spec:
      containers:
      - name: flink-main-container
        env:
        - name: TZ
          value: "Asia/Shanghai"
EOF
    
    wait_for_pod "bigdata" "app=flink-session-cluster" 300
    
    log_success "Flink部署完成"
}

# 部署Doris
deploy_doris() {
    log_info "开始部署Doris..."
    
    # 部署Doris FE
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: doris-fe
  namespace: bigdata
spec:
  serviceName: doris-fe
  replicas: 3
  selector:
    matchLabels:
      app: doris-fe
  template:
    metadata:
      labels:
        app: doris-fe
    spec:
      containers:
      - name: doris-fe
        image: apache/doris:${DORIS_VERSION:-2.0.2}-fe-x86_64
        ports:
        - containerPort: 9030
        - containerPort: 8030
        - containerPort: 9020
        env:
        - name: FE_SERVERS
          value: "doris-fe-0.doris-fe:9020,doris-fe-1.doris-fe:9020,doris-fe-2.doris-fe:9020"
        - name: PRIORITY_NETWORKS
          value: "10.244.0.0/16"
        volumeMounts:
        - name: doris-fe-data
          mountPath: /opt/apache-doris/fe/doris-meta
  volumeClaimTemplates:
  - metadata:
      name: doris-fe-data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: ${STORAGE_CLASS}
      resources:
        requests:
          storage: 20Gi
---
apiVersion: v1
kind: Service
metadata:
  name: doris-fe
  namespace: bigdata
spec:
  selector:
    app: doris-fe
  ports:
  - name: mysql
    port: 9030
    targetPort: 9030
  - name: http
    port: 8030
    targetPort: 8030
  - name: edit-log
    port: 9020
    targetPort: 9020
EOF
    
    # 部署Doris BE
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: doris-be
  namespace: bigdata
spec:
  serviceName: doris-be
  replicas: 3
  selector:
    matchLabels:
      app: doris-be
  template:
    metadata:
      labels:
        app: doris-be
    spec:
      containers:
      - name: doris-be
        image: apache/doris:${DORIS_VERSION:-2.0.2}-be-x86_64
        ports:
        - containerPort: 9060
        - containerPort: 8040
        - containerPort: 8060
        env:
        - name: FE_SERVERS
          value: "doris-fe-0.doris-fe:9020,doris-fe-1.doris-fe:9020,doris-fe-2.doris-fe:9020"
        - name: PRIORITY_NETWORKS
          value: "10.244.0.0/16"
        volumeMounts:
        - name: doris-be-data
          mountPath: /opt/apache-doris/be/storage
  volumeClaimTemplates:
  - metadata:
      name: doris-be-data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: ${STORAGE_CLASS}
      resources:
        requests:
          storage: 50Gi
---
apiVersion: v1
kind: Service
metadata:
  name: doris-be
  namespace: bigdata
spec:
  selector:
    app: doris-be
  ports:
  - name: be
    port: 9060
    targetPort: 9060
  - name: http
    port: 8040
    targetPort: 8040
  - name: brpc
    port: 8060
    targetPort: 8060
EOF
    
    wait_for_pod "bigdata" "app=doris-fe" 600
    wait_for_pod "bigdata" "app=doris-be" 600
    
    log_success "Doris部署完成"
}

# 部署KubeFlow
deploy_kubeflow() {
    log_info "开始部署KubeFlow..."
    
    # 安装KubeFlow
    helm install kubeflow kubeflow/kubeflow \
        --namespace ai-ml \
        --create-namespace \
        --set jupyterhub.enabled=true \
        --set jupyterhub.singleuser.image.name=jupyter/tensorflow-notebook \
        --set jupyterhub.singleuser.image.tag=latest \
        --set jupyterhub.singleuser.storage.dynamic.storageClass=${STORAGE_CLASS} \
        --set jupyterhub.singleuser.storage.dynamic.requests.storage=10Gi \
        --set katib.enabled=true \
        --set pipelines.enabled=true \
        --set profiles.enabled=true \
        --set centraldashboard.enabled=true \
        --set notebook-controller.enabled=true \
        --wait --timeout=20m
    
    log_success "KubeFlow部署完成"
}

# 部署Airflow
deploy_airflow() {
    log_info "开始部署Airflow..."
    
    # 部署Airflow
    helm install airflow apache-airflow/airflow \
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
        --set postgresql.persistence.storageClass=${STORAGE_CLASS} \
        --set persistence.enabled=true \
        --set persistence.size=10Gi \
        --set persistence.storageClass=${STORAGE_CLASS} \
        --set dags.persistence.enabled=true \
        --set dags.persistence.size=5Gi \
        --set dags.persistence.storageClass=${STORAGE_CLASS} \
        --wait --timeout=15m
    
    log_success "Airflow部署完成"
}

# 部署Superset
deploy_superset() {
    log_info "开始部署Superset..."
    
    # 部署Superset
    helm install superset apache/superset \
        --namespace bigdata \
        --set webserver.persistence.enabled=true \
        --set webserver.persistence.size=10Gi \
        --set webserver.persistence.storageClass=${STORAGE_CLASS} \
        --set init.adminUser=admin \
        --set init.adminPassword=admin123 \
        --set init.adminEmail=admin@example.com \
        --set init.adminFirstName=Admin \
        --set init.adminLastName=User \
        --set postgresql.enabled=true \
        --set postgresql.persistence.enabled=true \
        --set postgresql.persistence.size=10Gi \
        --set postgresql.persistence.storageClass=${STORAGE_CLASS} \
        --set redis.enabled=true \
        --wait --timeout=10m
    
    log_success "Superset部署完成"
}

# 配置Ingress
setup_ingress() {
    log_info "配置Ingress..."
    
    # 安装NGINX Ingress Controller
    helm install ingress-nginx ingress-nginx/ingress-nginx \
        --namespace ingress-nginx \
        --create-namespace \
        --set controller.replicaCount=2 \
        --set controller.resources.requests.cpu=100m \
        --set controller.resources.requests.memory=128Mi \
        --set controller.resources.limits.cpu=200m \
        --set controller.resources.limits.memory=256Mi \
        --wait --timeout=10m
    
    # 创建Ingress规则
    cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: bigdata-platform-ingress
  namespace: bigdata
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
spec:
  rules:
  - host: grafana.${CLUSTER_DOMAIN:-localhost}
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: prometheus-grafana
            port:
              number: 80
  - host: superset.${CLUSTER_DOMAIN:-localhost}
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: superset
            port:
              number: 8088
  - host: airflow.${CLUSTER_DOMAIN:-localhost}
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: airflow-webserver
            port:
              number: 8080
EOF
    
    log_success "Ingress配置完成"
}

# 验证部署
verify_deployment() {
    log_info "验证部署状态..."
    
    # 检查所有Pod状态
    kubectl get pods --all-namespaces
    
    # 检查服务状态
    kubectl get services --all-namespaces
    
    # 检查Ingress状态
    kubectl get ingress --all-namespaces
    
    log_success "部署验证完成"
}

# 显示访问信息
show_access_info() {
    log_info "=== 平台访问信息 ==="
    
    # 获取Ingress IP
    INGRESS_IP=$(kubectl get service ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    if [ -z "$INGRESS_IP" ]; then
        INGRESS_IP=$(kubectl get service ingress-nginx-controller -n ingress-nginx -o jsonpath='{.spec.clusterIP}')
    fi
    
    echo "Ingress IP: $INGRESS_IP"
    echo ""
    echo "访问地址:"
    echo "- Grafana: http://grafana.${CLUSTER_DOMAIN:-$INGRESS_IP.nip.io}"
    echo "- Superset: http://superset.${CLUSTER_DOMAIN:-$INGRESS_IP.nip.io}"
    echo "- Airflow: http://airflow.${CLUSTER_DOMAIN:-$INGRESS_IP.nip.io}"
    echo "- JupyterHub: http://jupyter.${CLUSTER_DOMAIN:-$INGRESS_IP.nip.io}"
    echo ""
    echo "默认账号:"
    echo "- Grafana: admin/admin123"
    echo "- Superset: admin/admin123"
    echo "- Airflow: admin/admin123"
    echo "- JupyterHub: 首次访问创建账号"
    echo ""
    echo "组件端口:"
    echo "- Doris FE: $INGRESS_IP:8030"
    echo "- Doris BE: $INGRESS_IP:8040"
    echo "- Flink JobManager: $INGRESS_IP:8081"
    echo "- Kafka: $INGRESS_IP:9092"
    echo "- MinIO: $INGRESS_IP:9000"
}

# 主函数
main() {
    log_info "开始部署K8s大数据AI平台..."
    
    # 加载环境变量
    load_env
    
    # 按顺序部署组件
    deploy_monitoring
    deploy_storage
    deploy_messaging
    deploy_flink
    deploy_doris
    deploy_kubeflow
    deploy_airflow
    deploy_superset
    setup_ingress
    
    # 验证部署
    verify_deployment
    
    # 显示访问信息
    show_access_info
    
    log_success "K8s大数据AI平台部署完成！"
    log_info "请查看上面的访问信息，开始使用平台"
}

# 执行主函数
main "$@" 