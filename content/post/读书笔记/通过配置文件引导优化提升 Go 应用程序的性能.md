---
title: 通过配置文件引导优化提升 Go 应用程序的性能
description: 
date: 2024-07-12
slug: 
image: 
draft: false
categories:
    - Golang
tags:
    - 读书笔记
    - Golang
---

2023 年，Go 1.21 引入了配置文件引导优化（PGO）。使用 PGO，您可以在运行时向 Go 编译器提供应用程序的配置文件，然后 Go 编译器使用该配置文件就如何在下一个构建中优化代码做出更明智的决策。

Google 和 Uber 的团队从 2021 年开始合作构建 PGO。我们一起尝试了各种优化，以提高计算效率并降低成本。如今，Uber 已在整个车队范围内推出了 PGO，降低了许多服务的 CPU 利用率。阅读更多内容，了解如何在 Go 应用程序中使用 PGO。

## **什么是PGO？**

当您构建 Go 二进制文件时，Go 编译器会执行优化，尝试生成性能最佳的二进制文件。但这并不总是一件容易的事：在许多情况下，过度激进的优化实际上可能会损害性能或导致构建时间过长，需要权衡取舍。在不知道代码在运行时如何使用的情况下，编译器使用静态启发式方法来对代码最常调用的路径进行最佳猜测，然后进行相应的优化。

但是，如果您可以准确地告诉编译器您的代码在运行时如何使用呢？有了 PGO，您就可以做到。如果您在生产中收集应用程序的配置文件，然后在下一个构建中使用此配置文件，编译器可以做出更明智的决策，例如更积极地优化最常用的函数，或更准确地选择函数内的常见情况。

## **在 Go 应用程序中使用 PGO**

使用 PGO 非常简单。只需在运行时收集应用程序的配置文件，然后在下一次构建时向编译器提供配置文件即可。具体做法如下：

1. 导入并启用分析：在 `main` 包中，导入 `net/http/pprof` 包。这会自动将 `/debug/pprof/profile` 端点添加到服务器以获取 CPU 配置文件。

2. 收集配置文件：照常构建您的项目，然后在代表性环境（例如生产、登台）或实际测试条件下运行您的应用程序。当您的应用程序正在运行并经历典型负载时，从您在上一步中创建的服务器端点下载配置文件。例如，如果您的应用程序在本地运行：

   ```bash
   curl -o cpu.pprof "http://localhost:8080/debug/pprof/profile?seconds=30"
   ```

3. 使用配置文件优化您的下一个构建：现在您有了配置文件，您可以在下一个构建中使用它。当 Go 工具链在主包目录中找到名为 `default.pgo` 的配置文件时，它会自动启用 PGO。或者， `go build` 的 `-pgo` 标志采用用于 PGO 的配置文件的路径。我们建议将 `default.pgo` 文件提交到您的存储库，以便用户自动访问该配置文件，并且您的构建保持可重现（并且高性能！）：

   ```bash
   $ mv cpu.pprof default.pgo
   $ go build
   ```

4. 衡量改进：如果您能够复制创建第一个配置文件的条件（例如，使用每秒提供恒定数量查询的负载测试），那么您可以使用优化的构建和收集新的配置文件使用 `go tool pprof` 命令将其与第一个进行比较，以测量 CPU 使用率的减少情况：

   ```bash
   $ go tool pprof -diff_base nopgo.pprof yespgo.pprof
   ```

   有关如何对性能改进进行基准测试的详细示例以及更多信息，请务必查看 Go 博客中的[这篇文章](https://go.dev/blog/pgo) 。您还可以了解 PGO 在幕后的工作原理以及如何在 [Go docs](https://go.dev/doc/pgo) 中生成更强大的分析策略。



## 参考

本文翻译于 [**Boost performance of Go applications with profile-guided optimization**](https://cloud.google.com/blog/products/application-development/using-profile-guided-optimization-for-your-go-apps)