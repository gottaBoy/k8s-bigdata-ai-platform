# Kubernetes集群搭建指南

## 概述

本指南将帮助您从零开始搭建一个生产级别的Kubernetes集群，用于部署大数据AI平台。

## 方案选择

### 1. 本地开发环境
- **Minikube**: 单节点集群，适合开发测试
- **Docker Desktop**: 内置K8s，简单易用
- **Kind**: 多节点集群，适合CI/CD

### 2. 生产环境
- **Kubeadm**: 官方推荐，灵活可控
- **K3s**: 轻量级，资源占用少
- **OpenShift**: 企业级，功能丰富
- **云服务**: EKS、AKS、GKE等

## 方案一：使用Kubeadm搭建生产集群

### 前置要求

#### 硬件要求
- **Master节点**: 2核CPU, 4GB内存, 20GB存储
- **Worker节点**: 4核CPU, 8GB内存, 50GB存储
- **网络**: 千兆网络，低延迟

#### 软件要求
- **操作系统**: Ubuntu 20.04+ / CentOS 8+ / RHEL 8+
- **容器运行时**: containerd 1.6+
- **网络插件**: Calico / Flannel / Weave Net

### 步骤1：准备节点

#### 1.1 系统配置

```bash
# 关闭防火墙
systemctl stop firewalld
systemctl disable firewalld

# 关闭SELinux
setenforce 0
sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

# 关闭swap
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# 配置内核参数
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system
```

#### 1.2 安装容器运行时

```bash
# 安装containerd
cat <<EOF | sudo tee /etc/yum.repos.d/docker-ce.repo
[docker-ce-stable]
name=Docker CE Stable - \$basearch
baseurl=https://download.docker.com/linux/centos/\$releasever/\$basearch/stable
enabled=1
gpgcheck=1
gpgkey=https://download.docker.com/linux/centos/gpg
EOF

sudo yum install -y containerd.io

# 配置containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml

# 修改配置
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

# 启动containerd
sudo systemctl enable containerd
sudo systemctl start containerd
```

#### 1.3 安装Kubernetes组件

```bash
# 添加Kubernetes仓库
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-\$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
exclude=kubelet kubeadm kubectl
EOF

# 安装Kubernetes组件
sudo yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes

# 启动kubelet
sudo systemctl enable kubelet
sudo systemctl start kubelet
```

### 步骤2：初始化Master节点

```bash
# 初始化集群
sudo kubeadm init \
  --pod-network-cidr=10.244.0.0/16 \
  --service-cidr=10.96.0.0/12 \
  --apiserver-advertise-address=<MASTER_IP> \
  --kubernetes-version=v1.27.0

# 配置kubectl
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# 安装网络插件 (Calico)
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/calico.yaml
```

### 步骤3：添加Worker节点

在Master节点上获取join命令：

```bash
kubeadm token create --print-join-command
```

在Worker节点上执行join命令：

```bash
sudo kubeadm join <MASTER_IP>:6443 --token <TOKEN> --discovery-token-ca-cert-hash sha256:<HASH>
```

### 步骤4：验证集群

```bash
# 检查节点状态
kubectl get nodes

# 检查Pod状态
kubectl get pods --all-namespaces

# 检查集群信息
kubectl cluster-info
```

## 方案二：使用Kind搭建开发环境

### 安装Kind

```bash
# 下载Kind
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# 创建集群
kind create cluster --name bigdata-platform --config - <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
- role: worker
- role: worker
- role: worker
EOF
```

### 安装Ingress Controller

```bash
# 安装NGINX Ingress Controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# 等待Ingress Controller就绪
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s
```

## 方案三：使用云服务

### AWS EKS

```bash
# 安装eksctl
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin

# 创建集群
eksctl create cluster \
  --name bigdata-platform \
  --region us-west-2 \
  --nodegroup-name workers \
  --node-type t3.medium \
  --nodes 3 \
  --nodes-min 1 \
  --nodes-max 5 \
  --managed
```

### Azure AKS

```bash
# 安装Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# 登录Azure
az login

# 创建资源组
az group create --name bigdata-platform-rg --location eastus

# 创建AKS集群
az aks create \
  --resource-group bigdata-platform-rg \
  --name bigdata-platform \
  --node-count 3 \
  --node-vm-size Standard_D2s_v3 \
  --enable-addons monitoring \
  --generate-ssh-keys

# 获取凭据
az aks get-credentials --resource-group bigdata-platform-rg --name bigdata-platform
```

## 存储配置

### 安装存储类

```bash
# 安装NFS Provisioner
helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/
helm install nfs-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
  --set nfs.server=<NFS_SERVER_IP> \
  --set nfs.path=/shared \
  --set storageClass.name=nfs-client

# 设置为默认存储类
kubectl patch storageclass nfs-client -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

### 配置本地存储

```bash
# 创建本地存储类
cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-storage
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
EOF
```

## 网络配置

### 配置DNS

```bash
# 安装CoreDNS
kubectl apply -f https://raw.githubusercontent.com/coredns/coredns/master/kubernetes/coredns.yaml

# 验证DNS
kubectl run -it --rm --restart=Never --image=busybox:1.28 dns-test -- nslookup kubernetes.default
```

### 配置网络策略

```bash
# 安装Calico网络策略
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/tigera-operator.yaml
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/custom-resources.yaml
```

## 安全配置

### RBAC配置

```bash
# 创建管理员用户
kubectl create serviceaccount admin-user -n kube-system
kubectl create clusterrolebinding admin-user-binding --clusterrole=cluster-admin --serviceaccount=kube-system:admin-user

# 获取Token
kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep admin-user | awk '{print $1}')
```

### 配置Pod安全策略

```bash
# 启用Pod安全策略
kubectl apply -f https://raw.githubusercontent.com/kubernetes/website/main/content/en/examples/policy/privileged-psp.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes/website/main/content/en/examples/policy/baseline-psp.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes/website/main/content/en/examples/policy/restricted-psp.yaml
```

## 监控配置

### 安装Metrics Server

```bash
# 安装Metrics Server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# 验证安装
kubectl top nodes
kubectl top pods
```

## 故障排查

### 常见问题

1. **节点NotReady**
   ```bash
   # 检查kubelet状态
   sudo systemctl status kubelet
   
   # 查看kubelet日志
   sudo journalctl -u kubelet -f
   ```

2. **Pod启动失败**
   ```bash
   # 查看Pod事件
   kubectl describe pod <pod-name> -n <namespace>
   
   # 查看Pod日志
   kubectl logs <pod-name> -n <namespace>
   ```

3. **网络连接问题**
   ```bash
   # 检查网络插件状态
   kubectl get pods -n kube-system | grep calico
   
   # 测试网络连通性
   kubectl run -it --rm --restart=Never --image=busybox:1.28 network-test -- nslookup kubernetes.default
   ```

### 性能优化

1. **调整kubelet参数**
   ```bash
   # 编辑kubelet配置
   sudo vim /var/lib/kubelet/config.yaml
   
   # 重启kubelet
   sudo systemctl restart kubelet
   ```

2. **优化容器运行时**
   ```bash
   # 配置containerd镜像加速
   sudo vim /etc/containerd/config.toml
   
   # 重启containerd
   sudo systemctl restart containerd
   ```

## 下一步

集群搭建完成后，请继续：

1. [安装Helm](./04-helm-setup.md)
2. [配置存储](./02-storage-setup.md)
3. [部署监控](./05-monitoring-setup.md)
4. [开始部署平台](../scripts/deploy-platform.sh)

## 参考资源

- [Kubernetes官方文档](https://kubernetes.io/docs/)
- [Kubeadm安装指南](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/)
- [Kind文档](https://kind.sigs.k8s.io/)
- [Calico文档](https://docs.tigera.io/calico/) 