---
title: singleflight
description: 
date: 2020-01-22 15:00:00
slug: 
image: 
draft: false
categories:
    - Golang
tags:
    - Go
    - 源码
---



## 什么是 SingleFlight?

应对并发的利器! 常用场景有: 缓存穿透 

100 个并发，普通的加锁方式会导致队列执行。

而 SingleFlight 会**缓存一瞬间的并发请求函数返回值**。第 1 个访问的函数去执行，其余 99 个进入协程等待，当第一个函数执行结果出来，剩下 99 个直接返回该结果。最后删除 map 中缓存的结果。



## 如何使用 SingleFlight?

```bash
func TestSingleFlight(t *testing.T){
	var g singleflight.Group
	g.Do("key",func() (interface{}, error){
		 return "test",nil
	})
}
```



## 看看源码

[singleflight](https://github.com/golang/groupcache/blob/master/singleflight/singleflight.go)

```go
package singleflight

import "sync"


type call struct {
	wg  sync.WaitGroup  // 阻塞并发函数请求
	val interface{}			// 函数返回值
	err error						// 函数返回值
}

// 一类工作
type Group struct {
	mu sync.Mutex       
	m  map[string]*call // 延迟初始化,用于临时存储函数
}

// 判断 key 是否第一次调用
// 是则调用函数获取结果
// 不是, 则阻塞在 c.wg.Wait() 等待函数返回值
func (g *Group) Do(key string, fn func() (interface{}, error)) (interface{}, error) {
  
	g.mu.Lock()
  // 创建 map
	if g.m == nil {
		g.m = make(map[string]*call)
	}
  
  // 如果已经有这个函数了, 则进入并解锁, 让其它协程全部进入
  // 等待函数返回值，注意 map 的值是指针
	if c, ok := g.m[key]; ok {
		g.mu.Unlock()
    // 等待函数执行结果
		c.wg.Wait()
		return c.val, c.err
	}
  
  // 初始化 call,写入 map 后解锁
	c := new(call)
	c.wg.Add(1)
	g.m[key] = c
	g.mu.Unlock()

  // 执行函数
	c.val, c.err = fn()
  // 已经获取结果, 后进来的协程都可以返回了
	c.wg.Done()
	
  // group 仅仅是执行函数时的临时存储空间
  // 操作结束后, 删除内容
	g.mu.Lock()
	delete(g.m, key)
	g.mu.Unlock()
	
	return c.val, c.err
}
```

