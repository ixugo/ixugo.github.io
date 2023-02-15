---
title: HTTP 流式传输
description: 
date: 2023-02-15 
slug: 
image: 
draft: false
categories:
    - HTTP
tags:
    - Go
    - HTTP
---

# HTTP 流式传输

`Transfer-Encoding` 出现在 HTTP Response Header 中。

该消息指明将消息体传递给请求端的编码形式。

```bash
# 语法
Transfer-Encoding: chunked
Transfer-Encoding: compress
Transfer-Encoding: deflate
Transfer-Encoding: gzip
Transfer-Encoding: identity

// 可以多个值，以逗号隔开
Transfer-Encoding: gzip, chunked
```

`chunked` 指数据以一系列分块的形式进行发送，`Content-Length` 在这种情况下不被发送，在每一个分块的开头需要添加当前分块的长度，以十六进制的形式表示，后面紧跟着 '`\r\n`'。

分块的应用场景是要传输大量的数据，但是在请求没有被处理完之前响应的长度是无法获得的。

接下来演示一个 demo，假设客户端有一个进度条，向用户告知服务端处理进度。

## 服务端

```go
func main() {
	http.HandleFunc("/aaa", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(200)
		w.Header().Set("Transfer-Encoding", "chunked")
		w.Header().Set("Content-Type", "text/plain")

		var resp struct {
			Total   int `json:"total"`
			Current int `json:"current"`
		}

		flusher := w.(http.Flusher)
		resp.Total = 30
		for i := 0; i <= resp.Total; i++ {
			resp.Current = i
			b, _ := json.Marshal(resp)
			_, _ = w.Write(b)
			flusher.Flush()
			time.Sleep(300 * time.Millisecond)
		}
	})
	http.Handle("/", http.FileServer(http.Dir("./"))) // 展示网页
	_ = http.ListenAndServe(":8888", nil)
}
```



## 网页端

```html
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta http-equiv="X-UA-Compatible" content="IE=edge" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>test</title>
  </head>
  <body>
    <p>response</p>
    <h1 id="output">...</h1>
  </body>

  <script>
    // 参考: https://web.dev/i18n/zh/fetch-upload-streaming/
    const { readable, writable } = new TransformStream();
    document.addEventListener("DOMContentLoaded", async function () {
      const response = await fetch("/aaa");
      const reader = response.body.getReader();
      while (true) {
        const { value, done } = await reader.read();
        if (done) break;
        const decoder = new TextDecoder("utf-8");
        const str = decoder.decode(value);
        document.getElementById("output").innerHTML = str;
      }
    });
  </script>
</html>

```



## 参考

[使用 fetch API 流式处理请求](https://web.dev/i18n/zh/fetch-upload-streaming/)

[Transfer-Encoding](https://developer.mozilla.org/zh-CN/docs/Web/HTTP/Headers/Transfer-Encoding)

