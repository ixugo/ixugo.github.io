---
title: 公网部署 k8s
description: 
date: 2021-11-05 15:00:00
slug: 
image: 
draft: false
categories:
    - 容器
tags:
    - Kubernets
---



# 公网部署 K8s

**环境**

一台腾讯云轻量应用服务器 2 核 4G

一台阿里云共享型服务器 1 核 2G

ubuntu 18.04 ( CKA 认证环境的系统 )

趁着双十二活动，花了 74 入手腾讯云轻量应用服务器，用于搭建 k8s 集群环境



## [环境准备](https://kubernetes.io/zh/docs/setup/production-environment/tools/kubeadm/install-kubeadm/)

```bash
# 永久关闭交换区
sudo sed -i 's/.*swap.*/#&/' /etc/fstab

# 修改主机名
# master 节点执行
hostnamectl set-hostname master1 
# node 节点执行
hostnamectl set-hostname node1
```

允许 iptables 检查桥接流量

```bash
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

sudo sysctl --system
```

如下图所示，开放相应端口，如果使用 flannel 网络插件，需要开放 upd/8472 端口

![image-20211222010656008](http://img.golang.space/shot-1640106416152.png)



## 安装工具

**安装 docker，国内建议自行使用镜像安装，以下为docker官网提供的安装方式**

```bash
sudo apt-get install \
    ca-certificates \
    curl \
    gnupg \
    lsb-release
    
    
 curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg


echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  
 sudo apt-get update
 sudo apt-get install -f docker-ce docker-ce-cli containerd.io
```

配置 docker 的 cgroup，要跟 kubelet 使用的保持一致，否则 kubelet 进程会失败。

 `systemd` 是 k8s 默认驱动。

```bash
cat > /etc/docker/daemon.json <<EOF
{
	"exec-opts": ["native.cgroupdriver=systemd"],
}
EOF

systemctl restart docker
```

**安装 kubeadm**

国内安装

```bash
cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb http://mirrors.tuna.tsinghua.edu.cn/kubernetes/apt/ kubernetes-xenial main
EOF

sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys FEEA9169307EA071

sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 8B57C5C2836F4BEB

sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
systemctl enable --now kubelet
```

为 ip 配置别名

```bash
#echo "${ip} ${主机名}" >> /etc/hosts
echo "${master1_ip} master1" >> /etc/hosts
echo "${node1_ip} master2" >> /etc/hosts
```

提前拉取镜像，避免在初始化时过久等待

```bash
kubeadm config images pull --image-repository=registry.aliyuncs.com/google_containers
```

创建虚拟网卡

```bash
sudo apt install ifupdown
```

临时生效

```bash
# sudo ifconfig eth0:1 ${公网 IP}
sudo ifconfig eth0:1 44.44.44.44
```

永久生效

```bash
cat <<EOF | sudo tee /etc/network/interfaces
auto eth0:1
iface eth0:1 inet static
# address ${公网 IP}
address 44.44.44.44
netmask 255.255.255.0
EOF

150.158.141.120
```

```bash
sudo /etc/init.d/networking restart
```

修改 kubelet 启动参数

添加 kubelet 的启动参数`--node-ip=公网IP`， 每个主机都要添加并指定对应的公网 ip

```bash
sudo vi /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
```

![image-20211222012639793](http://img.golang.space/shot-1640107599909.png)

master 初始化，如果初始化失败，可以重置

```bash
kubeadm init \
--kubernetes-version v1.23.1 \
--apiserver-advertise-address=${公网IP} \
--service-cidr=10.96.0.0/16 \
--pod-network-cidr=10.244.0.0/16 \
--image-repository=registry.aliyuncs.com/google_containers


# 重置
kubeadm reset -f
rm -rf /etc/cni/net.d
rm -rf $HOME/.kube
```

```bash
#  当你看到如下信息时，初始化成功
Your Kubernetes control-plane has initialized successfully!
...
# 按提示，执行以下三行
  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config
...
# 用于 worker 节点加入集群
kubeadm join master1:6443 --token zqmjvh.5wij6n8j.........
```

修改 kube-apiserver 参数

`- --bind-address=0.0.0.0`

```bash
sudo vi /etc/kubernetes/manifests/kube-apiserver.yaml
```

![image-20211222013224975](http://img.golang.space/shot-1640107945059.png)



## 安装 flannel 网络

下载 flannel 的 的 yaml 配置文件

```bash
wget https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
```

修改配置文件

```bash
vim kube-flannel.yml
```

在 200 行左右

```bash
args:
 - --public-ip=$(PUBLIC_IP)
 - --iface=eth0

env:
 - name: PUBLIC_IP
   valueFrom:
     fieldRef:
       fieldPath: status.podIP
```

![image-20211222013457005](http://img.golang.space/shot-1640108097100.png)

开始安装网络插件

```bash
kubectl apply -f kube-flannel.yml
```



## K8s 启用 ipvs

安装工具，方便检查配置

```bash
sudo apt-get install ipvsadm
```

ubuntu 永久启用 ipvs 模块

```bash
ls /lib/modules/$(uname -r)/kernel/net/netfilter/ipvs|grep -o "^[^.]*" >> /etc/modules
```

修改配置文件，找到 `mode`，后面参数修改为 `ipvs`

```bash
kubectl edit configmap kube-proxy -n kube-system
```

![image-20211222013906175](http://img.golang.space/shot-1640108346277.png)

删除所有的 kube-proxy 的 pod，并等待自愈恢复

```bash
$ kubectl delete pods `kubectl get pods -n kube-system | grep kube-proxy  | awk '{print $1}'` -n kube-system 
```

通过 `kubectl logs ` 来查看启用 ipvs 的日志，检查是否正常启用



## worker 节点加入集群

如果 token 过期，可以使用以下命令创建新的加入命令

```bash
kubeadm token create --print-join-command
```

在 worker 节点执行，等待执行结束

```bash
kubeadm join........
```

在 master 节点检查

```bash
kubectl get nodes
```



## 部署 nginx 测试

```bash
vim nginx.yaml
```

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  selector:
    matchLabels:
      app: nginx
  replicas: 2 # tells deployment to run 2 pods matching the template
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.21.4
        ports:
        - containerPort: 80
```

```bash
kubectl apply -f nginx.yaml
```

开启服务

```bash
vim nginx-svc.yaml
```

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  selector:
    app: nginx
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
    nodePort: 30080
  type: NodePort
```

```bash
kubectl apply -f nginx-svc.yaml
```

![image-20211222015209540](http://img.golang.space/shot-1640109129671.png)

访问任意节点公网 IP:30080，查看是否能够请求到 nginx 主页

![image-20211222015313801](http://img.golang.space/shot-1640109193912.png)



## 部署 dashboard

国内可能无法访问此链接

```bash
wget https://raw.githubusercontent.com/kubernetes/dashboard/v2.3.1/aio/deploy/recommended.yaml
```

```bash
kubectl apply -f recommended.yaml
```

设置访问端口

```bash
kubectl edit svc kubernetes-dashboard -n kubernetes-dashboard
```

![image-20211223124038088](http://img.golang.space/shot-1640234438326.png)

查看端口

```bash
kubectl get svc -A |grep kubernetes-dashboard
```



## 参考

[k8s 官方安装文档](https://kubernetes.io/zh/docs/setup/production-environment/tools/kubeadm/install-kubeadm/)

[公网环境搭建 k8s 集群](https://www.caiyifan.cn/p/d6990d10.html)

[flannel](https://cloud.tencent.com/developer/article/1819134)





