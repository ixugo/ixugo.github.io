---
title: OpenTelemetry
description: 
date: 2023-10-10
slug: 
image: 
draft: false
categories:
    - 遥测
tags:
    - 
---

# OpenTelemetry

OpenTelemetry 是一个可观察性框架和工具包，用于创建和管理链路，指标和日志等遥测数据。

它不像 Jaeger，Prometheus 那样的可观察性后端，它专注于遥测数据的生成，收集，管理和导出。数据的存储和可视化由其它工具提供。

## 可观察性

---

**什么是可观察性?**

从外部了解应用系统内正发生什么。

**可靠性和指标**

遥测是指从系统发出的有关其行为的数据，数据可以是链路，指标，日志的形式。

服务是否按照用户期望的运行? 如果用户将一条黑色裤子添加到购物车，但系统显示红色的裤子，显然被认为是不可靠。

指标是一段时间内，有关基础设置和应用程序的数字数据的聚合。包括 CPU ，错误率 ，调用频率，连接数，请求次数等等。

SLI ( Service Level Indicator )，表示服务的衡量标准，例如网页加载的速度。

SLO ( Service Level Objective  )，向组织传达可靠性的方式。

## 了解分布式追踪

---

**日志**

日志是由服务或其它组件发出的带有时间戳的消息，过去开发人员和运维人员非常依赖它们来帮助理解系统行为。

但日志对于追踪代码执行并不是非常有用，因为通常缺乏上下文信息，例如它们是从哪里调用的。

当它们与追踪相关时，会变得更加有用。

---

**Spans**

Span 代表一个工作或操作单元。它追踪请求进行的特定操作，描绘执行该操作期间发生的情况。

包含名称，时间，结构化日志消息或其它元数据。

---

**分布式追踪**

分布式追踪，记录请求在微服务架构中传播时所采用的路径。

如果没有追踪，就很难查明分布式系统中性能问题的原因。

它提高了应用程序或系统运行状况的可见性，并让我们能够调试难以在本地重现的行为。

---

## 信号

### Traces

![image-20231019005551903](http://img.golang.space/img-1697648152083.png)

提供了应用程序发出请求时发生的情况。

通过三个工作单元，用 Spans 表示:

```bash
# hello span
# 注意，它有一个指示追踪的 trace_id
{
  "name": "hello",
  "context": {
    "trace_id": "0x5b8aa5a2d2c872e8321cf37308d69df2",
    "span_id": "0x051581bf3cb55c13"
  },
  "parent_id": null,
  "start_time": "2022-04-29T18:52:58.114201Z",
  "end_time": "2022-04-29T18:52:58.114687Z",
  "attributes": {
    "http.route": "some_route1"
  },
  "events": [
    {
      "name": "Guten Tag!",
      "timestamp": "2022-04-29T18:52:58.114561Z",
      "attributes": {
        "event_attributes": 1
      }
    }
  ]
}

```

```bash
# hello-greetings span
# 这个 span 封装了特定的任务，它与 hello 共享 trace_id，并有 parent_id 指示调用关系。
{
  "name": "hello-greetings",
  "context": {
    "trace_id": "0x5b8aa5a2d2c872e8321cf37308d69df2",
    "span_id": "0x5fb397be34d26b51"
  },
  "parent_id": "0x051581bf3cb55c13",
  "start_time": "2022-04-29T18:52:58.114304Z",
  "end_time": "2022-04-29T22:52:58.114561Z",
  "attributes": {
    "http.route": "some_route2"
  },
  "events": [
    {
      "name": "hey there!",
      "timestamp": "2022-04-29T18:52:58.114561Z",
      "attributes": {
        "event_attributes": 1
      }
    },
    {
      "name": "bye now!",
      "timestamp": "2022-04-29T18:52:58.114585Z",
      "attributes": {
        "event_attributes": 1
      }
    }
  ]
}

```

```bash
# hello-salutations
# 该 span 代表此跟踪中的第三个操作，它是 `hello` span 的子级，与 `hello-greetings` 同级。
{
  "name": "hello-salutations",
  "context": {
    "trace_id": "0x5b8aa5a2d2c872e8321cf37308d69df2",
    "span_id": "0x93564f51e1abe1c2"
  },
  "parent_id": "0x051581bf3cb55c13",
  "start_time": "2022-04-29T18:52:58.114492Z",
  "end_time": "2022-04-29T18:52:58.114631Z",
  "attributes": {
    "http.route": "some_route3"
  },
  "events": [
    {
      "name": "hey there!",
      "timestamp": "2022-04-29T18:52:58.114561Z",
      "attributes": {
        "event_attributes": 1
      }
    }
  ]
}
```

在三个 JSON 块，有相同的 trace_id，有 parent_id 来表示层次结构，具有上下文，相关信息，层次结构。

---

**Tracer Provider**

这是 Tracer 的工厂，在大多数应用程序中，Provider 会初始化一次，还包括 Resource 和 Exporter 初始化。

---

**Tracer**

tracer 创建的 span 包含有关给定操作锁发生情况的更多信息，由 Tracer Provider 创建。

---

**Trace Exporters**

追踪导出器将数据发送给消费者。可以是 OpenTelemetry Collector 或其它后端。

---

**Context Propagation**

上下文传播是实现分布式跟踪的核心概念。通过上下文传播，Span 可以互相关联并组装成 Tracer。

Context 是一个对象，其中包含发送和接收服务的信息，用于将一个 Span 与 另一个 Span 关联起来。

Propagation 是在服务和进程之间移动上下文的机制，它序列化或反序列化上下文对象。OpenTelemetry 支持多种不同的上下文格式。 OpenTelemetry 跟踪中使用的默认格式称为 W3C TraceContext。

---

**Spans**

Span 是 Traces 的构建模块。包含以下信息:

+ Name
+ Parent span ID (empty for root spans)
+ Start and End Timestamps
+ Span Context，每个 Span 不可变对象，包含 trace_id，span_id，state
+ Attributes，包含元数据的键值对，描述追踪操作的信息
+ Span Events，可以被认为是结构化日志，通常表示持续时间内有意义的单一时间点
+ Span links，关联多个 span，因果关系。
+ Span Status，当代码中出现错误时，可以设置 span 状态。
  + `Unset`，由处理 span 的后端分配
  + `OK`，一切正常
  + ``Error`，代码中出现错误

```bash
{
  "trace_id": "7bba9f33312b3dbb8b2c2c62bb7abe2d",
  "parent_id": "",
  "span_id": "086e83747d0e381e",
  "name": "/v1/sys/health",
  "start_time": "2021-10-22 16:04:01.209458162 +0000 UTC",
  "end_time": "2021-10-22 16:04:01.209514132 +0000 UTC",
  "status_code": "STATUS_CODE_OK",
  "status_message": "",
  "attributes": {
    "net.transport": "IP.TCP",
    "net.peer.ip": "172.17.0.1",
    "net.peer.port": "51820",
    "net.host.ip": "10.177.2.152",
    "net.host.port": "26040",
    "http.method": "GET",
    "http.target": "/v1/sys/health",
    "http.server_name": "mortar-gateway",
    "http.route": "/v1/sys/health",
    "http.user_agent": "Consul Health Check",
    "http.scheme": "http",
    "http.host": "10.177.2.152:26040",
    "http.flavor": "1.1"
  },
  "events": [
    {
      "name": "",
      "message": "OK",
      "timestamp": "2021-10-22 16:04:01.209512872 +0000 UTC"
    }
  ]
}

```

---

**Span Kind**

Span 有以下类型:

+ client，子级通常是 server span，表示同步传出远程调用。
+ server，父级通常是 client span，表示远程过程调用。
+ internal，未提供类型，则默认为此类型，表示不跨越 span 的操作。
+ producer，子级通常是 consumer span，表示创建一个稍后可能会异步处理的作业。
+ consumer，父级通常是 producer span，表示对 producer 创建的作业的处理，可能再很久之后才开始。

---

### Metrics

对运行时捕获的测量，捕获测量的时刻称为度量事件，不仅包括测量本身，还包括捕获的时间和关联的元数据。

应用程序和请求指标是可用性和性能的重要指标，自定义指标可以深入了解其如何影响用户体验或业务。收集的数据可用于发出警报或调度决策，以根据高需求自动扩展部署。

---

**Meter Provider**

是 Metrics 的工厂，它会初始化一次，还包括 Resource 和 Exporter 初始。

---

**Meter**

创建度量工具，在运行时捕获有关服务的测量结果。

---

**Metric Exporter**

将数据发送给消费者，可以是标准输出OpenTelemetry Collector 或其它后端。

---

**Metric Instruments**

测量结果由它捕获，定义如下:

+ Name
+ Kind
+ Unit
+ Description

instrument 的 kind 有:

+ counter，计数器，只会上涨
+ asynchronous counter，异步计数器，与计数器相同，但每次导出只会收集一次。如果无法访问连续增量，而只能访问聚合值，则可以使用。
+ UpDownCounter，随着时间积累的值，可以下降。
+ asynchronous UpDownCounter，与 UpDownCounter 相同，但每次导出时收集一次。
+ Gauge ，仪表，测量读取时的当前值，例如汽车的功率表。
+ Histogram ，直方图，值的聚合，例如请求延迟，例如有多少个请求花费的时间大于 1 秒。

---

**Aggregation**

将大量结果组合成有关窗口期发生的度量事件。

例如:

+ 系统调用持续时间
+ 请求数量趋势
+ CPU 或 内存使用情况
+ 账号的平均余额
+ 当前正在处理的活动请求

---

**View**

视图为用户提供自定义输出指标的灵活性。

---

### Logs

Go 版本截止 2023-10-14 尚未实现，略。

### Baggage

是在 Span 之间传递的 Context 信息，它是一个键值对存。

假设希望追踪中的每个范围都有一个 CustomerID 属性，涉及多个服务，但是 CustomerID 仅一项特定服务可用，为了实现目标，可以使用 Baggage 在整个系统中传播此值。

通常将 账号标识，用户 ID，产品 ID等等内容，附加到下游服务中的 Span ，以便于搜索时过滤。

## 参考

[OpenTelemetry-Go Github](https://github.com/open-telemetry/opentelemetry-go#opentelemetry-go)

[Go 语言实现的 Otel 文档](https://opentelemetry.io/docs/instrumentation/go/)

[Otel 概念](https://opentelemetry.io/docs/concepts/)





