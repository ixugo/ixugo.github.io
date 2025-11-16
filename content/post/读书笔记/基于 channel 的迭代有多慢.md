---
title: 基于 channel 的迭代有多慢?
date: 2025-10-16
slug: 
image: 
draft: true
categories:
    - 翻译
tags:
    - Go
    - 性能 
---



```go
type RowIter interface {
	Next(ctx *Context) (Row, error)
	Close() error
}
```



## 参考

https://www.dolthub.com/blog/2025-10-10-how-slow-is-channel-iteration/
