---
title: 持续集成(CI)/持续交付(CD)
description: 每一种支持的平台和环境中运行单元测试，要积极的寻找问题，而不是等问题来找你。
date: 2023-02-14
slug: 
image: http://img.golang.space/img-1676339073254.png
draft: false
categories:
    - Golang
tags:
    - CICD
---

# 持续集成(CI)/持续交付(CD)

+ 持续集成: 自动构建和自动化测试
+ 持续交付: 自动推送到发布系统
+ 持续部署: 自动将更改推送到生产中

不同环境，就有不同问题。如果应用在不同的操作系统上运行，或者操作系统的不同版本，就需要测试所有的操作系统。

使用持续集成工具，在每一种支持的平台和环境中运行单元测试，要积极的寻找问题，而不是等问题来找你。

## Caddy Server 

Caddy 2 是一个强大的、企业级、**开源的 Web 服务器，**具有用 Go 编写的 **自动 HTTPS**

### 在服务器上安装

```bash
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt update
sudo apt install caddy
```

查看 caddy 运行状态

```bash
systemctl status caddy
# 如果你还没有运行，执行
caddy start
```

此时访问 ip 将会看到 caddy 的默认页面

![image-20230214093027252](http://img.golang.space/img-1676338227412.png)

caddy 的常用命令如下

```bash
# 停止
caddy stop
# 重载当前目录的配置
caddy reload
```

在部署 Drone 之前，我们先用 caddy 作为网关，反向代理。

在 `/etc/caddy/Caddyfile` 增加几行

```bash
drone.example.com:80 {
	reverse_proxy 127.0.0.1:8000
}
```

此处 `127.0.0.1:8000` 是 drone 的服务

## Drone 

Drone 是为繁忙的开发团队提供的自助式持续集成平台。

### 在 Git 仓库平台创建第三方应用

此处以官网文档的图片示例，关于如何创建，官方文档非常详细。

回调地址大概是  应用主页/login

![Application Create](https://docs.drone.io/screenshots/gitee_token_create.png)

在服务器下，创建 drone 文件夹，编辑 docker-compose.yml 文件

```bash
mkdir /home/app/drone && cd /home/app/drone
vim docker-compose.yml
```

使用 docker-compose 部署 drone

```yaml
version: '3'

services:
  drone-server:
    image: drone/drone:latest
    ports:
      - 8000:80
 #     - 9000:443
    networks:
      - drone_network
    volumes:
      - $PWD/data:/data:rw
      - /var/run/docker.sock:/var/run/docker.sock
      - /etc/localtime:/etc/localtime
    restart: always
    environment:
      - TZ=Asia/Shanghai
      - DRONE_RPC_SECRET=<随机秘钥，试试 openssl rand -hex 16>
      - DRONE_GITEE_CLIENT_ID=<创建第三方应用时得到的 id>
      - DRONE_GITEE_CLIENT_SECRET=<创建第三方应用时得到的 secret>
      - DRONE_SERVER_HOST=<公网 IP:port 或域名>
      - DRONE_SERVER_PROTO=http
      - DRONE_TLS_AUTOCERT=false
      - DRONE_USER_CREATE=username:ixugo,admin:true
      - DRONE_NETRC_CLONE_ONLY=true
      # 如果部署后遇到问题，追踪日志依次处理
      # 部署成功后，建议注释
      - DRONE_TRACE=true
      - DRONE_DEBUG=true
      - DRONE_LOGS_DEBUG=true

  drone-runner:
    image: drone/drone-runner-docker:latest
    command: agent
    restart: always
    ports:
      - 3000:3000
    depends_on:
      - drone-server
    networks:
      - drone_network
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /etc/localtime:/etc/localtime
    dns: 114.114.114.114
    environment:
      - TZ=Asia/Shanghai
      - DRONE_RPC_HOST=drone-server
      - DRONE_RPC_PROTO=http
      - DRONE_RPC_SECRET=<随机秘钥，跟上面的配置相同>
      - DRONE_RUNNER_CAPACITY=2
      - DRONE_RUNNER_NETWORKS=drone_network
      # 开启日志
      - DRONE_TRACE=true
      - DRONE_DEBUG=true
      - DRONE_LOGS_DEBUG=true

networks:
  drone_network:
    name: drone_network
```

执行 `docker-compose up -d` 即可，如果发现意外，检查日志查看发生的问题。

![image-20230214094433115](http://img.golang.space/img-1676339073254.png)



## 使用 CI/CD 

进入 Drone 控制面板，将会同步你的所有仓库。

如果你不是仓库的管理员，是没有权限激活的。

![image-20230214094758442](http://img.golang.space/img-1676339278546.png)

如果仓库的名称有问题，打开后会提示 404。

![image-20230214094816448](http://img.golang.space/img-1676339296561.png)

成功激活后的页面是这样

![image-20230214094850943](http://img.golang.space/img-1676339331040.png)

同时，你在对应仓库的 webhook 中将会看到多出的配置。

![image-20230214095015469](http://img.golang.space/img-1676339415563.png)

在项目中创建文件 `.drone.yml`，如下所示:

这里使用 `plugins/docker` 来构建镜像并推送到远程仓库，默认会识别当前目录下的 Dockerfile 文件。这里使用的是免费的阿里云个人镜像仓库，如果认为这一步麻烦可以跳过。将构建的应用程序放到主机上，远程执行命令在主机上构建。

避免秘钥泄露在公共仓库中，请使用 from_secret，该参数在 drone settings 中配置。

使用 `appleboy/drone-ssh` 对远程主机通信，可用来执行部署操作。

```yml
---
kind: pipeline
type: docker
name: build

platform:
  os: linux
  arch: amd64

steps:
  - name: test and build
    image: golang:1.19.5-alpine3.17
    # privileged: true
    # volumes:
    #   - name: deps
    #     path: /tmp/cache
    commands:
      - go test ./...
      - go build -o start
  - name: build Docker image and push
    image: plugins/docker
    settings:
      registry: registry.cn-hangzhou.aliyuncs.com
      repo: <名字>
      use_cache: true
      username:
        from_secret: registry_username
      password:
        from_secret: registry_password
      auto_tag: true # 自动打tag
  - name: ssh commands
    image: appleboy/drone-ssh
    environment:
      DEBUG_STR: asdasd
    settings:
      host:
        from_secret: debug_host
      username:
        from_secret: debug_username
      key:
        from_secret: debug_password
      port:
        from_secret: debug_port
      script:
        - echo start
        - docker pull <镜像名>

environment:
  CGO_ENABLED: 0
  GOOS: linux
  GOARCH: amd64

# volumes:
#   - name: deps
#     host:
#       path: /home/app/test/build

trigger:
  branch:
    - main
  event:
    - push
```

当你在 main 分支推送代码后，drone 将会自动执行工作流。

![image-20230214095716411](http://img.golang.space/img-1676339836528.png)

## 参考

[Caddy 2 官方文档](https://caddyserver.com/docs/install)

[Drone 官方文档](https://docs.drone.io/)

[Drone 插件 ssh](https://plugins.drone.io/plugins/ssh)

[Drone 插件 docker](https://plugins.drone.io/plugins/docker)

[ 博客 使用 Drone Pipeline 构建 Docker 镜像](https://www.qikqiak.com/post/drone-with-k8s-2/)

[私有化轻量级持续集成部署方案--05-持续部署服务-Drone（下）](https://www.cnblogs.com/yan7/p/15881091.html)

[私有存储库注入身份验证权限](https://docs.drone.io/pipeline/docker/syntax/cloning/auth/)











