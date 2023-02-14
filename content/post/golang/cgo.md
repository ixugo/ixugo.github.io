---
title: CGO 编程
description: 
date: 2022-11-24
slug: 
image: 
draft: true
categories:
    - Golang
tags:
    - Go
    - C
---



# CGO

## 前言

CGO 和 Go 语言是两码事:

+ 构建时间变成
+ 复杂的构造
+ 不支持交叉编译
+ 失去了通向 Go 工具的大门 ((竞争分析/性能分析/覆盖率/模糊测试...))
+ 性能问题
+ C 是主导，这是C的世界，你只是在其上生存。
+ 部署变得更复杂，

请明智地选择，在使用 CGO 之前，请仔细考虑同时要放弃的 Go 的优点。

## CGO 基础

`CGO_ENABLED` 环境变量用于控制是否启用 CGO，本地构建时默认是启用的，交叉编译默认是禁用的。

### 一个简单的 CGO Demo

```c
package main

/*
#include <stdio.h>

void printint(int v) {
    printf("printint: %d\n", v);
}
*/
import "C"

func main() {
    v := 42
    C.printint(C.int(v))
}

```

`import "C"` 表示使用 CGO 特性，紧跟这行上面的注释是特殊语法，包含 C 语言代码，也可以在目录中包含`c/c+` 源文件。

Go 是强类型语言，所以 cgo 中传递的参数类型必须与声明的类型完全一致，而且传递前必须用”C” 中的转化函数转换成对应的 C 类型，不能直接传入 Go 中类型的变量。同时通过虚拟的 C 包导入的 C 语言符号并不需要是大写字母开头，它们不受 Go 语言的导出规则约束。

Go 语言每个依赖包导入的虚拟 C 包，类型不能通用。

### 类型

`_cgo_export.h` 头文件生成了 Go 数值类型的定义

```c
typedef signed char GoInt8;
typedef unsigned char GoUint8;
typedef short GoInt16;
....
```

C99 标准引入了 `<stdint.h>`，为了提高 C 语言的可移植性，在 `<stdint.h>` 文件中，不但每个数值类型都提供了明确内存大小，而且和 Go 语言的类型命名更加一致。







