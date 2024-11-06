---
title: HTTP Cache 
description: 
date: 2024-08-01
slug: 
image: 
draft: false
categories:
    - GoWeb
tags:
    - Go
    - HTTP
---

## Etag

```bash
# 客户端请求
GET /api/data
If-None-Match: "abc123"    # 之前服务器返回的 ETag

# 服务器响应（如果数据未变）
HTTP/1.1 304 Not Modified  # 不会返回响应体
ETag: "abc123"            # 通常会重新确认 ETag
```

ETag 是 HTTP 缓存机制的重要组成部分,可以有效减少不必要的数据传输。

服务端携带响应头 ETag 时，下次浏览器请求时间将会携带此 ETag 值，可通过 `If-None-Match` 获取。服务识别到相同的 ETag 可直接返回 304 状态码。

304 状态码响应很快，不需要返回 Body，该状态码表示 "Not Modified"，具体的含义为:

1. 请求的资源未修改
2. 客户端可以继续使用本地缓存
3. 响应体为空，节省带宽

通过上面的理论，以下是 Go/Gin 的 ETag 中间件实现，主要内容简略概括:

1. 自定义 `EtagWriter`，捕获响应内容
2. 使用 SHA1 算法生成基于内容的 ETag
3. 处理 If-None-Match 请求头
4. 返回 304 Not Modified（如果内容未变）
5. 返回 200 和 body (如果内容发生变化)

**工作流程**

```bash
浏览器 ---GET---> 服务器
       带 ETag

服务器 -----> 比对数据
      -----> 发现未修改

服务器 ---304---> 浏览器
       空响应体

浏览器 -----> 使用本地缓存
```

**注意**

1. 此实现适用于内容中小响应，中大型静态文件请参考下一章节的 Cache-Control
2. ETag 的生成可以根据需求修改，可以基于时间或版本号
3. 根据 RFC 9110（HTTP/1.1 规范），ETag 的值是一个“quoted-string”，即带引号的字符串。如果 `ETag` 值前有 `W/` 前缀，则表示这是一个**弱标签**，表明资源内容大致相同，但不是完全相同。强 `ETag` 则表示资源内容完全相同。
   1. 强标签：`ETag: "12345abc"`
   2. 弱标签：`ETag: W/"12345abc"`
4. SHA1 (160位) 比 MD5 (128位) 有更低的碰撞概率，SHA1 虽然比 MD5 慢一点，但差异极小，对 ETag 生成这种低频操作影响可以忽略。

```go

type EtagWriter struct {
	gin.ResponseWriter
	body bytes.Buffer
}

func (w *EtagWriter) Unwrap() http.ResponseWriter {
	return w.ResponseWriter
}

func (w *EtagWriter) Write(b []byte) (int, error) {
	return w.body.Write(b)
}


func EtagHandler() gin.HandlerFunc {
	return func(ctx *gin.Context) {
		bw := EtagWriter{
			ResponseWriter: ctx.Writer,
		}
		ctx.Writer = &bw
		ctx.Next()

		hash := sha1.New()
		buf := bw.body.Bytes()
		hash.Write(buf)
		etag := `"` + hex.EncodeToString(hash.Sum(nil)) + `"`
		if match := ctx.GetHeader("If-None-Match"); match != "" && match == etag {
			ctx.Writer.WriteHeader(http.StatusNotModified)
			return
		}
		ctx.Header("ETag", etag)
		if _, err := bw.ResponseWriter.Write(buf); err != nil {
			slog.Error("write err", "err", err)
		}
	}
}
```



## Cache-Control

Cache-Control 和 ETag 是两种不同的缓存机制，它们的作用和场景不同：

```http
Cache-Control: max-age=3600    # 缓存1小时
Cache-Control: no-cache        # 每次都需要验证
Cache-Control: no-store        # 完全不缓存
Cache-Control: private         # 只允许浏览器缓存
Cache-Control: public          # 允许中间代理缓存
```

其特点是:

+ 基于时间的缓存策略
+ 完全不请求服务器（如果缓存未过期）
+ 适合静态资源（图片、CSS、JS等）
+ 配置简单，性能最好

下方是 Go/Gin 实现的缓存中间件，一般静态资源的获取(HTTP/CSS/JS 等)采用 GET 请求，根据传入的 millisecond 让浏览器缓存一定时间。

```go
func CacheControlMaxAge(millisecond int) gin.HandlerFunc {
	age := strconv.Itoa(millisecond)
	return func(ctx *gin.Context) {
		if ctx.Request.Method == "GET" {
			ctx.Header("Cache-Control", "max-age="+age)
		}
		ctx.Next()
	}
}
```

**两者可组合使用**

```bash
Cache-Control: max-age=3600
ETag: "abc123"
```

+ 1小时内直接使用缓存
+ 超过1小时后用ETag验证
+ 既节省资源又保证准确性

## 建议

建议对于不会变化的静态资源

```http
# 长期缓存
Cache-Control: max-age=31536000  # 1年
```

对于 API 数据

```http
# 短期缓存+ETag验证
Cache-Control: max-age=60  # 1分钟
ETag: "data-version"
```

对于时刻变化的内容

```http
# 只用ETag
Cache-Control: no-cache
ETag: "content-hash"
```

## Goweb 中最佳实践

此实践场景为 Go 提供静态 web 资源访问服务，以此类推，使用 nginx 等其它方式部署 web 静态资源，也可以使用以上的缓存控制方案。

1. 通过前缀将静态资源分组
2. 对于该分组，使用 gzip 压缩，Cache-Control 缓存到客户端
3. 代码示例里面是通过 embed 内嵌静态资源的，也可以读取磁盘文件
4. 访问根路由时，跳转到静态资源首页

```go
const publicPrefix = "/cloud"
admin := router.Group(publicPrefix, gzip.Gzip(gzip.DefaultCompression), web.CacheControlMaxAge(7200))
admin.StaticFS("/", static.FileSystem())

g.GET("/", func(ctx *gin.Context) {
		ctx.Redirect(http.StatusPermanentRedirect, publicPrefix)
})
```





