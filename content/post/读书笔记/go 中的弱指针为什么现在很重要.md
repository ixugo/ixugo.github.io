---
title: Go 中的弱指针:为什么他们现在很重要?
description: 
date: 2024-12-01
slug: 
image: 
draft: false
categories:
    - Go
tags:
    - 读书笔记
---



## 什么是弱指针呢?

弱指针基本上是一种引用一块内存而不锁定它的方法，因此如果没有其他人主动持有它，垃圾收集器可以清理它。

> *为什么还要为弱指针烦恼呢？ Go 有吗？*

嗯，是的，Go 确实有弱指针的概念。它是弱包的一部分，与 Go 运行时紧密相连。有趣的是，它曾经更多地是一个内部工具，但最近有人通过这个[提案](https://github.com/golang/go/issues/67552)推动将其公开。

很酷，对吧？

弱指针的关键是它们是安全的。如果它们指向的内存被清理，弱指针会自动变为`nil`因此不存在意外指向已释放内存的风险。当您确实需要保留该内存时，可以将弱指针转换为强指针。这个强指针告诉垃圾收集器，“嘿，当我使用它时，请把它放开。”

> *等等，它就自动变成 nil 了？这听起来……有风险*

是的，弱指针肯定会变成`nil`有时在你意想不到的时刻。

它们比常规指针更难使用。在任何时候，如果弱指针指向的内存被清理，它就可以变成`nil` 。当没有强指针持有该内存时，就会发生这种情况。因此，始终检查刚刚从弱指针转换而来的强指针是否为`nil`非常重要。

现在，关于清理何时发生——它不是立即发生的。即使没有人引用内存，清理时间也完全取决于垃圾收集器。

> 现在，展示一些代码。

在撰写本文时，弱包尚未正式发布。预计将在 Go 1.24 中落地。但我们可以偷看一下源代码并尝试一下。该软件包为您提供了两个主要的 API：

+ `weak.Make` ：从强指针创建弱指针。
+ `weak.Pointer[T].Strong` ：将弱指针转换回强指针。

```go
type T struct {
  a int
  b int
}

func main() {
  a := new(string)
  println("original:", a)

  // make a weak pointer
  weakA := weak.Make(a)

  runtime.GC()

  // use weakA
  strongA := weakA.Strong()
  println("strong:", strongA, a)

  runtime.GC()

  // use weakA again
  strongA = weakA.Strong()
  println("strong:", strongA)
}

// Output:
// original: 0x1400010c670
// strong: 0x1400010c670 0x1400010c670
// strong: 0x0
```

这是代码中发生的事情：

1. 在第一次垃圾回收（ `runtime.GC()` ）之后，弱指针`weakA`仍然指向内存，因为我们仍在使用变量`a` `println("strong:", strongA, a)` 线。由于内存正在使用中，因此还无法清理。
2. 但是当第二次垃圾收集运行时，强引用（ `a` ）不再使用。这意味着垃圾收集器可以安全地清理内存，让`weakA.Strong()`返回`nil` 。

现在，如果您尝试使用`string`指针以外的其他内容（例如`*int` 、 `*bool`或其他类型）来尝试此代码，您可能会注意到不同的行为，最后一个`strong`输出可能不是`nil` 。

这与 Go 如何处理`int` 、 `bool` 、 `float32` 、 `float64`等“微小对象”有关。这些类型被分配为微小对象，即使它们在技术上未使用，垃圾收集器也可能不会立即清理它们在垃圾收集期间。要了解更多信息，您可以更深入地研究[Go Runtime Finalizer 和 Keep Alive](https://victoriametrics.com/blog/go-runtime-finalizer-keepalive)中的微小对象分配。

弱指针对于特定场景下的内存管理非常实用。

+ 例如，它们非常适合规范化映射 - 您只想保留一份数据的一份副本的情况。这与我们之前[关于字符串驻留的讨论](https://victoriametrics.com/blog/go-unique-package-intern-string)有关。
+ 另一种情况是，当您希望某些内存的寿命与另一个对象的寿命相匹配时，类似于 JavaScript 的 WeakMap 的工作方式。 WeakMap 允许对象在不再使用时自动清理。

因此，弱指针的主要好处是它们可以让你告诉垃圾收集器， *“嘿，如果没有人使用这个资源，就可以删除它——我以后可以随时重新创建它。”*这对于占用大量内存但不需要保留的对象非常有效，除非它们正在被积极使用。

**弱指针如何工作？**

有趣的是，弱指针实际上并不直接指向它们引用的内存。相反，它们是包含“间接对象”的简单结构（使用泛型）。这个对象很小，只有 8 个字节，它指向实际的内存目标。

```go
type Pointer[T any] struct {
	u unsafe.Pointer
}
```

![弱指针通过间接引用内存](http://img.golang.space/img-1734485576251.png)

为什么要这样设计呢？

此设置使垃圾收集器可以高效地一次性清理指向特定对象的弱指针。当它决定应该释放内存时，收集器只需将间接对象中的指针设置为`nil` （或`0x0` ）。它不必单独更新每个弱指针。

![GC回收内存，更新弱指针链接](http://img.golang.space/img-1734485968905.png)

最重要的是，这个设计支持相等检查（ `==` ）。从同一原始指针创建的弱指针将被视为“相等”，即使它们指向的对象已被垃圾回收。

```go
func main() {
	a := new(string)

	// make a weak pointers
	weakA := weak.Make(a)
	weakA2 := weak.Make(a)

	println("Before GC - Equality check:", weakA == weakA2)

	runtime.GC()

	// Test their equality
	println("After GC - Strong:", weakA.Strong(), weakA2.Strong())
	println("After GC - Equality check:", weakA == weakA2)
}

// Before GC - Equality check: true
// After GC - Strong: 0x0 0x0
// After GC - Equality check: true
```

这是可行的，因为来自同一原始对象的弱指针共享相同的间接对象。当您调用`weak.Make`时，如果一个对象已经有一个与之关联的弱指针，则现有的间接对象将被重用，而不是创建一个新的。

> 等等，使用 8 个字节作为间接对象不是有点浪费吗？

看起来好像是这样，但作者会说，这并不是什么大问题。弱指针通常用于总体目标是节省内存的情况。例如，在规范化映射中（通过仅保留每个唯一数据的一份副本来消除重复项），您已经通过避免冗余节省了大量内存。

也就是说，如果您存在大量唯一项和很少重复项的情况下使用弱指针，则最终可能会使用比预期更多的内存。因此，在决定弱指针是否是适合该工作的工具时，考虑具体用例非常重要。



## 参考

本文翻译于 [Weak Pointers in Go: Why They Matter Now](https://victoriametrics.com/blog/go-weak-pointer/)
