---
title: Docker 学习笔记
description: 
date: 2020-03-05 10:00:00
slug: 
image: 
draft: false
categories:
    - 容器
tags:
    - Docker
---



# Docker 

![ ](http://img.golang.space/PicGo/20200204184919.png)

+ image 镜像, 相当于类
+ container 容器, 相当于对象
+ repository 仓库, 集中存储镜像
+ tag 标签, 版本号





零  安装 docker

https://docs.docker.com/engine/install/ubuntu/  官方文档

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
  sudo apt-get install docker-ce docker-ce-cli containerd.io
```







## 一 重用命令

1. **帮助命令**

    1. `docker info`   列出当前docker 的所有信息
    2. `docker --help` 帮助

2. **镜像命令**

    1. `docker images` 列出本地所有镜像

        > -a 所有
        >
        > -q 全部镜像 id
        >
        > --digests 摘要说明
        >
        > --no-true 列出完整信息,比如长 id

    2. `docker search {image}`  搜索镜像

        > -s  点赞数排序     docker search -s 30 ubuntu   // 列出30以上点赞的ubuntu 镜像
        >
        > --no-trunc  完整信息
        >
        > --automated 只列出automated build 镜像

    3. `docker pull {image[:tag]}`  下载镜像

    4. `docker rmi {image} `  删除某个镜像

        >-f  强制删除, 当有容器在运行时需要强制删除才能删除镜像
        >
        >参数可以是 镜像id, 也可以是唯一镜像名, 多个镜像以空格分割
        >
        >删除全部  docker rmi -f ${docker images -qa}

3. **容器命令**

    1. `docker run [option] {image} [command] [ARG...]`  运行镜像

        > -name 名字
        >
        > -d 后台运行
        >
        > -i 交互运行,与 -t 一同使用
        >
        > -t 分配伪终端
        >
        > -P 随机端口映射
        >
        > -p 指定端口映射  8888:8080   对外暴露端口, 内部端口

    2. `docker ps`查看容器

        > 仅仅查看正在运行的容器
        >
        > -a  查看所有容器,正在运行+历史运行
>
        > -l 显示最近创建
        >
        > -n 显示最近 n 个容器
        >
        > -q 静默模式, 只显示容器编号
        >
        > --no-trunc   不截断输出(完整信息)

3. 退出容器

    1. exit   容器停止退出
    2. ctrl+p+q  容器不停止退出

4. `docker start`启动容器

5. `docker restart` 重启容器

6. 停止容器

    1. `docker stop`    软停止
    2. `docker kill`   强制

7. `docker rm `删除容器

    > 一次性删除多个
    >
    > docker ps -aq | xargs docker rm

8. ==守护进程==  以后台方式启动容器,

    ![](http://img.golang.space/PicGo/20200204143931.png)

    **docker 容器后台运行, 必须有一个前台进程**

9. 查看容器日志

    ```bash
    docker logs -ft --tail 3 3757f
    ```

    ![](http://img.golang.space/PicGo/20200204144948.png)

    > -t   加入时间
    >
    > -f   跟随最新的日志
    >
    > --tail n  显示最后 n 条

10. 查看容器内进程

    ```bash
    docker top 501d8
    ```

    ![](http://img.golang.space/PicGo/20200204145230.png)

11. 查看容器内部细节

     ```bash
     docker inspect 501d8
     ```

     ![](http://img.golang.space/PicGo/20200204145449.png)

12. 进入容器

    1. `docker exec -it 容器id /bin/bash` 进入并可以启动新进程, 末尾加命令可以蹭蹭不进去![](http://img.golang.space/PicGo/20200204150225.png)
    2. 重新进入  `docker attach 容器id`     直接进入,不会启动新进程

13. `docker cp`拷贝

    ```bash
    docker cp  容器id:/home/demo.go ~/Desktop/demo.go  // 容器内拷贝到宿主机
    docker cp ~/Desktop/demo.go 容器id:/home/demo.go   // 宿主机拷贝到容器
    ```




![](http://img.golang.space/PicGo/20200204151900.png)



如果不指定镜像的版本, 默认最新版,  `:latest`,  使用   `{image}:{tag} ` 来指定版本





## 二 补充



1. 提交容器副本使之建立新镜像

    > docker commit
    >
    > docker commit -m="描述信息" -a="作者" 容器id 要创建的目标镜像名:[标签名]

    ```bash
    docker commit -a="breeze" -m="delete tomcat docs" 614 breeze/tomcat:0.1
    ```

![](http://img.golang.space/PicGo/20200204173756.png)

2. 打包成压缩包

   ```bash
   docker save -o adc.tar <镜像名>
   # 加载镜像
   docker load -i adc.tar
   ```

   



## 三 容器数据卷

目的是解决 持久化与数据共享, 没有目录会自动创建目录

```bash
docker run -it -v /宿主机绝对路径:/容器内目录  镜像名
```

![](http://img.golang.space/PicGo/20200204190930.png)

> 添加权限   :ro    read only ,  仅仅可读

```bash
docker run -it -v /宿主机绝对路径:/容器内目录:ro  镜像名
```

开启多个容器卷

```bash
docker run -it -v /host1:/volume1 -v /host2:/volume2 centos
```

通过 `docker inspect` 查看镜像信息, 关键字 `volumes` 表示数据卷, true 表示可使用



> 共享数据    --volumes-from

新建容器,并共享前一个容器的数据卷

```bash
docker run -it --name dc02 ---volumes-from dc01 breeze/centos
```





## 四 Dockerfile

dockerfile 用来构建 docker 镜像的构建文件, 由一系列命令和参数构成的脚本



> 如何用?

通过 dockerfile 创建镜像

```bash
docker build -f /mydocker/dockerfile -t breeze/centos .
```

注意后面有个 `.`  , 即在当前目录生成

![](http://img.golang.space/PicGo/20200205102003.png)

> 说明

+ 每条保留字指令都必须为大写字母且后面要跟随至少一个参数
+ 指令从上到下, 顺序执行
+ 每条指令都会创建一个新的镜像层, 并对镜像进行提交



> 指令

+ FROM    基础镜像, 当前镜像基于哪个镜像
+ MAINTAINER  镜像维护者的姓名和邮箱
+ RUN   容器构建时需要运行的命令
+ EXPOSE 当前容器对外暴露出的端口
+ WORKDIR   制定创建容器后, 终端默认登录的工作目录
+ ENV   构建镜像过程中设置环境变量
+ ADD   将宿主机目录下的文件拷贝进镜像且自动处理 url 和解压 tar 压缩包
+ COPY  类似 add, 拷贝文件和目录到镜像中
+  VOLUME  容器数据卷, 数据保存和持久化工作
+ CMD  指定一个容器启动时运行的命令, 可以有多个, 但只执行一个
+ ENTRYPOINT  指定容器启动时运行的命令
+ ONBUILD  构建一个被继承的 dockerfile 时运行命令, 父镜像被子继承后 父镜像的 onbuild 被触发, 基础镜像 scratch







## 共享网络   --net=host

![image-20200407104946843](http://img.golang.space/PicGo/1586227787015-image-20200407104946843.png)



## 那些坑

> 容器内时间与宿主机时间相差 8 小时

```bash
docker cp /etc/localtime 41c:/etc/localtime
```

![](http://img.golang.space/PicGo/20200204193715.png)



> 使用数据卷, 挂载主机目录 docker 访问出现error

提示为：　cannot open directory : Permission denied

解决　：　在挂载目录时增加参数　　　--privileged=true

```

```

## 配置加速地址

### 1 mac



```bash
https://xobyp2t2.mirror.aliyuncs.com
```



![image-20200407113130792](http://img.golang.space/PicGo/1586230290960-image-20200407113130792.png)

### 2 ubuntu

通过修改daemon配置文件/etc/docker/daemon.json来使用加速器

```json
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json <<-'EOF'
{
  "registry-mirrors": ["https://xobyp2t2.mirror.aliyuncs.com"]
}
EOF
sudo systemctl daemon-reload
sudo systemctl restart docker
```







## docker  常用软件们





安装 ctop  性能监控

```bash
wget https://github.com/bcicen/ctop/releases/download/v0.7.1/ctop-0.7.1-linux-amd64  -O /usr/local/bin/ctop

chmod +x /usr/local/bin/ctop
```





### 1 mysql 8.0

运行实例

```bash
docker run --name first-mysql -p 3308:3306 -e MYSQL_ROOT_PASSWORD=123456 -d mysql
docker run --name second-mysql -p 3307:3306 -e MYSQL_ROOT_PASSWORD=123456 -d mysql
```



> 使用 docker 部署 mysql 集群

```bash
mysql -h127.0.0.1 -uroot -P3308 -p123456
```

```go
mysql -h127.0.0.1 -uroot -P3307 -p123456
```



![show master status;](http://img.golang.space/PicGo/1587043681910-image-20200416212801633.png)



1 

```bash
show master status;
```





> 无法登陆

sudo apt install gnupg2 pass 