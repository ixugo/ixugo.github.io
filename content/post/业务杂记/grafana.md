---
title: 使用 Grafana 全家桶进行主机监控
description: 
date: 2023-11-07
slug: 
image: 
draft: false
categories:
    - 运维
tags:
---



## 部署

**端口**

| grafana       | 3000 |
| ------------- | ---- |
| prometheus    | 9090 |
| node_exporter | 9100 |

**创建配置文件**

`vim prometheus.yml`

```yaml
# prometheus.yml
global:
  scrape_interval: 15s # 每15秒抓取一次指标
  evaluation_interval: 15s # 每15秒评估一次规则

scrape_configs:
  # 可选：也让 Prometheus 监控自己
  - job_name: 'prometheus'
    static_configs:
      - targets: [ 'localhost:9090' ]
  - job_name: 'node'
    static_configs:
      - targets: ['localhost:9100']
```

**创建 docker-compose.yml 文件**

`vim docker-compose.yml`

```yml
services:
  grafana:
    image: registry.cn-shanghai.aliyuncs.com/lnton/grafana:latest
    user: "root:root"
    container_name: grafana
    restart: unless-stopped
    volumes:
      - ./grafana/datasource:/etc/grafana/provisioning/datasources
      - ./grafana/data:/var/lib/grafana
    environment:
      - GF_PATHS_PROVISIONING=/etc/grafana/provisioning
      - GF_AUTH_ANONYMOUS_ENABLED=false # 禁止匿名访问，必须登录
      # - GF_SERVER_ROOT_URL=http://ip:port
        # - GF_SERVER_SERVE_FROM_SUB_PATH=true
    network_mode: host
      #    ports:
      # - '3000:3000'
  prometheus:
    image: registry.cn-shanghai.aliyuncs.com/lnton/prometheus:latest
    container_name: prometheus
    volumes:
      # 将宿主机当前目录下的 prometheus.yml 挂载到容器内
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
    restart: unless-stopped
    network_mode: host

      #networks:
      #- monitoring
  node_exporter:
    image: quay.io/prometheus/node-exporter:latest
    command:
      - '--path.rootfs=/host'
    network_mode: host
    pid: host
    restart: unless-stopped
    volumes:
      - '/:/host:ro,rslave'
```

## Grafana 配置 SMTP

编辑 docker-compose 文件，给 grafana 增加环境变量

注意 GF_SMTP_HOST 必须携带端口号

```bash
      - GF_SMTP_ENABLED=true
      - GF_SMTP_HOST=smtp.qiye.163.com:465
      - GF_SMTP_USER=xxxxxxx@163.com
      - GF_SMTP_PASSWORD=password
      - GF_SMTP_FROM_ADDRESS=xxxxxx@163.com
      - GF_SMTP_FROM_NAME=name
```

更新后，按照以下流程测试能否收到邮件

![image-20250907150748054](http://img.golang.space/img-1757228868159.png)

## 模板

在仪表板导入模板

node_exporter ，[可以看看 16098](https://grafana.com/grafana/dashboards/16098-node-exporter-dashboard-20240520-job/)

livekit，[可以看看 15237](https://grafana.com/grafana/dashboards/15237-livekit-metrics/)

![image-20250907145556845](http://img.golang.space/img-1757228157436.png)