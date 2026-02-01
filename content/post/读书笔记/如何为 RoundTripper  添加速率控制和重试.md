---
title: 如何为 http.RoundTripper 添加速率控制和重试功能
description: 原生的 net/http 并没有提供请求失败时的重试功能，也没有限制每秒最大请求数的速率控制功能，通过 http.RoundTripper 来扩展实现这两个功能。
date: 2022-10-21
slug: 
image: 
draft: false
categories:
    - Go
tags:
    - 读书笔记
---

## 介绍

在 Go 中向外部发起 HTTP 请求时，大多数情况下会使用 net/http。

net/http 已具备常规所需的功能，但如果需要单独扩展功能，可以使用 http.RoundTripper 接口。

## 想要实现的功能

原生的 net/http 并没有提供请求失败时的重试功能，也没有限制每秒最大请求数的速率控制功能。

因此本次我们打算实现以下两种功能：

+ 重试处理
+ 速率控制

通过 http.RoundTripper 来扩展实现这两个功能。

## 准备工作

首先准备本次要实现的 http.RoundTripper 框架。

定义一个包含 http.RoundTripper 字段的结构体(MyTransport)，并定义初始化函数。

此外，通过向 MayTransport 的接收器函数添加 `RoundTrip(req *http.Request) (*http.Response, error)` ，可以隐式地使其符合 http.RoundTripper 接口。

```go
import (
	"net/http"
)

type MyTransport struct {
	wrapped http.RoundTripper
}

func NewMyTransport(transport http.RoundTripper) *MyTransport {
	return &MyTransport{
		wrapped: transport,
	}
}

func (t *MyTransport) RoundTrip(req *http.Request) (*http.Response, error) {
	return t.wrapped.RoundTrip(req)
}
```

通过在 RoundTrip 中添加处理逻辑，可以在 HTTP 请求前后添加处理功能。

## 重试控制

在 MyTransport 字段中添加最大重试次数和已重试次数。

```go
type MyTransport struct {
	wrapped http.RoundTripper

	maxRetryCounts int // 最大リトライ数
	retryCounts    int // リトライした数
}
```

使初始化时能够传递 maxRetryCounts 的值。

```go
func NewLimitedTransport(transport http.RoundTripper, maxRetryCounts int) *MyTransport {
	return &MyTransport{
		wrapped:        transport,
		maxRetryCounts: maxRetryCounts,
	}
}
```

接下来在 RoundTrip 内部添加重试处理。

当响应的状态码为 50x 及以上时进行重试。

另外，重试次数不超过 maxRetryCounts 指定的上限，并使用 Exponential BackOff 算法呈指数级增加重试间隔。

```go
func (t *MyTransport) RoundTrip(req *http.Request) (*http.Response, error) {
	var res *http.Response
	var err error
	for {
		// 実際のhttpリクエストはここ
		res, err = lt.wrapped.RoundTrip(req)

		// 50x系以上はリトライ
		if res != nil && res.StatusCode < http.StatusInternalServerError {
			break
		}

		// リトライ数の上限チェック
		lt.retryCounts++
		if lt.retryCounts > lt.maxRetryCounts {
			break
		}

		// Exponential BackOff でウェイトを入れる
		time.Sleep(time.Second * time.Duration(math.Pow(2, float64(lt.retryCounts))))
	}
	lt.retryCounts = 0
	return res, err
}
```

## 速率控制

本次我们使用 Fixed Window Counter 算法来实现速率控制。

简单来说，就是将经过的时间按固定期间进行分割，在每个期间内限制允许的请求数量的算法。

定义表示固定期间的结构体(Window)，并将单位时间内的请求次数上限、单位时间(ms)、当前 window 作为 MyTransport 的字段添加进去。

```go
type MyTransport struct {
... 省略
	maxRequestCounts int    
	perMilliSecond   int64  
	window           Window 
}


type Window struct {
	key           int64 
	requestCounts int   
}
```

在 MyTransport 的初始化时能够对这些进行初始化。

```go
func NewMyTransport(transport http.RoundTripper, maxRetryCounts int, maxRequestCounts int, perMilliSecond int64) *MyTransport {
	return &MyTransport{
		wrapped:          transport,
		maxRequestCounts: maxRequestCounts,
		perMilliSecond:   perMilliSecond,
		maxRetryCounts:   maxRetryCounts,
		retryCounts:      0,
		window: Window{
			key:           int64(0),
			requestCounts: 0,
		},
	}
}
```

最后将速率控制处理添加到 RoundTrip 中。

将当前时间戳除以 perMilliSecond 并向下取整作为窗口的键值。

这个键值每隔 perMilliSecond 毫秒就会更新为新值，因此在同一窗口内是唯一的键。

```go
func (t *MyTransport) RoundTrip(req *http.Request) (*http.Response, error) {
	for {
		now := time.Now().UnixMilli()
		cKey := now / t.perMilliSecond

    // 如果当前窗口和上一次记录的窗口不同（即进入了一个新窗口），就重置计数器为 0，并允许立即发送请求
		if t.window.key != cKey {
			t.window = Window{
				key:           cKey,
				requestCounts: 0,
			}
			break
		}
    // 如果还在同一个窗口内，但当前请求数还没达到上限（maxRequestCounts），也允许立即发送。
		if t.window.requestCounts < t.maxRequestCounts {
			break
		}
    // 如果当前窗口内请求数已达上限，则需要等待到当前窗口结束。
		wait := t.perMilliSecond - now%t.perMilliSecond
		time.Sleep(time.Millisecond * time.Duration(wait))
	}
	t.window.requestCounts++
  // ...省略，处理请求
	return res, err
}
```

## 测试

那么，我们来使用完成的 MyTransport 进行测试。

本次测试将使用以下设置:

+ 最大重试次数为 5
+ 每 4.5 秒最多 3 个请求

```go
client := http.Client{
	Transport: NewMyTransport(
		http.DefaultTransport,
		5,    // 最大リトライ数
		3,    // 単位時間あたりのリクエスト数上限
		4500, // 単位時間(ms)
	),
}
```

使用此配置向返回 500 的端点发送请求试试看

```go
resp, _ := client.Get(url)
defer resp.Body.Close()
```

结果如图所示，可以看到重试间隔逐渐增大，并且最多重试了 5 次

```go
{"time":"2022-09-09T08:59:01.521892211Z","level":"INFO","prefix":"-","file":"http.go","line":"69","message":"500"}
{"time":"2022-09-09T08:59:03.577460181Z","level":"INFO","prefix":"-","file":"http.go","line":"69","message":"500"}
{"time":"2022-09-09T08:59:07.642723871Z","level":"INFO","prefix":"-","file":"http.go","line":"69","message":"500"}
{"time":"2022-09-09T08:59:15.713717009Z","level":"INFO","prefix":"-","file":"http.go","line":"69","message":"500"}
{"time":"2022-09-09T08:59:31.822121165Z","level":"INFO","prefix":"-","file":"http.go","line":"69","message":"500"}
{"time":"2022-09-09T09:00:03.914825907Z","level":"INFO","prefix":"-","file":"http.go","line":"69","message":"500"}
```

接下来，向返回 200 的端点连续发送 20 次请求试试看

```go
for i := 0; i < 20; i++ {
	resp, _ := client.Get(url)
	defer resp.Body.Close()
}
```

虽然看起来有些困难，但可以发现请求大约以每 4.5 秒 3 个请求的节奏发出。

```go
{"time":"2022-09-09T09:00:04.006523686Z","level":"INFO","prefix":"-","file":"http.go","line":"69","message":"200"}
{"time":"2022-09-09T09:00:04.103094697Z","level":"INFO","prefix":"-","file":"http.go","line":"69","message":"200"}
{"time":"2022-09-09T09:00:04.189073231Z","level":"INFO","prefix":"-","file":"http.go","line":"69","message":"200"}
{"time":"2022-09-09T09:00:04.552413101Z","level":"INFO","prefix":"-","file":"http.go","line":"69","message":"200"}
{"time":"2022-09-09T09:00:04.647212881Z","level":"INFO","prefix":"-","file":"http.go","line":"69","message":"200"}
{"time":"2022-09-09T09:00:04.727567042Z","level":"INFO","prefix":"-","file":"http.go","line":"69","message":"200"}
{"time":"2022-09-09T09:00:09.051296264Z","level":"INFO","prefix":"-","file":"http.go","line":"69","message":"200"}
{"time":"2022-09-09T09:00:09.149187824Z","level":"INFO","prefix":"-","file":"http.go","line":"69","message":"200"}
{"time":"2022-09-09T09:00:09.239032885Z","level":"INFO","prefix":"-","file":"http.go","line":"69","message":"200"}
{"time":"2022-09-09T09:00:13.549064137Z","level":"INFO","prefix":"-","file":"http.go","line":"69","message":"200"}
{"time":"2022-09-09T09:00:13.636816718Z","level":"INFO","prefix":"-","file":"http.go","line":"69","message":"200"}
{"time":"2022-09-09T09:00:13.724980151Z","level":"INFO","prefix":"-","file":"http.go","line":"69","message":"200"}
{"time":"2022-09-09T09:00:18.054925814Z","level":"INFO","prefix":"-","file":"http.go","line":"69","message":"200"}
{"time":"2022-09-09T09:00:18.15239561Z","level":"INFO","prefix":"-","file":"http.go","line":"69","message":"200"}
{"time":"2022-09-09T09:00:18.231450035Z","level":"INFO","prefix":"-","file":"http.go","line":"69","message":"200"}
{"time":"2022-09-09T09:00:22.566128516Z","level":"INFO","prefix":"-","file":"http.go","line":"69","message":"200"}
{"time":"2022-09-09T09:00:22.663002133Z","level":"INFO","prefix":"-","file":"http.go","line":"69","message":"200"}
{"time":"2022-09-09T09:00:22.750378144Z","level":"INFO","prefix":"-","file":"http.go","line":"69","message":"200"}
{"time":"2022-09-09T09:00:27.06199479Z","level":"INFO","prefix":"-","file":"http.go","line":"69","message":"200"}
{"time":"2022-09-09T09:00:27.156784826Z","level":"INFO","prefix":"-","file":"http.go","line":"69","message":"200"}
```

## 总结

本次我们通过扩展 Go 中的 http.RoundTripper 接口，

实现了 HTTP 请求的速率控制和重试功能。

在调用外部 API 时经常会遇到「每秒最多调用 N 次」这样的使用限制，希望这个实现能在这种场景下发挥作用。

## 参考

本文翻译于 [Goのhttp.RoundTripperでレート制御とリトライの機能を追加する方法](https://zenn.dev/fujisawa33/articles/aef6d266aa751f)

## 读后感

以"调用外部 API" 为例，如果并发调用频繁，会导致有许多阻塞，且顺序会被打乱，以上现有的代码适合单线程的场景，将上级调用也阻塞等待。

有个非常适合 `http.RoundTripper` 的用例，是 Digest 摘要鉴权，首次请求遇到 401，则带上鉴权信息第二次请求。

上面提到的是请求频率限流，还有 **带宽/流量限速** ，可以通过包装 `io.Reader` 限制每秒读取字节数量，定义 LimieRead 结构体，替代 `req.Body`。