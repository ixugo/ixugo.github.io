---
title: Go Traces
description: 
date: 2024-08-10
slug: 
image: 
draft: false
categories:
    - Go
tags:
    - Go

---

## Trace

`runtime/trace` 包包含一个用于理解 Go 程序和排除故障的强大工具。其中的功能允许人们在一段时间内生成每个 goroutine 执行的跟踪。使用 `go tool trace` 命令或（或优秀的开源[gotraceui 工具](https://gotraceui.dev/)），用可视化的探索这些跟踪中的数据。

trace 的神奇之处在于，它可以轻松地揭示程序中难以通过其它方式看到的信息。例如，大量 goroutine 在同一个 channel 上阻塞的并发瓶颈可能很难在 CPU profile 中看到，因为没有可供采样的执行。但在 trace 中，将会清晰的显现出来，并且被阻塞的 goroutine 的堆栈跟踪将很快指出罪魁祸首。

![img](http://img.golang.space/img-1723269814746.png)

Go 开发人员甚至能够使用 tasks, regions 和 logs 来检测自己的程序，它们可以使用这些将更高级别的关注点和较低级别的执行细节相关联。

## 问题

不幸的是，执行跟踪中的大量信息通常是遥不可及的。历史上有四个与 trace 有关的大问题困扰着我们。

+ trace 的开销很高。
+ trace 不能很好地扩展，并且可能会变的过大而无法分析。
+ 通常不清楚何时开始 trace 以捕获特定的不良行为。
+ 由于缺乏用于理解和解释执行跟踪的公共包，只要最具冒险精神的 gopher 才能以编程方式分析 trace 。

幸运的是，Go 在四个问题都取得了巨大的进展。

## 低开销 trace

在 Go 1.21 之前，对于许多应用程序来说，trace 的运行时开销约为 10~20% cpu，这将 trace 限制情景使用情况，而不是像 cpu 分析那样的连续使用情况。事实证明，trace 大部分成本都归结为回溯。运行时产生的续跌事件都附加了堆栈跟踪，对于实际识别 goroutine 在执行的关键时刻正在做什么非常有价值。

感谢 Felix Geisendörfer  和 Nick Ripley  在优化回溯效率方面所做的工作，执行 trace 的运行时 cpu 开销已大幅消减，对于许多应用程序而言，已将至 1~2%，您可以在[Felix 关于该主题的精彩博客文章](https://blog.felixge.de/reducing-gos-execution-tracer-overhead-with-frame-pointer-unwinding/)中阅读有关此处所做工作的更多信息。

## 可缩放 traces

trace 格式及其事件是围绕相对有效设计的，但需要工具来解析和保留整个 trace 的状态，几百 MiB 的 trace 可能需要几个 GiB 的 RAM 来分析。

不幸的是，这个问题对于 trace 的生成方式至关重要。为了保持较低的运行时开销，所有事件都被写入相当于线程本地缓冲区的位置。但这意味着事件的出现不符合其真实顺序，并且 trace 工具需要承担起弄清楚到底发生了什么的责任。

在保持低开销的同时使用 trace 扩展的关键是偶尔分割升生成的 trace。每个分割点的行为有点像一次性同时禁用和重新启用 trace。到目前为止，所有 trace 数据都将代表一个完整且独立的 trace，而新的 trace 数据将从其中断的位置无缝衔接。

正如您可能想象的那样，解决这个问题需要重新思考和重写运行时中的 trace 实现的大量基础。很高兴地说这项工作已在 go 1.22 中发布并且现已普遍可用。重写带来了许多不错的改进，包括对 go tool trace 命令的一些改进。如果您好奇的话，详细信息都在[设计文档](https://github.com/golang/proposal/blob/master/design/60773-execution-tracer-overhaul.md)中。

## 飞行记录

假设您从事 Web 服务，并且 RPC 花费了很长时间。当您知道 RPC 已经花费了一段时间时，您无法开始跟踪，因为缓慢请求的根本原因已经发生并且没有记录。

有一种技术可以帮助完成此任务，称为飞行记录，您可能已经在其他编程环境中熟悉了该技术。飞行记录的要点是持续跟踪并始终保留最新的跟踪数据，以防万一。然后，一旦发生有趣的事情，程序就可以写出它所拥有的一切！

在 traces 被分割之前，这几乎是不可能的。但是，由于开销较低，连续trace 现在是可行的，而且运行时现在可以在需要时随时分割跟踪，因此事实证明，实现飞行记录非常简单。

因此，我们很高兴地宣布进行飞行记录器实验，可在[golang.org/x/exp/trace 包](https://go.dev/pkg/golang.org/x/exp/trace#FlightRecorder)中找到。

请尝试一下！下面是一个设置飞行记录以捕获长 HTTP 请求的示例，以帮助您入门。

```go

func main() {
	// Set up the flight recorder.
	fr := trace.NewFlightRecorder()
	fr.Start()

	// Set up and run an HTTP server.
	var once sync.Once
	var i int
	http.HandleFunc("/test", func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		i++

		// Do the work...
		// doWork(w, r)
		if i > 1000 {
			time.Sleep(5000 * time.Millisecond)
		} else {
			time.Sleep(200 * time.Millisecond)
		}

		// We saw a long request. Take a snapshot!
		if time.Since(start) > 300*time.Millisecond {
			// Do it only once for simplicity, but you can take more than one.
			once.Do(func() {
				// Grab the snapshot.
				var b bytes.Buffer
				_, err := fr.WriteTo(&b)
				if err != nil {
					log.Print(err)
					return
				}
				// Write it to a file.
				if err := os.WriteFile("trace.out", b.Bytes(), 0o755); err != nil {
					log.Print(err)
					return
				}
			})
		}
	})
	log.Fatal(http.ListenAndServe(":8081", nil))
}

```

## trace reader api

随着 traces 实现重写，我们还努力清理其他 trace 内部，例如`go tool trace` 。这催生了创建一个trace reader API 的尝试，该 API 足以共享并且可以使跟踪更容易访问。

就像飞行记录器一样，我们很高兴地宣布，我们也有一个实验性的跟踪读取器 API，我们愿意与大家分享。它[与飞行记录器位于同一包中，golang.org/x/exp/trace](https://go.dev/pkg/golang.org/x/exp/trace#Reader) 。

我们认为它足以开始在其上构建东西，所以请尝试一下！下面的示例测量了阻塞等待网络的 goroutine 阻塞事件的比例。