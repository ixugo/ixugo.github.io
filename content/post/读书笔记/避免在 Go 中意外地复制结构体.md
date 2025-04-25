---
title: 避免在 Go 中意外地复制结构体
description: 
date: 2025-04-26
slug: 
image: 
draft: false
categories:
    - 翻译
tags:
    - 读书笔记
    - GO
---

默认情况下，Go 在传递值时会复制它们。但有时这可能是不希望的。例如，如果你不小心复制了一个互斥锁，并且多个 goroutine 在不同的锁实例上工作，它们将无法正确同步。在这种情况下，传递锁的指针可以避免复制并按预期工作。

以这个例子来说：通过值传递 `sync.WaitGroup` 会以微妙的方式破坏程序：

```go
func f(wg sync.WaitGroup) {
    // ... do something with the waitgroup
}

func main() {
    var wg sync.WaitGroup
    f(wg) // oops! wg is getting copied here!
}
```

`sync.WaitGroup` 让你可以等待多个 goroutine 完成一些工作。在幕后，它是一个包含 `Add` 、 `Done` 和 `Wait` 等方法的结构体，用于同步并发运行的 goroutine。

这段代码可以编译，但由于我们在 `f` 函数中复制了锁而不是引用它，因此会导致错误行为。

幸运的是， `go vet` 会捕获这个问题。如果你在代码上运行 vet，你会得到一个类似于这样的警告：

```bash
f passes lock by value: sync.WaitGroup contains sync.noCopy
call of f copies lock value: sync.WaitGroup contains sync.noCopy
```

这意味着当我们应该传递一个引用时，我们却通过值传递了 `wg` 。这是修复方法：

```go
func f(wg *sync.WaitGroup) { // pass by reference
    // ... do something with the waitgroup
}

func main() {
    var wg sync.WaitGroup
    f(&wg) // pass a pointer to wg
}
```

由于这种不正确的复制不会抛出编译错误，如果你跳过了 `go vet` ，你可能永远也发现不了它。这也是始终审查代码的另一个原因。

我很好奇 Go 工具链是如何强制执行这一点的。线索就在 vet 警告中：

所以 `sync.noCopy` 结构体在 `sync.WaitGroup` 中做了些什么来提醒 `go vet` 当你通过值传递它时。

查看 `sync.WaitGroup` [1](https://rednafi.com/go/prevent_struct_copies/#fn:1) 的实现，你会发现：

```go
type WaitGroup struct {
    noCopy noCopy

    state atomic.Uint64
    sema  uint32
}
```

然后我追踪了 `noCopy` 在 `sync/cond.go` [2](https://rednafi.com/go/prevent_struct_copies/#fn:2) 中的定义：

```go
// noCopy may be added to structs which must not be copied
// after the first use.

// Note that it must not be embedded, due to the Lock and Unlock methods.
type noCopy struct{}

// Lock is a no-op used by -copylocks checker from `go vet`.
func (*noCopy) Lock()   {}
func (*noCopy) Unlock() {}
```

只需要在 `noCopy` 上定义那些空的 `Lock` 和 `Unlock` 方法。这实现了 `Locker` [3](https://rednafi.com/go/prevent_struct_copies/#fn:3) 接口。然后如果你将这个结构体嵌入到另一个结构体中， `go vet` 将会标记你在尝试复制外部结构体时出现的情况。

另外，请注意注释：不要嵌入 `noCopy` 。显式包含它。嵌入会使 `Lock` 和 `Unlock` 在外部结构体中可见，这可能不是你想要的。

Go 工具链通过 `-copylocks` 检查器来强制执行这一点。它是 `go vet` 的一部分。你可以单独使用 `go vet -copylocks ./...` 来调用它。它会查找任何包含 `Lock` 和 `Unlock` 方法的嵌套结构体的值拷贝。这些方法的具体功能并不重要，只要有这些方法就足够了。

当 vet 运行时，它会遍历抽象语法树（AST），并在赋值、函数调用、返回值、结构体字面量、范围循环、通道发送等任何值被拷贝的地方应用检查器。如果它发现你拷贝了一个包含 `noCopy` 的结构体，它会发出警告。你可以在这里查看检查的实现 [4](https://rednafi.com/go/prevent_struct_copies/#fn:4) 。

有趣的是，如果你将 `noCopy` 定义为任何非结构体类型并实现 `Locker` 接口，vet 会忽略它。我在 Go 1.24 中进行了测试：

```go
type noCopy int     // this is valid but vet doesn't get triggered
func (*noCopy) Lock()   {}
func (*noCopy) Unlock() {}
```

这不会触发 vet。只有当 `noCopy` 是结构体时才会生效。原因是 vet 在检查何时触发警告时采取了一条捷径 [5](https://rednafi.com/go/prevent_struct_copies/#fn:5) 。目前，它明确查找满足 `Locker` 接口的结构体，并忽略任何其他类型，即使它们实现了该接口。

你也会在 sync 包的其他部分看到这一点。 `sync.Mutex` 使用了同样的技巧：

```go
type Mutex struct {
    _ noCopy

    mu isync.Mutex
}
```

同样适用于 `sync.Once` :

```go
type Once struct {
    done   uint32
    m      Mutex
    noCopy noCopy
}
```

这是一个使用 `-copylocks` 避免复制我们自己的结构体的完整示例：

```go
type Svc struct{ _ noCopy }

type noCopy struct{}

func (*noCopy) Lock()   {}
func (*noCopy) Unlock() {}

// Use this
func main() {
    var svc Svc
    _ = svc // go vet will complain about this copy op
}
```

运行 `go vet` 得到：

```bash
assignment copies lock value to s: play.Svc contains play.noCopy
call of fmt.Println copies lock value: play.Svc contains play.noCopy
```

有人在 Reddit 上问我，是什么触发了 `copylock` 检查器在 `go vet` — 是结构体的字面名称 `noCopy` 还是它实现了 `Locker` 接口？

`noCopy` 这个名字不是特殊的。你可以想叫它什么就叫什么。只要它实现了 `Locker` 接口， `go vet` 会在周围结构体被复制时抱怨。参见这个 Go Playground 片段 [6](https://rednafi.com/go/prevent_struct_copies/#fn:6) 。

## 参考

本文翻译于 [Preventing accidental struct copies in Go](https://rednafi.com/go/prevent_struct_copies)
