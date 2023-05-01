---
title: HTTP 读写超时
description: 单独控制每个 Handler 的读写超时时间
date: 2023-05-01
slug: 
image: 
draft: false
categories:
    - Golang
tags:
    - Go

---

# HTTP 读写超时

```go
http.Server{
		Addr:         defaultAddr,
		Handler:      handler,
		ReadTimeout:  defaultReadTimeout,
		WriteTimeout: defaultWriteTimeout,
}
```

如上面代码所示，可以使用 http.Server 定义读写超时时间，通常在 5~30 秒之间，这有助于防止应用程序无限期地阻塞在HTTP响应的读取或写入操作上，从而导致应用程序失去响应并影响整体性能。

ReadTimeout 是从 accept 到 request.Body 被完全读取的时间，如果不读 body 则时间截止到读完 header 为止。

WriteTimeout 是从 request header 的读取结束开始，到 response write 结束为止。

使用以上定义的代码，在上传文件功能中，如果文件的大小不确定，大文件读取用时超过预定义的 ReadTimeout，则会出现超时错误，类似于 `read tcp [::1]:1133->[::1]:57471: i/o timeout`。

在 Go 1.20 中新增加了 `http.ResponseController` 类型，使用该包可以单独控制每个 Handler 的读写超时时间。

参考 Github issue [ net/http: ResponseController to manipulate per-request timeouts (and other behaviors) #54136](https://github.com/centrifugal/centrifuge/pull/292)。

它有以下优点:

1. 根据每个请求设置读写超时时间。
2. http.Flusher 和 http.Hijacker 使用更轻松。
3. 使创建和使用自定义的 http.ResponseWrite 实现变得更容易和更安全。

### 使用

```go
func ServeHTTPx(w http.ResponseWriter, req *http.Request) {
  rc := http.NewResponseController(w)
	_ = rc.SetReadDeadline(time.Now().Add(30 * time.Second))
	_ = rc.SetWriteDeadline(time.Now().Add(30 * time.Second))
}
```

