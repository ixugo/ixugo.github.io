---
title: 使用 X-Forwarded
description: 
date: 2025-09-26
slug: 
image: 
draft: false
categories:
    - HTTP
tags:
---



## 背景描述

想象有一个服务端，且称其为 a 服务，当请求 `/login` 的时候，会触发重定向到 `/home`。

即访问  `a.com/login` 时，页面重定向到 `a.com/home`。

现在给 a 服务增加一个 nginx 反向代理，nginx 下也有其它服务，当然可以通过域名的方式区分访问的是哪个服务器，但在这个场景下，咱们限定只能通过前缀区分服务。即访问 `nginx.proxy.com/a/login` ，会被代理到 `a.com/login`，现在发出请求，会发现浏览器重定向到了 `a.com/home`，这不是我想要的结果，前端不应该直接访问到 a 服务，理想的结果是 `nginx.proxy.com/a/home`。

一种简单的方案如下

```nginx
location /a/ {
    proxy_pass http://a.com/;
    # 把后端返回的 "Location: /xxx" 改成 "Location: /a/xxx"
    proxy_redirect / /a/;
}
```

这是重定向，如果返回的链接也需要加前缀呢?

## 解决方案

为了解决上面的问题，我们可以在 nginx 配置中定义一个 `X-Forwarded-Prefix`，例如

```nginx
location /a/ {
    proxy_pass http://a.com/;
    proxy_set_header X-Forwarded-Prefix /a;
}
```

考虑到外层可能还有多个反向代理的情况

采用逗号分隔，记住每一层代理的前缀，我觉得意义不大，应该只有最外层的有效，层层传递即可，没有对应的 header 则当前层就是最外层。

配置可以这样改

```nginx
location /a/ {
        proxy_pass http://a.com/;

        # 如果没有 X-Forwarded-Prefix，则设置
        if ($http_x_forwarded_prefix = "") {
            proxy_set_header X-Forwarded-Prefix /a;
        }
}
```

在业务层，可以通过以下方式获取

```go
func home(w http.Response,  req *http.Request) {
  prefix := req.Header.Get("X-Forwarded-Prefix")
  path := prefix + "/home"
  // 响应结果
}
```

相对路径时可以这样拼接，当使用绝对路径时，要使用上 `X-Forwarded-Proto` 和 `X-Forwarded-Host`，前者用于标识请求协议 http/https，后者用于标识请求地址。

最终的 nginx 设置如下:

```nginx
   # 仅在不存在时才设置前缀
map $http_x_forwarded_prefix $prefix_for_test {
    ""      /test;  # 这里根据实际 prefix 动态修改
    default $http_x_forwarded_prefix;
}
# 仅在不存在时才设置 X-Forwarded-Proto
map $http_x_forwarded_proto $proto_for_test {
    ""      $scheme;
    default $http_x_forwarded_proto;
}
# 仅在不存在时才设置 X-Forwarded-Host
map $http_x_forwarded_host $host_for_test {
    ""      $http_host;
    default $http_x_forwarded_host;
}

server{
  # 略
  location /a/ {
    proxy_pass http://a.com/;
    # 使用 map 变量设置头
    proxy_set_header X-Forwarded-Prefix $prefix_for_test;
    proxy_set_header X-Forwarded-Proto $proto_for_test;
    proxy_set_header X-Forwarded-Host $host_for_test;
    # 原始 Host
    proxy_set_header Host $host;
    # 调用者 IP
    proxy_set_header X-Real-IP $remote_addr;
    # 多层代理下，最终会变成 逗号分隔的链条，记录所有经过的代理 IP，通过解析第一个能获取到原始客户端 IP
    # Client 1.1.1.1 → ProxyA → ProxyB → ProxyC → Nginx → 后端
    # 1.1.1.1, ProxyA_IP, ProxyB_IP, ProxyC_IP, Nginx_IP
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

  }
}
```

上面的配置，假设 nginx 代理前缀是 `/test`，当访问 `http://localhost:8002/test/login` 时，业务层就可以通过 header 取到 `http`，`localhsot:8002`，`/test` 三个参数。

不需要多层代理，更简单的 nginx 写法:

```go
location /a/ {
  proxy_pass http://a.com/;

  proxy_set_header X-Forwarded-Prefix /a;
  proxy_set_header X-Forwarded-Proto $scheme;
  proxy_set_header X-Forwarded-Host $http_host;
  proxy_set_header Host $host;
  proxy_set_header X-Real-IP $remote_addr;
  proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
}
```



## 关于 X-Forwarded-Prefix 

我在网上查询到微软，spring 都在使用这种方式，我倾向于沿用这种方案。

与所有以 `X-` 开头的 header 一样， `X-Forwarded-Prefix` 并非“标准”，且不如 `X-Forwarded-Proto` 之类的 header 那么知名，但它被一些较大的产品/供应商使用。[ 微软的 YARP 文档](https://microsoft.github.io/reverse-proxy/articles/transforms.html#defaults)中有一个具体示例，其中指出：

> X-Forwarded-Prefix - Sets the request's original PathBase, if any, to the X-Forwarded-Prefix header.

Golang  的 gin 框架默认的重定向操作也使用这种方式。在 gin 默认的行为里，请求 `/foo/`，但仅存在 `/foo` 的路由，则客户端被重定向到 `/foo`，GET 请求返回 HTTP状态码 301，其它请求方法返回 307 。

以下代码取自`gin@v1.10.1 gin.go`

```go
func redirectTrailingSlash(c *Context) {
	req := c.Request
	p := req.URL.Path
	if prefix := path.Clean(c.Request.Header.Get("X-Forwarded-Prefix")); prefix != "." {
		prefix = regSafePrefix.ReplaceAllString(prefix, "")
		prefix = regRemoveRepeatedChar.ReplaceAllString(prefix, "/")

		p = prefix + "/" + req.URL.Path
	}
	req.URL.Path = p + "/"
	if length := len(p); length > 1 && p[length-1] == '/' {
		req.URL.Path = p[:length-1]
	}
	redirectRequest(c)
}
```

## 参考

[spring issues](https://github.com/spring-projects/spring-framework/issues/31241)

[what-is-the-correct-value-for-x-forward-prefix-header](https://stackoverflow.com/questions/79619512/what-is-the-correct-value-for-x-forward-prefix-header)

[using-the-x-forwarded-prefix-header-to-prefix-your-hateoas-links](https://josef.codes/using-the-x-forwarded-prefix-header-to-prefix-your-hateoas-links/)

[X-Forwarded-Proto](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/X-Forwarded-Proto)