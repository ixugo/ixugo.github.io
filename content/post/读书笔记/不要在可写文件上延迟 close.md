---
title: 不要在可写文件上延迟 Close
date: 2024-09-17
slug: 
image: 
draft: false
categories:
    - 翻译
tags:
    - 读书笔记
    - GO
---

对于 Go 程序员来说，这是一个很快就会死记硬背的习惯用法：每当你想出一个实现`io.Closer`接口的值时，在检查错误后，你会立即`defer`其`Close()`方法。在发出 HTTP 请求时最常看到这种情况：

```go
resp, err := http.Get("https://joeshaw.org")
if err != nil {
    return err
}
defer resp.Body.Close()
```

或打开文件：

```go
f, err := os.Open("/home/joeshaw/notes.txt")
if err != nil {
    return err
}
defer f.Close()
```

但这种习惯用法实际上对可写文件有害，因为延迟函数调用会忽略其返回值，并且`Close()`方法可能会返回错误。**对于可写文件，Go 程序员应该避免`defer`习惯用法，否则会出现非常罕见的令人抓狂的错误。**

为什么您会从`Close()`中收到错误，但在之前的`Write()`调用中却没有收到错误？为了回答这个问题，我们需要补充一下计算机体系结构领域知识。

一般来说，当你从 CPU 向外移动时，操作的速度会变得慢几个数量级。写入 CPU 寄存器非常快。访问系统 RAM 相对较慢。进行磁盘或网络 I/O 则慢得多。

如果每个`Write()`调用都将数据同步提交到磁盘，我们系统的性能将会慢得无法使用。虽然同步写入对于某些类型的软件（例如数据库）非常重要，但大多数时候它是多余的。

最糟糕的情况是一次写入一个字节到文件中。硬盘驱动器——粗暴的机械设备——需要将磁头物理移动到盘片上的位置，并可能需要等待整盘的旋转才能将数据持久化。固态硬盘（SSD），它们以块的形式存储数据，并且每个块的写入周期是有限的，会因为块被反复写入和覆盖而迅速磨损。

幸运的是，这种情况不会发生，因为硬件和软件的多个层次实现了缓存和写入缓冲。当你调用 Write() 时，数据不会立即被写入到介质上。操作系统、存储控制器和介质本身都在缓存数据，以便将较小的写入操作批量处理，优化数据在介质上的存储，并决定何时最佳地提交数据。这将我们的写入操作从缓慢的、阻塞的同步操作转变为快速的、异步的操作，这些操作不会直接触及更慢的 I/O 设备。一次写入一个字节从来不是最有效的做法，但至少我们不会因为这样做而耗损硬件。

当然，这些字节最终必须被写入磁盘。操作系统知道当我们关闭一个文件时，我们已经完成了对它的操作，不会有后续的写入操作发生。它还知道关闭文件是它最后一次告诉我们是否出现了问题的机会。

在 Linux 和 macOS 等 POSIX 系统上，关闭文件是通过`close`系统调用来处理的。 `close(2)`的 BSD 手册页讨论了它可能返回的错误：

```bash
ERRORS
     The close() system call will fail if:

     [EBADF]            fildes is not a valid, active file descriptor.

     [EINTR]            Its execution was interrupted by a signal.

     [EIO]              A previously-uncommitted write(2) encountered an input/output
                        error.
```

EIO 正是我们担心的错误。这意味着我们在尝试将数据保存到磁盘时丢失了数据，我们的 Go 程序在这种情况下绝对不应返回 nil 错误。

解决这个问题最简单的方法就是在写入文件时不使用`defer` ：

```go
func helloNotes() error {
    f, err := os.Create("/home/joeshaw/notes.txt")
    if err != nil {
        return err
    }

    if err = io.WriteString(f, "hello world"); err != nil {
        f.Close()
        return err
    }

    return f.Close()
}
```

这确实意味着在出现错误时需要对文件进行额外的记录：在`io.WriteString()`失败的情况下，我们必须显式关闭它（并忽略它的错误，因为写入错误优先）。但它很清晰、直接，并且可以正确检查`f.Close()`调用中的错误。

*有*一种方法可以通过使用命名返回值和闭包`defer`处理这种情况：

```go
func helloNotes() (err error) {
    var f *os.File
    f, err = os.Create("/home/joeshaw/notes.txt")
    if err != nil {
        return
    }

    defer func() {
        cerr := f.Close()
        if err == nil {
            err = cerr
        }
    }()

    err = io.WriteString(f, "hello world")
    return
}
```

此模式的主要好处是不可能忘记关闭文件，因为延迟关闭始终会执行。在具有更多`if err != nil`条件分支的较长函数中，此模式还可以减少代码行数和重复次数。

尽管如此，我还是觉得这种模式有点魔法了。我不喜欢使用命名返回值，并且即使对于经验丰富的 Go 程序员来说，在核心函数完成后修改返回值也不是直观上清楚的。

我愿意接受更具可读性和易于理解的代码的权衡，因为需要不断地审查代码以确保文件在所有情况下都已关闭，这就是我在向其他人提供的代码审查中推荐的方法。

**更新 1**

[Ben Johnson 在 Twitter 上建议](https://twitter.com/benbjohnson/status/874286396411961345)，对文件多次运行`Close()`可能是安全的，如下所示：

```go
func doSomething() error {
    f, err := os.Create("foo")
    if err != nil {
        return err
    }
    defer f.Close()

    if _, err := f.Write([]byte("bar"); err != nil {
        return err
    }

    return f.Close()
}
```

`io.Closer`上的 Go 文档[明确指出](https://golang.org/pkg/io/#Closer)，在第一次调用后的接口级别行为是未指定的，但特定的实现可能会记录其自己的行为。

不幸的是， `*os.File`的文档[并不清楚](https://golang.org/pkg/os/#File.Close)它的行为，只是说，“Close 关闭文件，使其无法用于 I/O。如果有的话，它会返回一个错误。”然而，从 1.8 开始的实现显示：

```go
func (f *File) Close() error {
    if f == nil {
        return ErrInvalid
    }
    return f.file.close()
}

func (file *file) close() error {
    if file == nil || file.fd == badFd {
        return syscall.EINVAL
    }
    var err error
    if e := syscall.Close(file.fd); e != nil {
        err = &PathError{"close", file.name, e}
    }
    file.fd = -1 // so it can't be closed again

    // no need for a finalizer anymore
    runtime.SetFinalizer(file, nil)
    return err
}
```

为了清楚起见， `badFd`被定义为 -1 ，因此随后尝试关闭`*os.File`将不会执行任何操作并返回`syscall.EINVAL` 。但由于我们忽略了`defer`的错误，所以这并不重要。确切地说，它不是幂等的，但正如 Ben 后来在 Twitter 帖子中所说的那样， [“won’t blow shit up if you call it twice.”](https://twitter.com/benbjohnson/status/874289044800368640)

**更新 2**

关闭文件是操作系统告诉我们问题的最后机会，但关闭文件时缓冲区不一定会被刷新。关闭文件*后*完全有可能将写入缓冲区刷新到磁盘，并且无法捕获其中的故障。如果发生这种情况，通常意味着出现严重错误，例如磁盘出现故障。

但是，您可以使用`*os.File`上的`Sync()`方法强制写入磁盘，该方法调用`fsync`系统调用。您应该检查该调用中的错误，但我认为忽略`Close()`中的错误是安全的。调用`fsync`对性能有严重影响：它将写入缓冲区刷新到速度较慢的磁盘。但如果您真的非常想要将数据存储在磁盘上，那么最好遵循的模式可能是：

```go
func helloNotes() error {
    f, err := os.Create("/home/joeshaw/notes.txt")
    if err != nil {
        return err
    }
    defer f.Close()

    if err = io.WriteString(f, "hello world"); err != nil {
        return err
    }

    return f.Sync()
}
```

