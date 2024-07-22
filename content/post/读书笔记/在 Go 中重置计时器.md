---
title: 在 Go 中重置计时器
description: 
date: 2024-07-18
slug: 
image: 
draft: false
categories:
    - Golang
tags:
    - 读书笔记
    - Golang
---

如果你在 Go 1.22 或更早版本中使用 `Timer.Reset()` ，你可能会做错。甚至《100 Go Mistakes》一书（关于 Go 的细微差别通常是正确的）也犯了错误。

让我们看看问题可能是什么以及如何解决它。

## time.After

在 Go ≤1.22 的循环中使用 `time.After()` 可能会导致大量内存使用。考虑这个例子：

```go
// go 1.22
type token struct{}

func consumer(ctx context.Context, in <-chan token) {
	const timeout = time.Hour
	for {
		select {
		case <-in:
			// do stuff
		case <-time.After(timeout):
			// log warning
		case <-ctx.Done():
			return
		}
	}
}
```

消费者从输入通道读取令牌，如果一小时后通道中没有出现值，则会发出警报。

让我们编写一个客户端来测量 100K 通道发送后的内存使用情况：

```go
// go 1.22
func main() {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	tokens := make(chan token)
	go consumer(ctx, tokens)

	memBefore := getAlloc()

	for range 100000 {
		tokens <- token{}
	}

	memAfter := getAlloc()
	memUsed := memAfter - memBefore
	fmt.Printf("Memory used: %d KB\n", memUsed/1024)
  // Memory used: 20379 KB
}
```

### 什么是 getAlloc

```go
// getAlloc returns the number of bytes of allocated
// heap objects (after garbage collection).
func getAlloc() uint64 {
    var m runtime.MemStats
    runtime.GC()
    runtime.ReadMemStats(&m)
    return m.Alloc
}
```

`time.After` 在幕后创建一个计时器，该计时器在到期之前不会被释放。由于我们使用了较长的超时（一小时），因此 for 循环本质上创建了无数尚未释放的计时器。这些计时器总共使用约 20 MB 的内存。这显然不是我们想要的。

## 错误的解决方案

我们创建一个计时器并在每次循环迭代中重置它怎么样？看起来很合理。这是 *100 Go Mistakes* 建议的解决方案：

```go
// go 1.22
func consumer(ctx context.Context, in <-chan token) {
	const timeout = time.Hour
	timer := time.NewTimer(timeout)
	for {
		timer.Reset(timeout)
		select {
		case <-in:
			// do stuff
		case <-timer.C:
			// log warning
		case <-ctx.Done():
			return
		}
	}
}
// Memory used: 0 KB
```

由于我们重复使用相同的计时器实例而不是创建新实例，因此内存使用问题得到解决。但问题是，这不是 Go ≤1.22 中使用 `Reset` 方法的方式。

```go
// go 1.22
func main() {
	const timeout = 10 * time.Millisecond
	t := time.NewTimer(timeout)
	time.Sleep(20 * time.Millisecond)

	start := time.Now()
	t.Reset(timeout)
	<-t.C
	fmt.Printf("Time elapsed: %dms\n",time.Since(start).Milliseconds())
	// expected: Time elapsed: 10ms
	// actual:   Time elapsed:  0ms
}
```

计时器 `t` 的超时时间为 10 毫秒。所以我们等待了 20ms 后，它已经过期了，并向 `t.C` 通道发送了一个值。由于 `Reset` 不会排空通道，因此 `<-t.C` 不会阻塞并立即继续。另外，由于 `Reset` 重新启动了计时器，10 毫秒后我们将在 `t.C` 中看到另一个值。

这不是一个小问题。让我们看看如果消费者中的“do stuff”分支花费的时间超过计时器超时时间会发生什么：

```go
// go 1.22
func consumer(ctx context.Context, in <-chan token) {
	const timeout = 10 * time.Millisecond
	timer := time.NewTimer(timeout)
	for {
		timer.Reset(timeout)
		select {
		case <-in:
			// do stuff
			time.Sleep(20 * time.Millisecond)
		case <-timer.C:
			panic("should not happen")
		case <-ctx.Done():
			return
		}
	}
}
```

由于计时器通道未耗尽，因此无论 `Reset` 调用如何，都会执行计时器分支，从而导致恐慌。

让我在这里引用 Go stdlib 文档：

> For a Timer created with NewTimer, Reset should be invoked only on stopped or expired timers with drained channels.
>
> 对于使用 NewTimer 创建的计时器，仅应在通道已耗尽的停止或过期计时器上调用 Reset。

它可能不是很直观，但它是在 Go ≤1.22 中正确使用 `Reset` 的唯一方法。

## 1.23 修复

Go 1.23 修复了重置问题。再次引用文档：

> The timer channel associated with a Timer is now unbuffered, with capacity 0. The main effect of this change is that Go now guarantees that for any call to a Reset (or Stop) method, no stale values prepared before that call will be sent or received after the call.
>
> 与 Timer 关联的计时器通道现在是无缓冲的，容量为 0。此更改的主要效果是，Go 现在保证对于任何对 Reset（或 Stop）方法的调用，不会发送该调用之前准备的过时值，或者通话后收到。

但如果您查看代码，您会发现通道实际上仍在缓冲中：

```go
// As of Go 1.23, the channel is synchronous (unbuffered, capacity 0),
// eliminating the possibility of those stale values.
func NewTimer(d Duration) *Timer {
	c := make(chan Time, 1)
	t := (*Timer)(newTimer(when(d), 0, sendTime, c, syncTimer(c)))
	t.C = c
	return t
}
```

[time/sleep.go](https://github.com/golang/go/blob/release-branch.go1.23/src/time/sleep.go#L142)

根据提交消息，Go 团队将计时器通道保留为缓冲状态（与代码注释所述相反）。但他们还破解了 `chan` 类型本身，以返回计时器通道的零长度和容量：

[runtime/chan.go](https://github.com/golang/go/blob/release-branch.go1.23/src/runtime/chan.go#L786) • [commit message](https://go-review.googlesource.com/c/go/+/568341)

对我来说这似乎是一个肮脏的黑客方法，但我懂什么？

## 1.23 之前的解决方案

虽然简单的 `Reset` 应该适用于 1.23+，但在早期版本中，我们必须确保计时器停止或过期，并且具有耗尽的通道。让我们编写一个辅助函数并在消费者中使用它：

```go
// resetTimer stops, drains and resets the timer.
func resetTimer(t *time.Timer, d time.Duration) {
	if !t.Stop() {
		select {
		case <-t.C:
		default:
		}
	}
	t.Reset(d)
}

// go 1.22
func consumer(ctx context.Context, in <-chan token) {
	const timeout = time.Hour
	timer := time.NewTimer(timeout)
	for {
		resetTimer(timer, timeout)
		select {
		case <-in:
			// do stuff
		case <-timer.C:
			// log warning
		case <-ctx.Done():
			return
		}
	}
}
```

现在，无论超时值和“do stuff”执行时间如何，消费者都可以保证正常工作。

```go
// go 1.22
func main() {
	const timeout = 10 * time.Millisecond
	t := time.NewTimer(timeout)
	time.Sleep(20 * time.Millisecond)

	start := time.Now()
	resetTimer(t, timeout)
	<-t.C
	fmt.Printf("Time elapsed: %dms\n", time.Since(start).Milliseconds())
}
```

## 1.23 后的解决方案

从 Go 1.23 开始，垃圾收集器可以释放活动的（但未引用的）计时器。因此循环中的 `time.After` 不会堆积内存：

```go
// go 1.23
func consumer(ctx context.Context, in <-chan token) {
	const timeout = time.Hour
	for {
		select {
		case <-in:
			// do stuff
		case <-time.After(timeout):
			// log warning
		case <-ctx.Done():
			return
		}
	}
}
```

当然，它仍然会进行大量分配。因此，您可能更喜欢 `NewTimer` + `Reset` 方法 - 它不会创建新的计时器，因此 GC 不需要收集它们。

```go
// go 1.23
func consumer(ctx context.Context, in <-chan token) {
	const timeout = time.Hour
	timer := time.NewTimer(timeout)
	for {
		timer.Reset(timeout)
		select {
		case <-in:
			// do stuff
		case <-timer.C:
			// log warning
		case <-ctx.Done():
			return
		}
	}
}
```

以下两个选项（ `time.After` VS `timer.Reset` ）：

```bash
BenchmarkAfter-8    24    49271620 ns/op    23201095 B/op    300012 allocs/op
BenchmarkReset-8    40    29428138 ns/op         652 B/op         8 allocs/op
```

胜利者已经很明显了。

## time.AfterFunc

更糟糕的是， `time.AfterFunc` 还创建了一个计时器，但是是一个非常不同的计时器。它有一个 nil `C` 通道，因此 `Reset` 方法的工作方式不同：

+ 如果计时器仍然处于活动状态（未停止，未过期）， `Reset` 会清除超时，从而有效地重新启动计时器。
+ 如果计时器已停止或到期， `Reset` 会安排新的函数执行。

```go
func main() {
	var start time.Time

	work := func() {
		fmt.Printf("work done after %dms\n", time.Since(start).Milliseconds())
	}

	// run work after 10 milliseconds
	timeout := 10 * time.Millisecond
	start = time.Now()  // ignore the data race for simplicity
	t := time.AfterFunc(timeout, work)

	// wait for 5 to 15 milliseconds
	delay := time.Duration(5+rand.Intn(11)) * time.Millisecond
	time.Sleep(delay)
	fmt.Printf("%dms has passed...\n", delay.Milliseconds())

	// Reset behavior depends on whether the timer has expired
	t.Reset(timeout)
	start = time.Now()

	time.Sleep(50*time.Millisecond)
}
```

如果计时器尚未到期， `Reset` 会清除超时：

```bash
8ms has passed...
work done after 10ms
```

如果计时器已过期，Reset 会安排新的函数调用：

```go
work done after 10ms
13ms has passed...
work done after 10ms
```

## 最后

重申一下：

+ Go ≤ 1.22：对于使用 `NewTimer` 创建的 `Timer` ， `Reset` 只能在通道耗尽的计时器停止或过期时调用。
+ Go ≥ 1.23：对于使用 `NewTimer` 创建的 `Timer` ，在任何状态（活动、停止或过期）的计时器上调用 `Reset` 都是安全的。不需要通道耗尽，因为计时器通道（某种程度上）不再被缓冲。
+ 对于使用 `AfterFunc` 创建的 `Timer` ， `Reset` 要么重新安排该函数（如果计时器仍然处于活动状态），要么安排该函数再次运行（如果计时器已已停止或已过期）。

[Documentation [pre-1.23\]](https://pkg.go.dev/time@go1.22#Timer.Reset) • [Documentation [1.23+\]](https://pkg.go.dev/time@master#Timer.Reset) • [100 Go Mistakes](https://100go.co/#timeafter-and-memory-leaks-76)

定时器并不是 Go 中最明显的东西，不是吗？



## 参考

本文翻译于 [Resetting timers in Go](https://antonz.org/timer-reset/)