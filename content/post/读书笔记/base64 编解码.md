---
title: Base64 编解码
description: 
date: 2024-07-26
slug: 
image: 
draft: false
categories:
    - Go
tags:
    - 读书笔记

---



## 介绍

Base64 是一种用于将二进制数据转换为文本格式的标准编码。 Base64 通常用于对 JSON、XML 和 HTML 等文本格式的二进制数据进行编码。 Base64 还用于对电子邮件附件中的二进制数据进行编码。

## **Go 中的 Base64 编码**

Encoding 是将数据从一种格式转换为另一种格式的过程。在本例中，我们将二进制数据转换为文本。 `base64` 包提供了 `EncodeToString` 函数，用于将二进制数据编码为 Base64。

```go
package main

import (
    "encoding/base64"
    "fmt"
)

func main(){
    data := []byte("Hello World!")
    encoded := base64.StdEncoding.EncodeToString(data)
    fmt.Println(encoded)
}
// SGVsbG8gV29ybGQh
```

`EncodeToString` 函数将字节切片作为输入并返回字符串。 `StdEncoding` 变量是实现 `Encoding` 接口的 `*Encoding` 类型。 `Encoding` 接口提供 `EncodeToString` 功能。

## **Go 中的 Base64 解码**

Decoding 是将数据从一种格式转换为另一种格式的过程。在本例中，我们将文本转换为二进制数据。 `base64` 包提供了 `DecodeString` 函数，用于将 Base64 解码为二进制数据。

`DecodeString` 函数将字符串作为输入并返回字节切片。 `StdEncoding` 变量是实现 `Encoding` 接口的 `*Encoding` 类型。 `Encoding` 接口提供 `DecodeString` 功能

```go
package main

import (
    "encoding/base64"
    "fmt"
)

func main(){
    data := []byte("SGVsbG8gV29ybGQh")
    decoded, err := base64.StdEncoding.DecodeString(string(data))
    if err != nil {
        fmt.Println(err)
    }
    fmt.Println(string(decoded))
}
// Hello World!
```

## URL编码与解码

`base64` 包提供 `URLEncoding` 变量，用于使用 URL 和文件名安全字母表进行 Base64 编码和解码。 `URLEncoding` 变量是实现 `Encoding` 接口的 `*Encoding` 类型。 `Encoding` 接口提供 `EncodeToString` 和 `DecodeString` 功能。

```go
package main

import (
    "encoding/base64"
    "fmt"
)

func main(){
    data := []byte("Hello World!")
    encoded := base64.URLEncoding.EncodeToString(data)
    fmt.Println(encoded)
    decoded, err := base64.URLEncoding.DecodeString(encoded)
    if err != nil {
        fmt.Println(err)
    }
    fmt.Println(string(decoded))
}
// SGVsbG8gV29ybGQh
// Hello World!
```

该程序的功能与前一个程序相同，但使用 `URLEncoding` 变量而不是 `StdEncoding` 变量。

## 原始编码和解码

`base64` 包提供 `RawStdEncoding` 变量，用于使用标准原始、未填充的 Base64 格式对 Base64 进行编码和解码。 `RawStdEncoding` 变量是实现 `Encoding` 接口的 `*Encoding` 类型。 `Encoding` 接口提供 `EncodeToString` 和 `DecodeString` 功能。

```go
package main

import (
    "encoding/base64"
    "fmt"
)

func main(){
    data := []byte("Hello World!")
    encoded := base64.RawStdEncoding.EncodeToString(data)
    fmt.Println(encoded)
    decoded, err := base64.RawStdEncoding.DecodeString(encoded)
    if err != nil {
        fmt.Println(err)
    }
    fmt.Println(string(decoded))
}
```

当对需要以文本格式存储的二进制数据进行编码时，原始编码和解码非常有用。程序的输出是：

```go
SGVsbG8gV29ybGQh
Hello World!
```

## 示例：编码和解码 JSON 对象

`base64` 包提供了 `EncodeToString` 和 `DecodeString` 函数用于base64编码和解码。 `json` 包提供了 `Marshal` 和 `Unmarshal` 函数来编码和解码 JSON。 `json` 包还提供了 `MarshalIndent` 函数，用于使用缩进编码 JSON。

```go
package main

import (
    "encoding/base64"
    "encoding/json"
    "fmt"
)

type Person struct {
    Name string
    Age int
}

func main(){
    p := Person{
        Name: "John Doe",
        Age: 30,
    }
    data, err := json.MarshalIndent(p, "", "    ")
    if err != nil {
        fmt.Println(err)
    }
    encoded := base64.StdEncoding.EncodeToString(data)
    fmt.Println(encoded)
    decoded, err := base64.StdEncoding.DecodeString(encoded)
    if err != nil {
        fmt.Println(err)
    }
    var p2 Person
    err = json.Unmarshal(decoded, &p2)
    if err != nil {
        fmt.Println(err)
    }
    fmt.Println(p2)
}
// eyJBY2UiOjMwLCJOYW1lIjoiSm9obiBEb2UifQ==
// {30 John Doe}

```

`MarshalIndent` 函数接受一个值并返回一个字节切片。 `MarshalIndent` 函数还采用前缀和缩进字符串。该前缀被添加到输出的每一行之前。缩进字符串用于缩进输出的每个级别。 `MarshalIndent` 函数对于使用缩进编码 JSON 非常有用。

`Unmarshal` 函数采用一个字节切片和一个指向值的指针。 `Unmarshal` 函数对 JSON 编码数据进行解码，并将结果存储在 v 指向的值中。如果 JSON 编码数据不是有效表示， `Unmarshal` 函数将返回错误v 指向的值。

## Base64包中的其他函数

- `NewEncoder` -  返回一个新的 Base64 流编码器。写入返回的 writer，将 base64 数据编码为 w。
- `NewDecoder` - 返回一个新的 Base64 流解码器。从 r 读取解码 Base64 数据到 w。
- `NewEncoding` - 返回由给定字母表定义的新自定义编码，该编码必须是不包含填充字符“=”的 64 字节字符串。
- `RawStdEncoding` - 返回标准原始、未填充的 base64 编码。

## Base64 包中的其他类型

+ `Encoding` - 表示 Base64 编码/解码方案，由 64 个字符的字母表定义。最常见的用法是通过标准预定义编码 StdEncoding 和 URLEncoding。
+ `CorruptInputError` - 报告输入不是有效的 Base64 数据的错误。

## 参考

本文翻译于 [Golang Base64 Encoding and Decoding ](https://www.kelche.co/blog/go/golang-base64/)