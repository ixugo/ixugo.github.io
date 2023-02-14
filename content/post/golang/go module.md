---
title: Go Module
description: 
date: 2020-03-21 15:00:00
slug: 
image: 
draft: false
categories:
    - Golang
tags:
    - Go
---



分析源码中的依赖变化，自动增删依赖。

如果存在 vendor 目录，在修改依赖后，必须更新 vendor。

```bash
go mod tidy
go mod vendor
```

查询 logrus 的所有发布版本

```bash
go list -m -versions github.com/sirupsen/logrus
```

通常有指定某个版本的需要，比如升级后发现存在某些问题，需要使用更新之前的版本

```bash
go get github.com/sirupsen/logrus@v1.7.0
```

当依赖的主版本号为 0 或 1 的时候，在 Go 代码中添加导入路径不需要加版本号。

```bash
# import github.com/user/repo/v0
import github.com/user/repoimport 
# github.com/user/repo/v1
import github.com/user/repo
# 主版本号 >1 的情况
import github.com/user/repo/v2/xxx
```

