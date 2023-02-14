---
title: Go 函数式编程
description: 
date: 2020-05-22 15:00:00
slug: 
image: 
draft: false
categories:
    - Golang
tags:
    - Go进阶
---

# Go 函数式编程

核心概念

+ 纯函数
+ 函数复合
+ 避免共享状态
+ 避免改变状态
+ 避免副作用

## 说明

**纯函数**

+ 相同的输入总是返回相同的输出
+ 不产生副作用
+ 不依赖于外部状态

```go
// 非函数式
num1,num2 := 2,3
sum := num1 + num2

// 函数式
func add (n1, n2 int) int {  
    return n1 + n2
}
sum1 := add(2, 3)

```



**共享状态**

任意变量/对象或者内存空间存在于共享作用域，函数式编程避免共享状态

**避免改变状态**

函数式编程只返回新的值，不修改变量

**副作用**

包括

+ 改变任何外部变量或对象属性
+ 写入文件
+ 发网络请求
+ 在屏幕调用输出
+ 调用另一个有副作用得很局数

**声明式与命令式**

+ 命令式: 大量代码描述来达成期望结果， How to do
+ 声明式: 抽象控制流过程，大量代码描述数据流，What to do

```go
// 命令式
list := []int{1,2,3,4,5}
list2 := make([]int,len(list))
for i,v := range list{
  list2[i] = v*2
}
```

```go
// 声明式
```

**柯里化**

柯里化是将一个多参数函数转换成多个单参数函数。

```go
// 柯里化之前
func add(x, y int) int {
  return x + y
}

add(1, 2) // 3

// 柯里化之后
func addX(y) func (x) int {
  return function (x) int {
    return x + y
  }
}

addX(2)(1) // 3
```

