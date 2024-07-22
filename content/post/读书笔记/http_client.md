---
title: 知道何时 Go 的 http.DefaultClient 断开
description: 
date: 2024-07-09
slug: 
image: 
draft: false
categories:
    - HTTP
tags:
    - 读书笔记
    - Golang
---

这些可能是您在尝试使用 Go 的 HTTP 客户端时看到的第一组代码片段。 

```go
resp, err := http.Get("http://example.com/")
...
resp, err := http.Post("http://example.com/upload", "image/jpeg", &buf)
...
```

类似的代码可能导致你的第一次生产中断。这是非常好的代码，当将以下内容引入其中时，事情开始变得复杂。

+ 当程序开始大量 HTTP 调用时。
+ 当程序对多个服务主机进行 HTTP 调用时。

其背后的原因是 `net/http` 包中声明的这个变量。

## 认识 DefaultClient

`DefaultClient` 的类型是 `*http.Client`，`http.Client` 是包含执行 HTTP 调用的所有方法结构。`DefaultClient` 是一个 HTTP 客户端，所有底层设置都指向默认值。

当您尝试调用这些包级 HTTP 方法（例如 `http.Get` 、 `http.Post` 、 `http.Do` 等）时，将使用 `DefaultClient` 变量。 `http.Client` 结构中的两个字段可能会将 `http.DefaultClient` 的“默认”和“共享”行为转化为潜在问题：

```go
type Client struct {
	Transport RoundTripper
	Timeout time.Duration
}
```

`Timeout` 的默认值为零，因此 `http.DefaultClient` 默认情况下不会超时，并且只要连接处于活动状态，就会尝试保留本地端口/套接字。如果请求太多怎么办？答案是发生了生产中断，你将耗尽端口，并且不会有可用的端口进行进一步的 HTTP 调用。

接下来是 `http.Client` 中的 `Transport` 字段。默认情况下，以下 `DefaultTransport` 将在 `DefaultClient` 中使用。

```go
var DefaultTransport RoundTripper = &Transport{
	Proxy: ProxyFromEnvironment,
	DialContext: defaultTransportDialContext(&net.Dialer{
		Timeout:   30 * time.Second,
		KeepAlive: 30 * time.Second,
	}),
	ForceAttemptHTTP2:     true,
	MaxIdleConns:          100,
	IdleConnTimeout:       90 * time.Second,
	TLSHandshakeTimeout:   10 * time.Second,
	ExpectContinueTimeout: 1 * time.Second,
}
```

（里面有很多东西，但是把你的注意力转向 `MaxIdleConns` ）

这是关于它的作用的文档：

```go
// MaxIdleConns controls the maximum number of idle (keep-alive)
// connections across all hosts. Zero means no limit.
MaxIdleConns int
```

由于 `DefaultClient` 是共享的，因此您最终可能会从中调用多个服务（主机名）。在这种情况下，默认客户端为给定主机集维护的 `MaxIdleConns` 可能存在不公平的分配。

## 一个小例子

让我们在这里举个栗子：

```go
type LoanAPIClient struct {}

func (l *LoanAPIClient) List() ([]Loan, error) {
	// ....
	err := http.Get("https://loan.api.example.com/v1/loans")
	// ....
}

type PaymentAPIClient struct {}

func (p *PaymentAPIClient) Pay(amount int) (error) {
	// ....
	err := http.Post("https://payment.api.example.com/v1/card", "application/json", &req)
	// ....
}
```

`LoanAPIClient` 和 `PaymentAPIClient` 都通过调用 `http.Get` 和 `http.Post` 来使用 `http.DefaultClient` 。假设我们的程序最初从 `LoanAPIClient` 进行 80 次调用，然后从 `PaymentAPIClient` 进行 200 次调用。默认情况下 `DefaultClient` 仅维护最大100个空闲连接。因此， `LoadAPIClient` 将占领这 100 个位置中的 80 个位置，而 `PaymentAPIClient` 将仅获得 20 个剩余位置。这意味着对于来自 `PaymentAPIClient` 的其余 60 个调用，需要打开和关闭一个新连接。这会对支付API服务器造成不必要的压力。这些 MaxIdleConns 的分配很快就会脱离你的掌控！ （相信我😅）

## 我们该如何解决这个问题？

增加 `MaxIdleConns` ？是的，您可以，但如果客户端仍然在 `LoanAPIClient` 和 `PaymentAPIClient` 之间共享，那么这也会在某种程度上失控。

我发现了 `MaxIdleConns` 的兄弟，那就是 `MaxIdleConnsPerHost` 。

这有助于为每个端点（主机名）维护可预测数量的空闲连接。

## 好吧，我会如何修复它?

如果您的程序正在调用多个 HTTP 服务，那么您很可能还想调整客户端的其他设置。因此，为这些服务提供单独的 `http.Client` 可能会有所帮助。这样我们就可以在将来需要时对它们进行微调。

```go
type LoanAPIClient struct {
	client *http.Client
}

type PaymentAPIClient struct {
	client *http.Client
}
```

## 别担心

结论是这样的：使用 `http.DefaultClient` 开始是可以的。但如果您认为您将拥有更多客户端并且会进行更多 API 调用，请避免这样做。

提醒：如果您正在编写具有 API 客户端的库，请为您的用户提供一个帮助：提供一种自定义用于进行 API 调用的 `http.Client` 的方法。这样，您的用户就可以完全控制他们在使用您的客户端时想要实现的目标。

HTTP 服务器内的 HTTP 客户端与另一个具有 HTTP 客户端的 HTTP 服务器进行通信，所有这些都由您编写。那将是你的提示。











## 参考

本文翻译于[Know when to break up with Go's http.DefaultClient](https://vishnubharathi.codes/blog/know-when-to-break-up-with-go-http-defaultclient/)