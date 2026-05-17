---
title: 小米路由器配置 docker compose
date: 2026-03-23
slug: 
image: 
draft: true
categories:
    - docker
tags:
    - docker
---



检查外接设备的路径，例如是 `ln -s /mnt/usb-35f6643a` ，这个太难记了，做个软连接。

```bash
ln -s /mnt/usb-35f6643a /mnt/xiaomi
```

对 docker 设置一个别名

```bash
vim /etc/profile
alias docker=/mnt/xiaomi/mi_docker/docker-binaries/docker
source /etc/profile
```

运行   portainer

```bash
docker run -d \
  --name portainer \
  --restart=always \
  -p 9000:9000 \
  -p 9443:9443 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /mnt/xiaomi/portainer_data:/data \
 portainer/portainer-ce:latest
```





## 参考

