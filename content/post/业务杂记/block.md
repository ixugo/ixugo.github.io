---
title: block
description: 
date: 2024-03-30
slug: 
image: 
draft: true
categories:
    - 后端
tags:


---

# 

# Block

block 专门分析程序中的阻塞情况，即 goroutine 被阻塞等待的时间。

如果要开启采样

```go
// 0: 不采样; 1:全部采样，>1 设置纳秒的采样率
runtime.SetBlockProfileRate(1)
```

通过 web 视图分析

```go
 go tool pprof -http=:53139 http://localhost:8080/debug/pprof/block
```

![image-20250524112326398](http://img.golang.space/img-1748057006627.png)

图中的 `0 of 14.43hrs`  数值含义，hrs 是 `hours` 的缩写。

+ **第一个数字**（如 `0 of 14.43hrs`）：表示该函数自身的阻塞时间（这里是0小时）
+ **第二个数字**（如 `14.43hrs`）：表示该函数及其所有子调用的总阻塞时间
+ **括号内百分比**（如 `49.32%`）：表示该阻塞时间占总阻塞时间的比例

从这张图中可以解读出

- 大量 goroutine 在使用 channel 或 select 语句通信
- 可能有 goroutine 在等待永远不会到来的消息
- 检查 `tickGroup` 和 `runWriteLoop` 中的 select/channel 使用

注意，pprof 的阻塞时间是**所有 goroutine 阻塞时间的总和**，而不是程序的实际运行时间

+ 如果有 1000 个 goroutine 同时阻塞了 1 分钟
+ 那么累积阻塞时间 = 1000 * 1分钟 ≈ 16.67小时
+ 但程序实际运行时间可能只有 1 分钟

