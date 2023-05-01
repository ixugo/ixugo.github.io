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

## HTTP SSE

SSE 指的是 Server-sent events，使用服务器发送事件。

在 Go 服务端设置响应头信息。

```go
w.Header().Set("Content-Type", "text/event-stream")
w.Header().Set("Cache-Control", "no-cache")
w.Header().Set("Connection", "keep-alive")
```

客户端代码类似这样

```js
const evtSource = new EventSource("/ssedemo");
// 监听事件
evtSource.onmessage = function(event) {
  const newElement = document.createElement("li");
  const eventList = document.getElementById("list");
  newElement.innerHTML = "message: " + event.data;
  eventList.appendChild(newElement);
}
```

## HTTP 流式传输

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

**网页效果展示**

![iShot_2023-02-15_17.11.32](http://img.golang.space/img-1676452325334.gif)

## 服务端

```go
package main

import (
	"encoding/json"
	"fmt"
	"io"
	"math/rand"
	"net/http"
	"time"
)

// 流式传输
func main() {
	http.HandleFunc("/aaa", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(200)
		w.Header().Set("Transfer-Encoding", "chunked")
		w.Header().Set("Content-Type", "text/plain")

		ch := make(chan Resp, 10)
		defer close(ch)
		go func() {
			// 此处 defer... recover()...
			tick := time.NewTicker(40 * time.Millisecond)
			defer tick.Stop()
			var zeroValue Resp
			var last *Resp
			fn := func(v Resp, w io.Writer) error {
				b, _ := json.Marshal(v)
				if _, err := w.Write(b); err != nil {
					return err
				}
				w.(http.Flusher).Flush()
				return nil
			}

			for {
				select {
				case <-tick.C:
					if last != nil {
						_ = fn(*last, w)
						last = nil
					}
				case v := <-ch:
					if v != zeroValue {
						last = &v
						continue
					}
					if last != nil {
						_ = fn(*last, w)
					}
					return
				}
			}
		}()

		var resp Resp
		resp.All = 300
		ok := rand.Intn(10) == 5
		for i := 0; i <= resp.All; i++ {
			time.Sleep(10 * time.Millisecond)
			fmt.Println(i)
			if ok {
				resp.Err = fmt.Errorf("err").Error()
			}
			resp.CUR = i
			ch <- resp
			if ok {
				break
			}
		}
		time.Sleep(30 * time.Second)
	})
	http.Handle("/", http.FileServer(http.Dir("./"))) // 展示网页
	_ = http.ListenAndServe(":8888", nil)
}

type Resp struct {
	All int    `json:"all"`
	CUR int    `json:"cur"`
	Err string `json:"err"`
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

[使用服务器发送事件](https://developer.mozilla.org/zh-CN/docs/Web/API/Server-sent_events/Using_server-sent_events)

