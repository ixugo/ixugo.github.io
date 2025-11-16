---
title: Efficient go
description: 
date: 2023-02-22
slug: 
image: 
draft: true
categories:
    - 读书笔记
tags:
    - Go
---



# Efficient Go

`<Efficient Go>` 读书笔记

### 多次调用函数

```go
func FailureRatio(reports ReportGetter) float64 { 
   if len(reports.Get()) == 0 { 
      return 0
   }
   var sum float64
   for _, report := range reports.Get() { 
      if report.Error() != nil {
         sum++
      }
   }
   return sum / float64(len(reports.Get())) 
}
```

缺点是 3 次调用 reports.Get()。

不能总是假设该函数调用总是快速且廉价，可能别的开发者将会修改此函数，针对昂贵的 I/O 操作，数据库远程调用之类的。

如果 ReportGetter 随时间动态更改，可能三次函数调用拿到的是不同结果，不安全。

在函数开始，加一行 `got := reports.Get()`，调用 3 个函数替换成一个简单的变量，极大程度的减少了潜在的副作用。

### 在 for 循环中对切片 append

```go
func createSlice(n int) (slice []string) { 
   for i := 0; i < n; i++ {
      slice = append(slice, "I", "am", "going", "to", "take", "some", "space") 
   }
   return slice
}
```

缺点: 返回名为 slice 的命名参数，将会函数调用开始创建一个空字符串切片的变量。每次循环 append 有可能导致扩容。

如果能够确切的知道需要多大容量，在函数开头加一行 `slice := make([]string, 0, n*7)`，由于初始化时预分配，append 实现不需要逐步扩展内存中的切片大小。

### 如何使高效代码更具可读性

+ 删除或避免不必要的优化
+ 将复杂的代码封装到清晰的抽象后面
+ 将 "热" 代码与 "冷"代码分开。

XP (极限编程) 最广为人知的原则之一是你不会需要它原则，它强调了在投资回报不确定的事情下，延迟投资决策。

假设你想到过河到对岸去，你可以乘坐一辆快车，沿着下游找到附近的桥，快速达到对岸。但如果你跳进水里，慢慢游过河，你会更快到达对岸。如果高效完成较慢的动作，例如选择最短的路线，提高行驶性能，更快的车，改善路面以减少阻力，是可能击败游泳者，但这些剧烈的变化可能比简单做更少的工作更昂贵。





























