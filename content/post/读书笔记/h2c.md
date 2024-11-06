---
title: Go H2C 
description: 
date: 2024-10-25
slug: 
image: 
draft: false
categories:
    - HTTP
tags:
    - Golang

---



## HTTP/1.1

启动一个 HTTP 服务示例。

```go
	m := http.NewServeMux()
	m.HandleFunc("/proto", func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte(r.Proto))
	})
	go http.ListenAndServe(":8080", m)
```

## H2C

h2c 是未加密的 http/2 协议，启动一个 h2c 服务示例。

```go
	m := http.NewServeMux()
	m.HandleFunc("/proto", func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte(r.Proto))
	})
	h := h2c.NewHandler(m, &http2.Server{IdleTimeout: time.Minute})
	go http.ListenAndServe(":8080", h)
```

**客户端**

```go
	cli := &http.Client{
		Timeout: 10 * time.Second,
		Transport: &http2.Transport{
			AllowHTTP: true,
			DialTLSContext: func(ctx context.Context, network, addr string, cfg *tls.Config) (net.Conn, error) {
				var dialer net.Dialer
				return dialer.DialContext(ctx, network, addr)
			},
		},
	}

	{
		resp, err := cli.Get("http://localhost:8080/proto")
		if err != nil {
			t.Fatal(err)
		}
		defer resp.Body.Close()
		data, err := io.ReadAll(resp.Body)
		if err != nil {
			t.Fatal(err)
		}
		fmt.Println("h2c", string(data))
	}
```

h2c 客户端请求 h2c 服务端，可以从下面截图看出协议是 HTTP/2.0。

h1 客户端请求 h2c 服务端，协议为 HTTP/1.1。

![image-20241025170723671](http://img.golang.space/img-1729847243837.png)

那如果 h2c 客户端请求 h1 服务端呢? 将会收获以下错误。

` Get "http://localhost:8080/proto": read tcp [::1]:61776->[::1]:8080: read: connection reset by peer`

我们可以自己实现 `RoundTrip` 接口，当 h2c 连接不上时，降级到 h1 。

```go

// CustomTransport 实现 HTTP/2 回退到 HTTP/1.1 的逻辑
type CustomTransport struct {
	h2cTransport *http2.Transport
	h1Transport  *http.Transport
}

func NewCustomTransport() *CustomTransport {
	return &CustomTransport{
		h2cTransport: &http2.Transport{
			AllowHTTP: true,
			DialTLSContext: func(ctx context.Context, network, addr string, _ *tls.Config) (net.Conn, error) {
				var dialer net.Dialer
				return dialer.DialContext(ctx, network, addr)
			},
			IdleConnTimeout: time.Minute,
		},
		h1Transport: &http.Transport{
			IdleConnTimeout: time.Minute,
		},
	}
}

func (f *CustomTransport) RoundTrip(req *http.Request) (*http.Response, error) {
	// 使用 HTTP/2 Transport 作为默认传输
	resp, err := f.h2cTransport.RoundTrip(req)
	if err != nil {
		// 如果 HTTP/2 失败，回退到 HTTP/1.1 连接
		return f.h1Transport.RoundTrip(req)
	}
	return resp, nil
}
```

再尝试一次试试

```go
	cli := &http.Client{
		Timeout: 10 * time.Second,
    Transport: NewCustomTransport(),
	}

	{
		resp, err := cli.Get("http://localhost:8080/proto")
		if err != nil {
			t.Fatal(err)
		}
		defer resp.Body.Close()
		data, err := io.ReadAll(resp.Body)
		if err != nil {
			t.Fatal(err)
		}
		fmt.Println("h2c", string(data))
	}
```

