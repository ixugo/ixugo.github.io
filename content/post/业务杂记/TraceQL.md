---
title: 使用 TraceQL 查询
description: 
date: 2023-10-15
slug: 
image: 
draft: false
categories:
    - 遥测
tags:
    - 

---



# 使用 TraceQL 查询

受 PromQL 和 LogQL 的启发，TraceQL 是一种查询语言，设计用于在 Tempo 中选择跟踪。目前，TraceQL 查询可以根据以下内容选择跟踪：

+ Span and resource attributes, timing, and duration
+ 基本聚合， `count(), avg(),min(),max(),sum()`

## 构建查询

在 TraceQL 中，查询是一次对一个追踪求值的表达式。查询的结构为一组链式表达式（管道）。管道中的每个表达式都会选择或放弃包含在结果集中的范围集。例如：

```bash
{ span.http.status_code >= 200 && span.http.status_code < 300 } | count() > 2
```

大括号 `{}` 始终从当前追踪中选择一组范围。自定义属性以 `.`，`span.`，`resource.` 为前缀，内在函数可直接键入。

关键字

![image-20231015110845660](http://img.golang.space/img-1697339325840.png)