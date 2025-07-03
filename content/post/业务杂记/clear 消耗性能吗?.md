---
title: Golang clear 很消耗性能吗?
description: 此函数用于清除 map 和 slice。对于 map 会删除所有键值对，从而生成一个空 map，对于 slice，会将长度以内全部设置为对应元素类型的零值。
date: 2025-05-29
slug: 
image: 
draft: false
categories:
    - Golang
tags:
    - Go
---

# Golang clear 很消耗性能吗?

`clear` 内置函数在 Go 1.21 版本中新增。

此函数用于清除 map 和 slice。对于 map 会删除所有键值对，从而生成一个空 map，对于 slice，会将长度以内全部设置为对应元素类型的零值。

那么 clear 消耗性能吗?

让我看图写文

![image-20250529121017989](http://img.golang.space/img-1748491818425.png)

`clear(make([]byte,256*1024))` 时，runtime 调用了 `memclrNoHeapPointers`

![image-20250529121340006](http://img.golang.space/img-1748492020296.png)

![image-20250529121832362](http://img.golang.space/img-1748492312648.png)

![image-20250529121552634](http://img.golang.space/img-1748492152964.png)

`loop_zva` 是这段 ARM64 汇编代码中的一个关键循环，用于**高效清零大块内存**，利用了 ARM64 的 **`DC ZVA`（Data Cache Zero by VA）** 指令。它的作用是**通过硬件加速的方式，快速清零缓存行（cache line）大小的内存块**，比普通的 `STP`（存储零值）指令更快。

 明明硬件加速删除，怎么还需要 1.24s 呢? `DC ZVA` 并不是简单的“瞬间清零内存”，它的实际行为包括：

- **缓存行操作**：
  - `DC ZVA` 会清零**整个缓存行**（通常 64 字节），但需要先加载缓存行到 CPU 缓存（如果未加载），再清零并写回内存。
  - 如果目标内存尚未缓存，可能需要从主存加载，这会增加延迟。
- **内存访问模式的影响**：
  - 如果内存区域是**非连续访问**（例如跨多个缓存行），或者内存带宽受限，`DC ZVA` 的效率会下降。
  - 对于大块内存，`DC ZVA` 可能需要多次操作，每次操作都有固定开销。

### 不用 clear 呢?

```go
for i := range buf {
		buf[i] = 0
}
```

![image-20250529122938117](http://img.golang.space/img-1748492978443.png)

更慢了耶!! range 读取的副本，需要 copy 并加载到 cpu。

## 总结

在性能上要更高要求的地方，对于大内存块，不执行清零操作，取指定长度的子切片直接覆盖使用即可。

以上内容来源于开源项目 `https://github.com/ixugo/bytepool`

这是带引用的计数内存池，基于 sync.Pool 实现，适用于多协程共享同一块内存，不知道何时放回内存池场景。(内存复制到各个协程会更安全，但共享会更高性能，建议选择前者，现在服务器基本内存管饱)

+ 自动引用计数
+ 分层内存池
+ 零拷贝设计
+ 并发安全
+ 内置统计数据
+ 高性能



