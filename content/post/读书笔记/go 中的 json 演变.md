---
title: Go 中的 JSON 演变, 从 v1 到 v2
description: 
date: 2025-06-29
slug: 
image: 
draft: false
categories:
    - Go
tags:
    - 读书笔记
    - 翻译
---



Go 1.25 中 `json` 包的 v2 版本是一个重大更新，它有很多突破性的变化。v2 包添加了新功能，修复了 API 问题和行为缺陷，并提高了性能。让我们来看看发生了什么变化！

`Marshal` 和 `Unmarshal` 的基本用例保持不变。此代码适用于 v1 和 v2：

```go
type Person struct {
    Name string
    Age  int
}

alice := Person{Name: "Alice", Age: 25}

// Marshal Alice.
b, err := json.Marshal(alice)
fmt.Println(string(b), err)

// Unmarshal Alice.
err = json.Unmarshal(b, &alice)
fmt.Println(alice, err)
```

但其余的则大不相同。

## MarshalWrite and UnmarshalRead

在 v1 中，是这样的

```go
// Marshal Alice.
alice := Person{Name: "Alice", Age: 25}
out := new(strings.Builder) // io.Writer
enc := json.NewEncoder(out)
enc.Encode(alice)
fmt.Println(out.String())

// Unmarshal Bob.
in := strings.NewReader(`{"Name":"Bob","Age":30}`) // io.Reader
dec := json.NewDecoder(in)
var bob Person
dec.Decode(&bob)
fmt.Println(bob)
```

在 v2 中，可以直接使用  `MarshalWrite` 和 `UnmarshalRead`，无需任何中介：

```go
// Marshal Alice.
alice := Person{Name: "Alice", Age: 25}
out := new(strings.Builder)
json.MarshalWrite(out, alice)
fmt.Println(out.String())

// Unmarshal Bob.
in := strings.NewReader(`{"Name":"Bob","Age":30}`)
var bob Person
json.UnmarshalRead(in, &bob)
fmt.Println(bob)
```

不过，它们不能互换：

+ 与旧的 `Encoder.Encode` 不同，`MarshalWrite` 不添加换行符。
+ `UnmarshalRead` 会读取读取器中的所有内容，直到它到达 `io。EOF`，而旧的 `Decoder.Decode` 仅读取下一个 JSON 值。

## MarshalEncode and UnmarshalDecode

`Encoder` 和 `Decoder` 类型已移至新的 [`jsontext`](https://pkg.go.dev/encoding/json/jsontext) 包中，它们的接口已发生重大变化（以支持低级流式编码/解码作）。

你可以将它们与 `json` 函数一起使用来读取和写入 JSON 流，类似于之前 `Encode` 和 `Decode` 的工作方式：

+ v1 `Encoder.Encode` → v2 `json.MarshalEncode` + `jsontext.Encoder`.
+ v1 `Decoder.Decode` → v2 `json.UnmarshalDecode` + `jsontext.Decoder`.

流式处理编码器：

```go
people := []Person{
    {Name: "Alice", Age: 25},
    {Name: "Bob", Age: 30},
    {Name: "Cindy", Age: 15},
}
out := new(strings.Builder)
enc := jsontext.NewEncoder(out)

for _, p := range people {
    json.MarshalEncode(enc, p)
}

fmt.Print(out.String())
```

流式解码器：

```go
in := strings.NewReader(`
    {"Name":"Alice","Age":25}
    {"Name":"Bob","Age":30}
    {"Name":"Cindy","Age":15}
`)
dec := jsontext.NewDecoder(in)

for {
    var p Person
    // Decodes one Person object per call.
    err := json.UnmarshalDecode(dec, &p)
    if err == io.EOF {
        break
    }
    fmt.Println(p)
}
```

与 `UnmarshalRead` 不同，`UnmarshalDecode` 以完全流式处理的方式工作，每次调用一次解码一个值，而不是读取所有内容直到 `io.EOF`.

## 选项

选项使用特定功能配置编组和解组功能：

+ `FormatNilMapAsNull` 和 `FormatNilSliceAsNull` 定义如何编码 nil 映射和切片。
+ `MatchCaseInsensitiveNames` 允许匹配 `Name` ↔ `name` 等。
+ `Multiline` 将 JSON 对象扩展为多行。
+ `OmitZeroStructFields` 从输出中省略具有零值的字段。
+ `SpaceAfterColon` 和 `SpaceAfterComma` 在每个 `:` 或 `,` 后添加一个空格
+ `StringifyNumbers` 将数字类型表示为字符串。
+ `WithIndent` 和 `WithIndentPrefix` 缩进嵌套属性（请注意， `MarshalIndent` 函数已被删除）。

每个编组或解组函数可以采用任意数量的选项：

```go
alice := Person{Name: "Alice", Age: 25}
b, _ := json.Marshal(
    alice,
    json.OmitZeroStructFields(true),
    json.StringifyNumbers(true),
    jsontext.WithIndent("  "),
)
fmt.Println(string(b))
```

还可以将选项与 `JoinOptions` 组合：

```go
alice := Person{Name: "Alice", Age: 25}
opts := json.JoinOptions(
    jsontext.SpaceAfterColon(true),
    jsontext.SpaceAfterComma(true),
)
b, _ := json.Marshal(alice, opts)
fmt.Println(string(b))
```

请参阅文档中的完整选项列表：一些位于 [`json`](https://pkg.go.dev/encoding/json/v2#Options) 包中，其他位于 [`jsontext`](https://pkg.go.dev/encoding/json/jsontext#Options) 包中。

## Tags

v2 支持 v1 中定义的字段标签：

+ `omitzero` 和 `omitempty` 省略空值，`omitempty` 是 `go1.24` 之前用于省略 nil 对象的，`omitzero` 是 `go1.24` 加入用于省略零值对象。
+ `string` 将数字类型表示为字符串。
+ `-` 忽略字段。

并添加了一些：

- `case:ignore` 或 `case:strict` 指定如何处理大小写差异。
- `format:template` 根据模板格式化字段值。
- `inline` 通过将嵌套对象的字段提升到父级来展平输出。
- `unknown` 为未知字段提供了“全部捕获”。

下面是一个演示 `inline` 和 `format` 示例：

匿名属性一样有 `inline` 的效果。

```go
type Person struct {
    Name string         `json:"name"`
    // Format date as yyyy-mm-dd.
    BirthDate time.Time `json:"birth_date,format:DateOnly"`
    // Inline address fields into the Person object.
    Address             `json:",inline"`
}

type Address struct {
    Street string `json:"street"`
    City   string `json:"city"`
}

func main() {
    alice := Person{
        Name: "Alice",
        BirthDate: time.Date(2001, 7, 15, 12, 35, 43, 0, time.UTC),
        Address: Address{
            Street: "123 Main St",
            City:   "Wonderland",
        },
    }
    b, _ := json.Marshal(alice, jsontext.WithIndent("  "))
    fmt.Println(string(b))
}

//{
//  "name": "Alice",
//  "birth_date": "2001-07-15",
//  "street": "123 Main St",
//  "city": "Wonderland"
//}
```

`unknown`  用于将结构体中未定义的内容，在反序列化时收束到此，搭配 `map[string]any` 使用。

```go
type Person struct {
    Name string         `json:"name"`
    // Collect all unknown Person fields
    // into the Data field.
    Data map[string]any `json:",unknown"`
}

func main() {
    src := `{
        "name": "Alice",
        "hobby": "adventure",
        "friends": [
            {"name": "Bob"},
            {"name": "Cindy"}
        ]
    }`
    var alice Person
    json.Unmarshal([]byte(src), &alice)
    fmt.Println(alice)
}
// {Alice map[friends:[map[name:Bob] map[name:Cindy]] hobby:adventure]}

```

## 自定义marshaling

使用 `Marshaler` 和 `Unmarshaler` 接口进行自定义封送处理的基本用例保持不变。以下代码在 v1 和 v2 版本中均有效：

```go
// A custom boolean type represented
// as "✓" for true and "✗" for false.
type Success bool

func (s Success) MarshalJSON() ([]byte, error) {
    if s {
        return []byte(`"✓"`), nil
    }
    return []byte(`"✗"`), nil
}

func (s *Success) UnmarshalJSON(data []byte) error {
    // Data validation omitted for brevity.
    *s = string(data) == `"✓"`
    return nil
}

func main() {
    // Marshaling.
    val := Success(true)
    data, err := json.Marshal(val)
    fmt.Println(string(data), err)

    // Unmarshaling.
    src := []byte(`"✓"`)
    err = json.Unmarshal(src, &val)
    fmt.Println(val, err)
}
```

但是，Go 标准库文档建议使用新的 `MarshalerTo` 和 `UnmarshalerFrom` 接口（它们以纯流方式工作，速度更快）：

```go
// A custom boolean type represented
// as "✓" for true and "✗" for false.
type Success bool

func (s Success) MarshalJSONTo(enc *jsontext.Encoder) error {
    if s {
        return enc.WriteToken(jsontext.String("✓"))
    }
    return enc.WriteToken(jsontext.String("✗"))
}

func (s *Success) UnmarshalJSONFrom(dec *jsontext.Decoder) error {
    // Data validation omitted for brevity.
    tok, err := dec.ReadToken()
    *s = tok.String() == `"✓"`
    return err
}

func main() {
    // Marshaling.
    val := Success(true)
    data, err := json.Marshal(val)
    fmt.Println(string(data), err)

    // Unmarshaling.
    src := []byte(`"✓"`)
    err = json.Unmarshal(src, &val)
    fmt.Println(val, err)
}
```

更棒的是，不再局限于只使用一种特定类型的 marshaling 方式。现在，您可以随时通过通用的 `MarshalFunc` 和 `UnmarshalFunc` 函数使用自定义的 marshalers and unmarshalers。

```go
func MarshalFunc[T any](fn func(T) ([]byte, error)) *Marshalers
func UnmarshalFunc[T any](fn func([]byte, T) error) *Unmarshalers
```

例如，可以将 `bool` 值编组为 `✓` 或 `✗` 而无需创建自定义类型：

```go
// Custom marshaler for bool values.
boolMarshaler := json.MarshalFunc(
    func(val bool) ([]byte, error) {
        if val {
            return []byte(`"✓"`), nil
        }
        return []byte(`"✗"`), nil
    },
)

// Pass the custom marshaler to Marshal
// using the WithMarshalers option.
val := true
data, err := json.Marshal(val, json.WithMarshalers(boolMarshaler))
fmt.Println(string(data), err)
```

并将 `✓` 或 `✗` 解组为 `bool` ：

```go
// Custom unmarshaler for bool values.
boolUnmarshaler := json.UnmarshalFunc(
    func(data []byte, val *bool) error {
        *val = string(data) == `"✓"`
        return nil
    },
)

// Pass the custom unmarshaler to Unmarshal
// using the WithUnmarshalers option.
src := []byte(`"✓"`)
var val bool
err := json.Unmarshal(src, &val, json.WithUnmarshalers(boolUnmarshaler))
fmt.Println(val, err)
```

还有 `MarshalToFunc` 和 `UnmarshalFromFunc` 函数用于创建自定义编组器。它们与 `MarshalFunc` 和 `UnmarshalFunc` 类似，但它们与 `jsontext.Encoder` 和 `jsontext.Decoder` 一起使用，而不是字节切片。

```go
func MarshalToFunc[T any](fn func(*jsontext.Encoder, T) error) *Marshalers
func UnmarshalFromFunc[T any](fn func(*jsontext.Decoder, T) error) *Unmarshalers
```

可以使用 `JoinMarshalers` 组合 marshalers（并使用 `JoinUnmarshalers` 组合unmarshalers）。例如，以下示例展示了如何将布尔值（ `true` / `false` ）和“类布尔”字符串（ `on` / `off` ）封送为 `✓` 或 `✗` ，同时保留所有其他值的默认封送方式。

首先，我们为布尔值定义一个自定义 marshaler：

```go
// Marshals boolean values to ✓ or ✗..
boolMarshaler := json.MarshalToFunc(
    func(enc *jsontext.Encoder, val bool) error {
        if val {
            return enc.WriteToken(jsontext.String("✓"))
        }
        return enc.WriteToken(jsontext.String("✗"))
    },
)
```

然后我们为布尔字符串定义一个自定义 marshaler：

```go
// Marshals boolean-like strings to ✓ or ✗.
strMarshaler := json.MarshalToFunc(
    func(enc *jsontext.Encoder, val string) error {
        if val == "on" || val == "true" {
            return enc.WriteToken(jsontext.String("✓"))
        }
        if val == "off" || val == "false" {
            return enc.WriteToken(jsontext.String("✗"))
        }
        // SkipFunc is a special type of error that tells Go to skip
        // the current marshaler and move on to the next one. In our case,
        // the next one will be the default marshaler for strings.
        return json.SkipFunc
    },
)
```

最后，我们将编组器与 `JoinMarshalers` 结合起来，并使用 `WithMarshalers` 选项将它们传递给编组函数：

```go
// Combine custom marshalers with JoinMarshalers.
marshalers := json.JoinMarshalers(boolMarshaler, strMarshaler)

// Marshal some values.
vals := []any{true, "off", "hello"}
data, err := json.Marshal(vals, json.WithMarshalers(marshalers))
fmt.Println(string(data), err)
// ["✓","✗","hello"] <nil>
```

这不是很酷吗？

## 默认行为

v2 不仅改变了包接口，还改变了默认的编组/解组行为。

一些值得注意的**编组差异**包括：

+ v1 将 nil 切片封送为 `null` ，v2 则封送为 `[]` 。您可以使用`FormatNilSliceAsNull` 选项进行更改。
+ v1 将 nil map 封送为 `null` ，v2 则将其封送为 `{}` 。您可以使用 `FormatNilMapAsNull` 选项进行更改。
+ v1 将字节数组编组为数字数组，v2 则将其编组为 base64 编码的字符串。您可以使用 `format:array` 和 `format:base64` 标签进行更改。
+ v1 允许字符串中包含无效的 UTF-8 字符，而 v2 则不允许。您可以使用 `AllowInvalidUTF8` 选项进行更改。

以下是默认 v2 行为的示例：

```go
type Person struct {
    Name    string
    Hobbies []string
    Skills  map[string]int
    Secret  [5]byte
}

func main() {
    alice := Person{
        Name:    "Alice",
        Secret: [5]byte{1, 2, 3, 4, 5},
    }
    b, _ := json.Marshal(alice, jsontext.Multiline(true))
    fmt.Println(string(b))
}
//{
//    "Name": "Alice",
//    "Hobbies": [],
//    "Skills": {},
//    "Secret": "AQIDBAU="
//}
```

以下是强制执行 v1 行为的方法：

```go
type Person struct {
    Name    string
    Hobbies []string
    Skills  map[string]int
    Secret  [5]byte `json:",format:array"`
}

func main() {
    alice := Person{
        Name:    "Alice",
        Secret: [5]byte{1, 2, 3, 4, 5},
    }
    b, _ := json.Marshal(
        alice,
        json.FormatNilMapAsNull(true),
        json.FormatNilSliceAsNull(true),
        jsontext.Multiline(true),
    )
    fmt.Println(string(b))
}
// {
//     "Name": "Alice",
//     "Hobbies": null,
//     "Skills": null,
//     "Secret": [
//         1,
//         2,
//         3,
//         4,
//         5
//     ]
// }
```

一些值得注意的**解组差异**包括：

+ v1 版本使用不区分大小写的字段名称匹配，v2 版本则使用精确匹配，区分大小写。您可以使用 `MatchCaseInsensitiveNames` 选项或 `case` 标签进行更改。
+ v1 版本允许对象中存在重复字段，而 v2 版本则不允许。您可以使用 `AllowDuplicateNames` 选项进行更改。

以下是默认 v2 行为（区分大小写）的示例：

```go
type Person struct {
    FirstName string
    LastName  string
}

func main() {
    src := []byte(`{"firstname":"Alice","lastname":"Zakas"}`)
    var alice Person
    json.Unmarshal(src, &alice)
    fmt.Printf("%+v\n", alice)
}
// {FirstName: LastName:}
```

以下是强制执行 v1 行为的方法（不区分大小写）：

```go
type Person struct {
    FirstName string
    LastName  string
}

func main() {
    src := []byte(`{"firstname":"Alice","lastname":"Zakas"}`)
    var alice Person
    json.Unmarshal(
        src, &alice,
        json.MatchCaseInsensitiveNames(true),
    )
    fmt.Printf("%+v\n", alice)
}
// {FirstName:Alice LastName:Zakas}
```

请参阅[文档](https://pkg.go.dev/encoding/json@master#hdr-Migrating_to_v2)中的行为变化的完整列表。

## 表现

编组 (Marshaling) 时，v2 的性能与 v1 大致相同。对于某些数据集，它的速度更快，但对于其他数据集，它的速度较慢。然而，解组 (Unmarshaling) 的性能要*好得多* ：v2 比 v1 快 2.7 倍到 10.2 倍。

此外，从常规的 `MarshalJSON` 和 `UnmarshalJSON` 切换到其流式替代方案—— `MarshalJSONTo` 和 `UnmarshalJSONFrom` ，可以获得显著的性能提升。据 Go 团队称，它允许将某些 O(n²) 的运行时场景转换为 O(n)。例如，在 Kubernetes OpenAPI 规范中，从 `UnmarshalJSON` 切换到 `UnmarshalJSONFrom` 使其[速度提高了约 40 倍 ](https://github.com/kubernetes/kube-openapi/issues/315#issuecomment-1240030015)。

有关基准测试的详细信息，请参阅 [jsonbench](https://github.com/go-json-experiment/jsonbench#readme) repo。

## 最后的想法

呼！这可真是让人费解。v2 包比 v1 功能更多、更灵活，但也复杂得多，尤其是拆分成了 `json/v2` 和 `jsontext` 两个子包之后。

需要记住以下几点：

+ 从 Go 1.25 开始， `json/v2` 包处于实验阶段，可以通过在构建时设置 `GOEXPERIMENT=jsonv2` 来启用。该包的 API 可能会在未来的版本中发生变化。
+ 开启 `GOEXPERIMENT=jsonv2` 会使 v1 `json` 包使用新的 JSON 实现，速度更快，并支持一些选项，以便更好地兼容旧的编组和解组行为。

最后，这里有一些链接可以了解有关 v2 设计和实现的更多信息：

[proposal p.1](https://go.dev/issue/63397) • [proposal p.2](https://go.dev/issue/71497) • [json/v2](https://github.com/golang/go/tree/master/src/encoding/json/v2) • [jsontext](https://github.com/golang/go/tree/master/src/encoding/json/jsontext)

## 参考

本文翻译于 [JSON evolution in Go: from v1 to v2](https://antonz.org/go-json-v2/#marshalencode-and-unmarshaldecode)

