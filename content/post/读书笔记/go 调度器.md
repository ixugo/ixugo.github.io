---
title: Go 调度器
description: 
date: 2025-05-20
slug: 
image: 
draft: false
categories:
    - Go
tags:
    - Runtime
    - 读书笔记
---



## 免责声明

本博文主要关注在 [ARM](https://en.wikipedia.org/wiki/ARM_architecture_family) 架构 [Linux](https://en.wikipedia.org/wiki/Linux) 上运行的 [Go 1.24](https://tip.golang.org/doc/go1.24) 编程语言。它可能不涵盖其他操作系统或硬件架构的平台特定细节。

本文内容基于其他资料以及我个人对 Go 的理解，因此可能并不完全准确。欢迎在文末评论区指正或提出建议😄。

## 介绍

Golang 于 2009 年推出，作为一种用于构建并发应用程序的编程语言，其受欢迎程度稳步增长。它的设计目标是简单、高效且易于使用。

Go 的并发模型围绕 goroutine 的概念构建，goroutine 是由 Go 运行时在用户空间管理的轻量级用户线程。Go 提供了诸如通道 (channel) 等用于同步的实用原语，帮助开发者轻松编写并发代码。它还采用了一些巧妙的技术来提高 I/O 密集型程序的效率。

理解 Go 调度器对于 Go 程序员编写高效的并发程序至关重要。它还能帮助我们更好地排查性能问题或优化 Go 程序的性能。在本文中，我们将探讨 Go 调度器的发展历程，以及我们编写的 Go 代码在底层是如何运作的。

## 编译和 Go 运行时

本文包含大量源代码解析，因此最好先对 Go 代码的编译和执行方式有一定的了解。Go 程序的构建过程分为三个阶段：

+ Go 源文件（ `*.go` ）被编译成汇编文件（ `*.s` ）
+ 然后将汇编文件（ `*.s` ）汇编成目标文件（ `*.o` ）
+ 目标文件（ `*.o` ）链接在一起，生成一个可执行的二进制文件

要理解 Go 调度器，首先需要理解 Go 运行时。Go 运行时是这门编程语言的核心，它提供了调度、内存管理和数据结构等基本功能。它本质上就是一系列函数和数据结构的集合，正是这些函数和数据结构使 Go 程序能够正常运行。Go 运行时的实现位于 [runtime](https://github.com/golang/go/tree/go1.24.0/src/runtime) 包中。Go 运行时是用 Go 代码和汇编代码混合编写的，其中汇编代码主要用于处理寄存器等底层操作。

![img](http://img.golang.space/img-1769564763579.png)

编译时，Go 编译器会将一些关键字和内置函数替换为 Go 运行时的函数调用。例如，用于创建新 goroutine 的 `go` 关键字会被替换为对 [`runtime.newproc`](https://github.com/golang/go/blob/go1.24.0/src/runtime/proc.go#L5014-L5030) 的调用，或者用于分配新对象的 `new` 函数会被替换为对 [`runtime.newobject`](https://github.com/golang/go/blob/go1.24.0/src/runtime/malloc.go#L1710-L1715) 的调用。

你可能会惊讶地发现，Go 运行时中的某些函数根本没有 Go 实现。例如，像 [`getg`](https://github.com/golang/go/blob/go1.24.0/src/runtime/stubs.go#L28-L31) 这样的函数会被 Go 编译器识别，并在编译过程中被替换为底层汇编代码。而像 [`gogo`](https://github.com/golang/go/blob/go1.24.0/src/runtime/stubs.go#L214-L214) 这样的其他函数则是平台特定的，完全用汇编语言实现。Go 链接器的职责是将这些汇编实现与其 Go 声明连接起来。

在某些情况下，一个函数在其包中似乎没有实现，但实际上它通过 [`//go:linkname`](https://pkg.go.dev/cmd/compile#hdr-Linkname_Directive) 编译器指令链接到了 Go 运行时中的定义。例如，常用的 [`time.Sleep`](https://github.com/golang/go/blob/go1.24.0/src/time/sleep.go#L12-L14) 函数就链接到了其在 [`runtime.timeSleep`](https://github.com/golang/go/blob/go1.24.0/src/runtime/time.go#L297-L340) 中的实际实现。

## 原始调度器

> ⚠️ Go 调度器并非一个独立的对象，而是一组用于辅助调度的函数集合。此外，它并不运行在专用线程上；相反，它与 goroutine 运行在相同的线程上。阅读本文后续内容后，这些概念将变得更加清晰。

如果你曾经从事过并发编程，你可能对多线程模型有所了解。它规定了用户空间线程（Kotlin、Lua 中的协程或 Go 中的 goroutine）如何复用到单个或多个内核线程上。通常有三种模型：多对一 (N:1)、一对一 (1:1) 和多对多 (M:N)。

![img](http://img.golang.space/img-1769567248984.png)

Go 采用多对多（M:N）的线程模型，允许多个 goroutine 被复用（多路复用）到多个内核线程上。这种方法在一定程度上增加了复杂性，但能够充分利用多核系统的性能，并高效处理系统调用，从而克服了 N:1 模型和 1:1 模型各自存在的问题。由于内核并不知道 goroutine 的存在，它仅向用户空间应用程序提供线程作为并发单元，因此是由内核线程来运行调度逻辑、执行 goroutine 的代码，并代表 goroutine 发起系统调用。

在早期，尤其是在 1.1 版本之前，Go 以一种较为简单的方式实现了 M:N 多线程模型。当时只有两种实体：goroutine（ `G` ）和内核线程（ `M` ，或*称机器* ）。所有可运行的 goroutine 都存储在一个全局运行队列中，并使用锁来防止竞态条件。调度器（运行在每个线程 `M` 上）负责从全局运行队列中选择一个 goroutine 并执行它。

![img](http://img.golang.space/img-1769567426040.png)



如今，Go 以其高效的并发模型广为人知。但早期的 Go 并非如此。Go 的核心贡献者之一 Dmitry Vyukov 在他著名的《可扩展的 Go 调度器设计》一文中指出了当时实现的多个问题。他提到：“总体而言，当时的调度器会阻碍用户在性能关键的场景中使用符合 Go 风格的细粒度并发。” 下面我来详细解释他的意思。

首先，全局运行队列是性能瓶颈。当创建一个 goroutine 时，线程必须获取锁才能将其放入全局运行队列。同样，当线程想要从全局运行队列中取出 goroutine 时，也必须获取锁。您可能知道，加锁并非没有开销，它会带来锁竞争的开销。锁竞争会导致性能下降，尤其是在高并发场景下。

其次，线程经常会将关联的 goroutine 移交给另一个线程。这会导致局部性差和过多的上下文切换开销。子 goroutine 通常需要与其父 goroutine 通信。因此，让子 goroutine 与其父 goroutine 运行在同一个线程上性能更高。

第三，由于 Go 语言使用[线程缓存 Malloc](https://google.github.io/tcmalloc/design.html) ，每个线程 `M` 都有一个线程局部缓存 [`mcache`](https://nghiant3223.github.io/2025/06/03/memory_allocation_in_go.html#processors-memory-allocator-mcache) ，用于内存分配或存放空闲内存。虽然 [`mcache`](https://nghiant3223.github.io/2025/06/03/memory_allocation_in_go.html#processors-memory-allocator-mcache) 仅供执行 Go 代码的 `M` 使用，但即使是阻塞在系统调用中的 `M` （这些线程根本不使用 [`mcache`](https://nghiant3223.github.io/2025/06/03/memory_allocation_in_go.html#processors-memory-allocator-mcache) 也会占用它。一个 [`mcache`](https://nghiant3223.github.io/2025/06/03/memory_allocation_in_go.html#processors-memory-allocator-mcache) 最多可以占用 2MB 的内存，并且只有在线程 `M` 被销毁时才会释放。由于执行 Go 代码的 `M` 与所有 `M` 的比例可能高达 1:100（过多的线程阻塞在系统调用中），这可能导致资源过度消耗和数据局部性差。

## 调度器增强

既然您已经了解了早期 Go 调度器的问题，让我们来看看一些改进提案，看看 Go 团队是如何解决这些问题的，从而使我们今天拥有一个高性能的调度器。

### 方案一:  引入本地运行队列

每个线程 `M` 都配备一个本地运行队列，用于存储可运行的 goroutine。当线程 `M` 上正在运行的 goroutine `G` 使用 `go` 关键字生成一个新的 goroutine `G1` 时， `G1` 会被添加到 `M` 的本地运行队列中。如果本地队列已满，则 `G1` 会被放入全局运行队列。在选择要执行的 goroutine 时， `M` 会首先检查其本地运行队列，然后再查询全局运行队列。因此，本方案解决了上一节中描述的第一个和第二个问题。

![img](http://img.golang.space/img-1769568770970.png)

然而，它无法解决第三个问题。当许多线程 `M` 阻塞在系统调用中时，它们的 [`mcache`](https://nghiant3223.github.io/2025/06/03/memory_allocation_in_go.html#processors-memory-allocator-mcache) 会一直挂载，导致 Go 调度器本身内存占用过高，更不用说我们——Go 程序员——编写的程序的内存占用了。

这还会引入另一个性能问题。为了避免阻塞线程 `M` 的本地运行队列（例如上图中的 `M1` 中的 goroutine 因饥饿而无法执行，调度器应该允许其他线程从该队列中 *“窃取* ”goroutine。然而，当阻塞线程数量庞大时，扫描所有线程以找到非空的运行队列会变得非常耗时。

### 方案二: 引入逻辑处理器

该方案在 [《可扩展的 Go 调度器设计》一文](https://docs.google.com/document/d/1TTj4T2JO42uD5ID9e89oa0sLKhJYD0Y_kqxDv3I3XMw)中有所描述，其中引入了*逻辑*处理器 `P` 的概念。所谓 *“逻辑”* ，是指 `P` 表面上执行 goroutine 代码，但实际上，执行代码的是与 `P` 关联的线程 `M` 线程的本地运行队列和 [`mcache`](https://nghiant3223.github.io/2025/06/03/memory_allocation_in_go.html#processors-memory-allocator-mcache) 现在都归 `P` 所有。

该方案有效地解决了上一节中遗留的问题。由于 [`mcache`](https://nghiant3223.github.io/2025/06/03/memory_allocation_in_go.html#processors-memory-allocator-mcache) 现在附加到 `P` 而不是 `M` ，并且当 `G` 进行系统调用时 `M` 会从 `P` 分离，因此即使有大量 `M` 进行系统调用，内存消耗也能保持较低水平。此外，由于 `P` 的数量有限，这种*内存窃取*机制也十分高效。

![img](http://img.golang.space/img-1769569563522.png)

随着逻辑处理器的引入，多线程模型仍然是 M:N。但在 Go 语言中，它被专门称为 GMP 模型，因为有三种实体：goroutine、线程和处理器。

### GMP 模式

当 `go` 关键字后面跟着函数调用时，会创建一个新的 [`g`](https://github.com/golang/go/blob/go1.24.0/src/runtime/runtime2.go#L396-L508) 实例，称为 `G` `G` 是一个代表 goroutine 的对象，包含诸如执行状态、堆栈以及指向关联函数的程序计数器等元数据。执行 goroutine 就相当于运行 `G` 引用的函数。

当一个 goroutine 执行完毕后，它不会被销毁；相反，它会变成 *“死亡”状态* ，并被放入当前处理器 `P` 的空闲列表中。如果 `P` 的空闲列表已满，则该死亡的 goroutine 会被移至全局空闲列表。当创建一个新的 goroutine 时，调度器会首先尝试从空闲列表中重用一个，然后再从头开始分配一个新的。这种循环机制使得创建 goroutine 的开销远低于创建新线程。

下图和表格描述了 GMP 模型中 goroutine 的状态机。为简化起见，省略了一些状态和转换。触发状态转换的动作将在后续文章中进行描述。

|                          State 状态                          | Description 描述                               |
| :----------------------------------------------------------: | ---------------------------------------------- |
| [Idle](https://github.com/golang/go/blob/go1.24.0/src/runtime/runtime2.go#L36-L39) | 刚刚创建，尚未初始化                           |
| [Runnable](https://github.com/golang/go/blob/go1.24.0/src/runtime/runtime2.go#L40-L42) | 当前已进入运行队列，即将执行代码               |
| [Running](https://github.com/golang/go/blob/go1.24.0/src/runtime/runtime2.go#L44-L47) | 不在运行队列中，正在执行代码                   |
| [Syscall](https://github.com/golang/go/blob/go1.24.0/src/runtime/runtime2.go#L49-L52) | 执行系统调用，而不是执行代码                   |
| [Waiting](https://github.com/golang/go/blob/go1.24.0/src/runtime/runtime2.go#L54-L62) | 未执行代码，且不在运行队列中，例如正在等待通道 |
| [Dead](https://github.com/golang/go/blob/go1.24.0/src/runtime/runtime2.go#L68-L74) | 当前处于空闲列表、刚刚退出或刚刚初始化         |

![img](http://img.golang.space/img-1769569806061.png)

**线程 M**

所有 Go 代码——无论是用户代码、调度器还是垃圾回收器——都运行在由操作系统内核管理的线程上。为了使 Go 调度器能够在 GMP 模型下良好地运行线程，引入了表示线程的 [`m`](https://github.com/golang/go/blob/go1.24.0/src/runtime/runtime2.go#L528-L630) 结构体， [`m`](https://github.com/golang/go/blob/go1.24.0/src/runtime/runtime2.go#L528-L630) 的一个实例称为 `M`

M 会持有以下引用：当前的 goroutine G；如果 M 正在执行 Go 代码，则持有当前的处理器 P；如果 M 正在执行系统调用，则持有之前的处理器 P；如果 M 即将被创建，则持有下一个处理器 P。

每个 `M` 还持有一个名为 `g0` 的特殊 goroutine 的引用，该 goroutine 运行在系统栈上——系统栈是由内核提供给线程的栈。与系统栈不同，普通 goroutine 的栈是动态调整大小的；它会根据需要增长和收缩。然而，增长或收缩栈的操作本身必须在有效的栈上运行。为此，系统栈被使用。当运行在 `M` 线程上的调度器需要执行栈管理时，它会从 goroutine 的栈切换到系统栈。除了栈的增长和收缩之外，诸如垃圾回收和 [goroutine 的停用之](https://nghiant3223.github.io/2025/04/15/go-scheduler.html#goroutine-parking-gopark)类的操作也需要在系统栈上执行。每当线程执行此类操作时，它都会切换到系统栈，并在 `g0` 的上下文中执行该操作。

与 goroutine 不同，线程在 `M` 创建后立即运行调度器代码，因此 `M` 的初始状态为*运行中* 。当 `M` 创建或被唤醒时，调度器会保证始终存在一个*空闲*处理器 `P` ，以便将其与 `M` 关联以运行 Go 代码。如果 `M` 正在执行系统调用，它将与 `P` 分离（将在 [“处理系统调用”](https://nghiant3223.github.io/2025/04/15/go-scheduler.html#handling-system-calls) 部分中描述），并且 `P` 可能被另一个线程 `M1` 获取以继续其工作。如果 `M` 无法从其本地运行队列、全局运行队列或 `netpoll` （将在 [“netpoll 工作原理 ](https://nghiant3223.github.io/2025/04/15/go-scheduler.html#how-netpoll-works)”部分中描述）中找到可运行的 goroutine，它将持续自旋以再次从其他处理器 `P` 和全局运行队列中窃取 goroutine。请注意，并非所有 `M` 都会进入自旋状态，只有当自旋线程数少于繁忙处理器数的一半时才会进入自旋状态。当 `M` 没有事可做时，它不会销毁，而是进入睡眠状态，等待稍后被另一个处理器 `P1` 获取（在 [“寻找可运行的 Goroutine](https://nghiant3223.github.io/2025/04/15/go-scheduler.html#finding-a-runnable-goroutine) ”中描述）。

下图和表格描述了 GMP 模型中线程的状态机。 为简化起见，省略了一些状态和转换。 *自旋*是*空闲状态*的一种子状态，在这种状态下，线程会消耗 CPU 周期来执行占用 goroutine 的 Go 运行时代码。触发状态转换的操作将在后续文章中进行描述。

| State 状态 | Description 描述                 |
| :--------: | -------------------------------- |
|  Running   | 执行 Go 运行时代码或用户 Go 代码 |
|  Syscall   | 当前正在执行（阻塞）系统调用     |
|  Spinning  | 从其他处理器窃取 goroutine       |
|   Sleep    | 睡眠状态，不占用 CPU 周期        |

![img](http://img.golang.space/img-1769570601286.png)

**处理器 P**

[`p`](https://github.com/golang/go/blob/go1.24.0/src/runtime/runtime2.go#L632-L757) 结构体在概念上代表一个用于执行 goroutine `P` [`p`](https://github.com/golang/go/blob/go1.24.0/src/runtime/runtime2.go#L632-L757) 它们在程序的引导阶段创建。虽然创建的线程数可能很大（在 Go 1.24 中可达 [10000](https://github.com/golang/go/blob/go1.24.0/src/runtime/proc.go#L827-L827) ），但处理器的数量通常很少，由 [`GOMAXPROCS`](https://pkg.go.dev/runtime#GOMAXPROCS) 决定。无论程序处于何种状态，处理器的数量都恰好为 [`GOMAXPROCS`](https://pkg.go.dev/runtime#GOMAXPROCS) 。

为了最大限度地减少全局运行队列上的锁争用，Go 运行时中的每个处理器 `P` 都维护一个本地运行队列。本地运行队列并非仅仅是一个队列，而是由两个组件构成： [`runnext`](https://github.com/golang/go/blob/go1.24.0/src/runtime/runtime2.go#L655-L667) ，用于存放单个优先级不同的 goroutine；以及 [`runq`](https://github.com/golang/go/blob/go1.24.0/src/runtime/runtime2.go#L654-L654) ，一个 goroutine 队列。这两个组件都为处理器 `P` 提供可运行的 goroutine，但 [`runnext`](https://github.com/golang/go/blob/go1.24.0/src/runtime/runtime2.go#L655-L667) 存在本身就是为了优化性能。Go 调度器允许处理器 `P` 从其他处理器 `P1` 的本地运行队列中“窃取”goroutine。 只有当从 P1 的 [`runq`](https://github.com/golang/go/blob/go1.24.0/src/runtime/runtime2.go#L654-L654) 中窃取 goroutine 的前三次尝试均失败后，才会查询 `P1` 的 [`runnext`](https://github.com/golang/go/blob/go1.24.0/src/runtime/runtime2.go#L655-L667) 。因此，当 `P` 想要执行一个 goroutine 时，如果它首先从自己的 [`runnext`](https://github.com/golang/go/blob/go1.24.0/src/runtime/runtime2.go#L655-L667) 中查找可运行的 goroutine，则可以减少锁争用。

`P` 的 [`runq`](https://github.com/golang/go/blob/go1.24.0/src/runtime/runtime2.go#L654-L654) 组件是一个基于数组的、固定大小的循环队列。由于采用数组结构并固定大小（256 个槽位），它可以更好地保证缓存局部性并降低内存分配开销。固定大小对于 `P` 的本地运行队列来说是安全的，因为我们还有全局运行队列作为备份。循环结构允许高效地添加和删除 goroutine，而无需移动元素。

[`mcache`](https://nghiant3223.github.io/2025/06/03/memory_allocation_in_go.html#processors-memory-allocator-mcache) 在[线程缓存 Malloc](https://google.github.io/tcmalloc/design.html) 模型中充当前端，并由 `P` 用来分配微型和小型对象。 另一方面， [`pageCache`](https://github.com/golang/go/blob/go1.24.0/src/runtime/mpagecache.go#L14-L22) 使内存分配器能够在不获取[堆锁的](https://www.ibm.com/docs/en/sdk-java-technology/8?topic=management-heap-allocation#the-allocator)情况下获取内存页，从而提高高并发下的性能。

为了使 Go 程序能够很好地处理[睡眠 ](https://pkg.go.dev/time#Sleep)、[ 超时](https://pkg.go.dev/time#After)或[间隔](https://pkg.go.dev/time#Tick)操作， `P` 还管理着由[最小堆](https://en.wikipedia.org/wiki/Heap_(data_structure))数据结构实现的定时器，其中最近的定时器位于堆顶。在查找可运行的 goroutine 时， `P` 还会检查是否存在已过期的定时器。如果存在， `P` 会将带有相应定时器的 goroutine 添加到其本地运行队列中，从而给该 goroutine 运行的机会。

下图和表格描述了 GMP 模型中处理器的状态机。为简化起见，省略了一些状态和转换。触发状态转换的操作将在后续文章中进行描述。

|                          State 状态                          | Description 描述                                             |
| :----------------------------------------------------------: | ------------------------------------------------------------ |
| [Idle](https://github.com/golang/go/blob/go1.24.0/src/runtime/runtime2.go#L113-L120) | 未执行 Go 运行时代码或用户 Go 代码                           |
| [Running](https://github.com/golang/go/blob/go1.24.0/src/runtime/runtime2.go#L122-L129) | 与正在执行用户 Go 代码的 `M` 相关联                          |
| [Syscall](https://github.com/golang/go/blob/go1.24.0/src/runtime/runtime2.go#L131-L141) | 与正在执行系统调用的 `M` 相关联                              |
| [GCStop](https://github.com/golang/go/blob/go1.24.0/src/runtime/runtime2.go#L143-L151) | 与一个因垃圾收集而导致世界停摆的 `M` 有关                    |
| [Dead](https://github.com/golang/go/blob/go1.24.0/src/runtime/runtime2.go#L153-L157) | 不再使用，等待 [GOMAXPROCS](https://pkg.go.dev/runtime#GOMAXPROCS) 增长时重新使用。 |

![img](http://img.golang.space/img-1769611601457.png)

在 Go 程序执行初期，有 [`GOMAXPROCS`](https://pkg.go.dev/runtime#GOMAXPROCS) 个处理器 `P` 处于*空闲*状态。当线程 `M` 获取一个处理器来运行用户 Go 代码时， `P` 会转换到*运行*状态。如果当前 goroutine `G` 发起系统调用， `P` 会从 `M` 分离并进入*系统调用*状态。在系统调用期间，如果 `P` 被 `sysmon` 抢占（参见[非合作抢占 ](https://nghiant3223.github.io/2025/04/15/go-scheduler.html#non-cooperative-preemption)），它首先转换到*空闲状态* ，然后被移交给另一个线程（ `M1` ）并进入*运行*状态。否则，系统调用完成后， `P` 会重新附加到之前的 `M` 并恢复*运行*状态（参见[处理系统调用 ](https://nghiant3223.github.io/2025/04/15/go-scheduler.html#handling-system-calls)）。当发生 stop-the-world 垃圾回收时， `P` 会转换到 *gcStop* 状态，并在 start-the-world 恢复后返回到之前的状态。如果在运行时 [`GOMAXPROCS`](https://pkg.go.dev/runtime#GOMAXPROCS) 减少，冗余处理器会转换到 *dead* 状态，并在 [`GOMAXPROCS`](https://pkg.go.dev/runtime#GOMAXPROCS) 稍后增加时被重用。

**程序引导**

要启用 Go 调度器，必须在程序启动期间对其进行初始化。此初始化过程通过汇编语言中的 [`runtime·rt0_go`](https://github.com/golang/go/blob/go1.24.0/src/runtime/asm_amd64.s#L159-L159) 函数完成。在此阶段，将创建线程 [`M0`](https://github.com/golang/go/blob/go1.24.0/src/runtime/proc.go#L117-L117) （代表主线程）和 goroutine [`G0`](https://github.com/golang/go/blob/go1.24.0/src/runtime/proc.go#L118-L118) （ [`M0`](https://github.com/golang/go/blob/go1.24.0/src/runtime/proc.go#L117-L117) 的系统栈 goroutine）。 还为主线程设置了[线程本地存储 ](https://en.wikipedia.org/wiki/Thread-local_storage)（TLS），并将 [`G0`](https://github.com/golang/go/blob/go1.24.0/src/runtime/proc.go#L118-L118) 的地址存储在此 TLS 中，以便稍后通过 [`getg`](https://nghiant3223.github.io/2025/04/15/go-scheduler.html#getting-goroutine-getg) 检索它。

引导程序随后调用汇编函数 [`runtime·schedinit`](https://github.com/golang/go/blob/go1.24.0/src/runtime/asm_amd64.s#L349) ，其 Go 实现位于 [`runtime.schedinit`](https://github.com/golang/go/blob/go1.24.0/src/runtime/proc.go#L790-L898) 。该函数执行各种初始化操作，其中最重要的是调用 [`procresize`](https://github.com/golang/go/blob/go1.24.0/src/runtime/proc.go#L5719-L5868) ，将 [`GOMAXPROCS`](https://pkg.go.dev/runtime#GOMAXPROCS) 个逻辑处理器 `P` 设置为*空闲*状态。然后，主线程 [`M0`](https://github.com/golang/go/blob/go1.24.0/src/runtime/proc.go#L117-L117) 与第一个处理器关联，其状态从*空闲*转换为*运行状态*以执行 goroutine。

之后，创建主 goroutine 来运行 [`runtime.main`](https://github.com/golang/go/blob/go1.24.0/src/runtime/proc.go#L146-L148) 函数，该函数作为 Go 运行时入口点。在 [`runtime.main`](https://github.com/golang/go/blob/go1.24.0/src/runtime/proc.go#L146-L148) 函数内部，会创建一个专用线程来启动 `sysmon` ，这将在 [“非合作抢占”](https://nghiant3223.github.io/2025/04/15/go-scheduler.html#non-cooperative-preemption) 部分进行描述。请注意， [`runtime.main`](https://github.com/golang/go/blob/go1.24.0/src/runtime/proc.go#L146-L148) 与我们编写的 `main` 函数不同；后者在运行时中显示为 [`main_main`](https://github.com/golang/go/blob/go1.24.0/src/runtime/proc.go#L134-L135) 。

主线程随后调用 [`mstart`](https://github.com/golang/go/blob/go1.24.0/src/runtime/proc.go#L1769-L1769) 在内存 [`M0`](https://github.com/golang/go/blob/go1.24.0/src/runtime/proc.go#L117-L117) 上开始执行，启动[调度循环](https://nghiant3223.github.io/2025/04/15/go-scheduler.html#schedule-loop)以获取并执行主 goroutine。在 [`runtime.main`](https://github.com/golang/go/blob/go1.24.0/src/runtime/proc.go#L146-L148) 函数中，经过额外的初始化步骤后，控制权最终交给用户定义的 [`main_main`](https://github.com/golang/go/blob/go1.24.0/src/runtime/proc.go#L134-L135) 函数，程序开始执行用户编写的 Go 代码。

值得注意的是，主线程 [`M0`](https://github.com/golang/go/blob/go1.24.0/src/runtime/proc.go#L117-L117) 不仅负责运行主 goroutine，还负责执行其他 goroutine。每当主 goroutine 被阻塞时——例如等待系统调用或等待通道时——主线程都会寻找另一个可运行的 goroutine 并执行它。

综上所述，程序启动时，有一个 goroutine `G` 执行 `main` 函数；两个线程——一个是主线程 `M0` ，另一个用于启动 `sysmon` ；一个处理器 `P0` 处于*运行*状态，以及 `GOMAXPROCS−1` 处理器处于*空闲*状态。主线程 `M0` 最初与处理器 `P0` 关联，以运行主 goroutine `G`

下图展示了程序启动时的状态。图中假设 [`GOMAXPROCS`](https://pkg.go.dev/runtime#GOMAXPROCS) 设置为 2，并且 `main` 函数刚刚开始执行。处理器 `P0` 正在执行主 goroutine，因此处于*运行*状态。处理器 `P1` 没有执行任何 goroutine，处于*空闲*状态。主线程 `M0` 与处理器 `P0` 关联以执行主 goroutine 的同时，创建了另一个线程 `M1` 来运行 `sysmon` 。

![img](http://img.golang.space/img-1769611886747.png)

值得一提的是，在启动阶段，运行时还会生成一些与内存管理相关的 goroutine，例如标记、清除和清理。不过，本文暂不讨论这些，我们将在后续文章中进行更详细的探讨。

**创建 Goroutine**

Go 提供了一个简单的 API 来启动并发执行单元： `go func() { ... } ()` `go` 实际上，Go 运行时在底层做了很多复杂的工作来实现这一点。`go` 关键字只是 Go 运行时 [`newproc`](https://github.com/golang/go/blob/go1.24.0/src/runtime/proc.go#L5014-L5030) 函数的语法糖，该函数负责调度一个新的 goroutine。这个函数主要执行三件事：初始化 goroutine，将其放入调用 goroutine 的处理器 `P` 的运行队列中，以及唤醒另一个处理器 `P1` 。

**初始化 Goroutine**

调用 [`newproc`](https://github.com/golang/go/blob/go1.24.0/src/runtime/proc.go#L5014-L5030) 时，仅当没有空闲的 goroutine 可用时才会创建一个新的 goroutine `G` 在执行完毕返回后会变为空闲状态。新创建的 goroutine `G` 会被初始化为一个 2KB 的栈，该栈大小由 Go 运行时中的 [stackMin](https://github.com/golang/go/blob/go1.24.0/src/runtime/stack.go#L75-L75) 常量定义。此外， [`goexit`](https://github.com/golang/go/blob/go1.24.0/src/runtime/stubs.go#L281-L291) （负责清理逻辑和调度逻辑）会被压入 `G` 的调用栈，以确保它在 `G` 返回时执行。初始化完成后， `G` 会从*死*状态转换为*可运行*状态，表明它已准备好被调度执行。

**将 Goroutine 放入队列**

如前所述，每个处理器 `P` 都有一个由两部分组成的运行队列： [`runnext`](https://github.com/golang/go/blob/go1.24.0/src/runtime/runtime2.go#L655-L667) 和 [`runq`](https://github.com/golang/go/blob/go1.24.0/src/runtime/runtime2.go#L654-L654) 。当一个新的 goroutine 创建时，它会被放入 [`runnext`](https://github.com/golang/go/blob/go1.24.0/src/runtime/runtime2.go#L655-L667) 中。如果 [`runnext`](https://github.com/golang/go/blob/go1.24.0/src/runtime/runtime2.go#L655-L667) 已经存在 goroutine `G1` ，调度器会尝试将 `G1` 移至 [`runq`](https://github.com/golang/go/blob/go1.24.0/src/runtime/runtime2.go#L654-L654) （前提是 [`runq`](https://github.com/golang/go/blob/go1.24.0/src/runtime/runtime2.go#L654-L654) 未满），并将 `G` 放回 [`runnext`](https://github.com/golang/go/blob/go1.24.0/src/runtime/runtime2.go#L655-L667) 。如果 [`runq`](https://github.com/golang/go/blob/go1.24.0/src/runtime/runtime2.go#L654-L654) 已满，则 `G1` 以及 [`runq`](https://github.com/golang/go/blob/go1.24.0/src/runtime/runtime2.go#L654-L654) 中一半的 goroutine 会被移至全局运行队列，以减轻处理器 `P` 的工作负载。

**唤醒处理器**

当创建一个新的 goroutine 时，为了最大化程序并发性，运行该 goroutine 的线程会尝试通过 [`futex`](https://man7.org/linux/man-pages/man2/futex.2.html) 系统调用唤醒另一个处理器 `P` 为此，它首先检查是否有空闲的处理器 P。如果有空闲的处理器 `P` 可用，则会创建一个新线程，或者唤醒一个现有线程进入[调度循环 ](https://nghiant3223.github.io/2025/04/15/go-scheduler.html#schedule-loop)，并在循环中寻找可执行的 goroutine。创建或重用线程的逻辑在 [“启动线程”](https://nghiant3223.github.io/2025/04/15/go-scheduler.html#start-thread-startm) 部分中进行了描述。

如前所述， [`GOMAXPROCS`](https://pkg.go.dev/runtime#GOMAXPROCS) （即活动处理器数量 `P` 决定了可以同时运行的 goroutine 数量。如果所有处理器都处于忙碌状态，并且不断生成新的 goroutine，则既不会唤醒现有线程，也不会创建新线程。

**总结**

下图展示了 goroutine 的创建过程。为简化起见，图中假设 [`GOMAXPROCS`](https://pkg.go.dev/runtime#GOMAXPROCS) 设置为 2，处理器 `P1` 尚未进入[调度循环 ](https://nghiant3223.github.io/2025/04/15/go-scheduler.html#schedule-loop)，且 `main` 函数除了不断创建新的 goroutine 之外不做任何其他操作。由于 goroutine 不执行系统调用（详见 [“处理系统调用”](https://nghiant3223.github.io/2025/04/15/go-scheduler.html#handling-system-calls) 部分），因此会创建一个额外的线程 `M2` 与处理器 `P1` 关联。

![img](http://img.golang.space/img-1769612199196.png)

**调度循环**

Go 运行时中的 [`schedule`](https://github.com/golang/go/blob/go1.24.0/src/runtime/proc.go#L3986-L4068) 函数负责查找和执行可运行的 goroutine。它会在各种情况下被调用：创建新线程时、调用 [`Gosched`](https://pkg.go.dev/runtime#Gosched) 时、goroutine 被暂停或抢占时，或者 goroutine 完成系统调用并返回后。

选择可运行的 goroutine 的过程比较复杂，将在 [“查找可运行的 goroutine”](https://nghiant3223.github.io/2025/04/15/go-scheduler.html#finding-a-runnable-goroutine) 一节中详细介绍。一旦 goroutine 被选中，它的状态就会从*可运行*状态转变为*运行*状态，表明它已准备好运行。此时，内核线程会调用 [`gogo`](https://github.com/golang/go/blob/go1.24.0/src/runtime/stubs.go#L214-L214) 函数来启动 goroutine 的执行。

但为什么称之为*循环*呢？正如 [“初始化 Goroutine”](https://nghiant3223.github.io/2025/04/15/go-scheduler.html#initializing-goroutine) 一节所述，当一个 goroutine 执行完毕时，会调用 [`goexit`](https://github.com/golang/go/blob/go1.24.0/src/runtime/stubs.go#L281-L291) 函数。该函数最终会调用 [`goexit0`](https://github.com/golang/go/blob/go1.24.0/src/runtime/proc.go#L4307-L4310) ，后者负责清理终止的 goroutine 并重新进入 [`schedule`](https://github.com/golang/go/blob/go1.24.0/src/runtime/proc.go#L3986-L4068) 函数——从而再次形成 [schedule 循环 ](https://nghiant3223.github.io/2025/04/15/go-scheduler.html#schedule-loop)。

下图展示了 Go 运行时中的调度循环，其中粉色代码块是用户编写的 Go 代码， 黄色代码块是 Go 运行时代码。虽然以下内容看似显而易见，但请注意，调度循环是由线程执行的。这就是为什么它会在线程初始化（ 蓝色代码块）之后执行的原因。

![image-20260128225959394](http://img.golang.space/img-1769612399600.png)

但如果主线程陷入调度循环，进程如何退出呢？只需查看 Go 运行时中的 [`main`](https://github.com/golang/go/blob/go1.24.0/src/runtime/proc.go#L307-L307) 函数，它由 main goroutine 执行。main_main [`main_main`](https://github.com/golang/go/blob/go1.24.0/src/runtime/proc.go#L134-L135) Go 程序员编写的 `main` 函数的别名，返回后，会调用 [`exit`](https://man7.org/linux/man-pages/man3/exit.3.html) 系统调用来终止进程。这就是进程退出的方式，也是 main goroutine 不会等待由 `go` 关键字创建的 goroutine 的原因。

**寻找可运行的 Goroutine**

线程 `M` 的职责是找到合适的可运行 goroutine，以最大程度地减少 goroutine 饥饿现象。这一逻辑在 [`findRunnable`](https://github.com/golang/go/blob/go1.24.0/src/runtime/proc.go#L3267-L3646) 函数中实现，该函数由[调度循环](https://nghiant3223.github.io/2025/04/15/go-scheduler.html#schedule-loop)调用。

线程 `M` 按以下顺序查找可运行的 goroutine，如果找到则停止链式调用：

1. 检查[跟踪读取器 ](https://go.dev/blog/execution-traces-2024#trace-reader-api)goroutine 的可用性（用于[非合作抢占](https://nghiant3223.github.io/2025/04/15/go-scheduler.html#non-cooperative-preemption)部分）。
2. 检查垃圾回收工作程序 goroutine 的可用性（详见[垃圾回收器](https://nghiant3223.github.io/2025/04/15/go-scheduler.html#garbage-collector)部分）。
3. 1/61 次，检查全局运行队列。
4. 检查关联处理器 `P` 的本地运行队列，如果 `M` 正在运行。
5. 再次检查全局运行队列。
6. 检查 netpoll 是否有 I/O 就绪的 goroutine（详见 [netpoll 工作原理](https://nghiant3223.github.io/2025/04/15/go-scheduler.html#how-netpoll-works)部分）。
7. 从其他处理器 `P1` 的本地运行队列中窃取资源。
8. 再次检查垃圾回收工作程序 goroutine 的可用性。
9. 如果 `M` 正在运行，请再次检查全局运行队列

步骤 1、2 和 8 仅供 Go 运行时内部使用。在步骤 1 中，使用跟踪读取器来跟踪程序的执行情况。稍后您将在 [“Goroutine 抢占”](https://nghiant3223.github.io/2025/04/15/go-scheduler.html#goroutine-preemption) 部分看到它的用法。同时，步骤 2 和 8 允许垃圾回收器与常规 goroutine 并发运行。虽然这些步骤不会对“用户可见”的进度产生影响，但它们对于 Go 运行时的正常运行至关重要。

步骤 3、5 和 9 并非只获取一个 goroutine，而是尝试获取一批 goroutine 以提高效率。批处理大小计算为 `(global_queue_size/number_of_processors)+1` ，但受到几个因素的限制：它不会超过指定的最大参数，也不会超过 P 本地队列容量的一半。确定要获取的 goroutine 数量后，它会弹出一个 goroutine 直接返回（该 goroutine 将立即运行），并将其余的 goroutine 放入 P 的本地运行队列中。这种批处理方法有助于在处理器之间进行负载均衡，并减少对全局队列锁的争用，因为处理器不需要频繁访问全局队列。

步骤 4 稍微复杂一些，因为 `P` 的本地运行队列包含两部分： `runnext` 和 `runq` 。如果 `runnext` 不为空，则返回 `runnext` 中的 goroutine。否则，它会检查 `runq` 是否有可运行的 goroutine 并将其出队。步骤 6 将在 [“netpoll 工作原理”](https://nghiant3223.github.io/2025/04/15/go-scheduler.html#how-netpoll-works) 部分详细描述。

步骤 7 是整个过程中最复杂的部分。它最多会尝试四次从另一个处理器（称为 `P1` 窃取工作。在前三次尝试中，它只尝试从 `P1` 的 `runq` 中窃取 goroutine。如果成功， `P1` `runq` 中一半的 goroutine 会被转移到当前处理器 `P` 的 `runq` 中。在最后一次尝试中，它首先尝试从 `P1` 的 `runnext` 槽（如果可用）中窃取工作，如果仍然无法从中窃取，则回退到 `P1` 的 `runq` 。

请注意， [`findRunnable`](https://github.com/golang/go/blob/go1.24.0/src/runtime/proc.go#L3267-L3646) 不仅能找到可运行的 goroutine，还能唤醒在步骤 1 发生之前进入睡眠状态的 goroutine。goroutine 被唤醒后，将被放入执行它的处理器 `P` 的本地运行队列中，等待被某个线程 `M` 领取并执行。

如果在步骤 9 之后仍未找到 goroutine，线程 `M` 将等待 `netpoll` 返回，直到最近的[定时器](https://github.com/golang/go/blob/go1.24.0/src/runtime/time.go#L35-L107)超时——例如 goroutine 从睡眠状态唤醒时（因为 Go 内部的睡眠操作会创建一个定时器）。为什么 `netpoll` 会与定时器相关？这是因为 Go 的定时器系统严重依赖于 `netpoll` ，正如[这段](https://github.com/golang/go/blob/go1.24.0/src/runtime/time.go#L427-L427)代码注释中所述。netpoll 返回后， `M` 将重新进入[调度循环 ](https://nghiant3223.github.io/2025/04/15/go-scheduler.html#schedule-loop)`netpoll` 再次搜索可运行的 goroutine。

[`findRunnable`](https://github.com/golang/go/blob/go1.24.0/src/runtime/proc.go#L3267-L3646) 的前两个行为允许 Go 调度器唤醒休眠的 goroutine，从而使程序能够继续执行。它们解释了为什么每个 goroutine（包括主 goroutine）在休眠后都有机会运行。我们将在另一篇文章中看看下面的 Go 程序是如何工作的 😄。

```go
package main

import "time"

func main() {
    go func() {
        time.Sleep(time.Second)
    }()
	
    time.Sleep(2*time.Second)
}
```

如果 `P` 没有[定时器 ](https://github.com/golang/go/blob/go1.24.0/src/runtime/time.go#L35-L107)，则其对应的线程 `M` 将处于空闲状态。 `P` 被放入空闲列表， `M` 通过调用 [`stopm`](https://nghiant3223.github.io/2025/04/15/go-scheduler.html#stop-thread-stopm) 函数进入睡眠状态。它会一直保持睡眠状态，直到另一个 `M1` 线程将其唤醒，通常是在创建新的 goroutine 时，如 [“唤醒处理器”](https://nghiant3223.github.io/2025/04/15/go-scheduler.html#waking-up-processor) 部分所述。一旦被唤醒， `M` 会重新进入[调度循环 ](https://nghiant3223.github.io/2025/04/15/go-scheduler.html#schedule-loop)，以查找并执行可运行的 goroutine。





## 参考

本文翻译于 [go-scheduler.html#go-scheduler](https://nghiant3223.github.io/2025/04/15/go-scheduler.html#go-scheduler)