---
title: 设置 Gitea Actions 
description: 
date: 2024-04-28
slug: 
image: 
draft: false
categories:
    - 后端
tags:


---

# Gitea Actions



## 下载文件

```bash
wget https://gitea.com/gitea/act_runner/releases/download/v0.2.10/act_runner-0.2.10-linux-amd64 -O act_runner

chmod +x ./act_runner
./act_runner --version
```

[最新版本点这里](https://gitea.com/gitea/act_runner/releases)

## 注册到 Gitea

```bash
./act_runner register --no-interactive --instance <instance> --token <token>
```

instance 就是 Gitea 的访问地址，例如 `https://gitea.com`

token  可以在 Gitea 实例的 [管理后台]  - [Actions] 获取。

![image-20240413145106002](http://img.golang.space/img-1712991066270.png)

## 启动

```bash
./act_runner daemon
```

也可以使用 docker-compose 来启动

```yaml
version: "3.8"
services:
  runner:
    image: gitea/act_runner:nightly
    environment:
      CONFIG_FILE: /config.yaml
      GITEA_INSTANCE_URL: "${INSTANCE_URL}"
      GITEA_RUNNER_REGISTRATION_TOKEN: "${REGISTRATION_TOKEN}"
      GITEA_RUNNER_NAME: "${RUNNER_NAME}"
      GITEA_RUNNER_LABELS: "${RUNNER_LABELS}"
    volumes:
      - ./config.yaml:/config.yaml
      - ./data:/data
      - /var/run/docker.sock:/var/run/docker.sock
```

## 在存储库设置页面启用 actions

![image-20240413145732889](http://img.golang.space/img-1712991453037.png)

## 参考

[act_runner gitea 仓库](https://gitea.com/gitea/act_runner)

