---
title: JSON
description: 在 Go 语言中使用 JSON 的小细节
date: 2023-01-12 16:11:45
slug: 
image: 
draft: false
categories:
    - Golang
tags:
    - 读书笔记
    - Go
---

# JSON

### JSON charset

web 响应要指定 `Content-Type`，你可能见过 `Content-Type: application/json; charset=utf-8`

在 [RFC](https://tools.ietf.org/html/rfc8259#section-8.1) 中指出:

> JSON text exchanged between systems that are not part of a closed ecosystem MUST be 
> encoded using UTF-8.

面向公众的应用程序必须始终采用 UTF-8 编码，所以不需要标注字符集，`Content-Type: application/json` 即可

### JSON encode

![image-20230111162609606](http://img.golang.space/img-1673425569748.png)

+ time.Time 值将会被编码为 RFC 3339 格式的字符串，例如`"2020-11-08T06:27:59+01:00"`
+ []byte 切片将被编码为 base64 字符串
+ 无法对 channel/function/complex 进行编码，如果这样做，在运行时将会得到 ` json.UnsupportedTypeError `的错误
+ 任意指针都编码为指向的值

如果你有一个 `io.Writer` ，可以使用 `err := json.NewEncoder(w).Encode(data) `直接写入。

### `json.Encoder` 和 `json.Marshal()` 性能差异

![image-20230111175340730](http://img.golang.space/img-1673430820853.png)

json.Marshal()  比 json.Encoder 多一次堆内存分配。

### 嵌套结构体序列化不会 omitempty

```go
type A struct{
  b struct{
    Bar string `json:",omitempty"`
  } `json:",omitempty"`
}
```

结构体为值类型，不存在 nil 的情况，所以不会 omitempty。

如果需要省略，建议替换成 pointer。

## 转义字符

如果字符串中包含 `<>&` 字符，将会转义成 unicode，这是为了防止某些 web 浏览器意外解释 JSON 响应为 HTML，如果不需要转义，使用 `json.Encoder`  `SetEscapeHTML(false)` 执行编码。

| 转义字符 | unicode |
| -------- | ------- |
| <        | \u003c  |
| >        | \u003e  |
| &        | \u0026  |

### 删除 float 小数点末尾的 0

```go
s := []float64{
123.0, 
456.100, 
789.990,
}
```

编码后将得到

```json
[123,456.1,789.99]
```

### 预编码 JSON

如果你有一个包含预编码的 string 或者 []byte，使用 JSON tag 将会被转义并编码为 json 字符串

```go
m := struct { 
	Person string
}{
	Person: `{"name": "Alice", "age": 21}`, 
}
```

编码后得到

```json
{"Person":"{\"name\": \"Alice\", \"age\": 21}"}
```

如果想插入 JSON 而非 JSON 字符串，可以使用 `json.RawMessage`

```go
m := struct {
	Person json.RawMessage 
}{
	Person: json.RawMessage(`{"name": "Alice", "age": 21}`), 
}
```

编码后得到

```json
{"Person":{"name":"Alice","age":21}}
```

使用 `json.RawMessage` 要确保预编码的值是有效的 JSON，否则会出错。如果需要在运行时检查 JSON  是否有效，可以使用 `json.Valid()` 函数

### MarshalText

如果类型有没有 `MarshalJSON()` 方法，但是有 `MarshalText()` 方法，以实现 ` encoding.TextMarshaler` 接口，使用 JSON 编码将会显示 json 字符串。

```go
type myFloat float64
func (f myFloat) MarshalText() ([]byte, error) { 
	return []byte(fmt.Sprintf("%.2f", f)), nil
}
func main() {
	f := myFloat(1.0/3.0)
	js, err := json.Marshal(f) 
	if err != nil {
		log.Fatal(err) 
	}
	fmt.Printf("%s", js) 
}
```

它将会打印由 `MarshalText()` 函数返回的 JSON 字符串

```json
0.33
```

### MarshalJSON 的接收器

当自定义类型实现了 MarshalJSON()，并使用 pointer 接收器时，仅传递指针时函数有效。

> 关于接收器的指针与值的规则是:
>
> 值方法可以用指针或值调用，但指针方法只能在指针上调用。

```bash
type myFloat float64

// This has a pointer receiver.
func (f *myFloat) MarshalJSON() ([]byte, error) {
	return []byte(fmt.Sprintf("%.2f", *f)), nil
}

func main() {
	f := myFloat(1.0 / 3.0)

	// When encoding a value, the MarshalJSON method is used.
	// 得到 0.33
	js, err := json.Marshal(&f)
	if err != nil {
		log.Fatal(err)
	}

	fmt.Printf("%s\n", js)

	// When encoding a value, the MarshalJSON method is ignored.
	// 得到默认的 0.3333333333333333
	js, err = json.Marshal(f)
	if err != nil {
		log.Fatal(err)
	}

	fmt.Printf("%s", js)
}
```

### 部分 JSON 解码

如果你只需要处理 JSON 中的一小部分

```go
// Let's say that the only thing we're interested in is processing the "genres" array in 
// the following JSON object
js := `{"title": "Top Gun", "genres": ["action", "romance"], "year": 1986}`
// Decode the JSON object to a map[string]json.RawMessage type. The json.RawMessage 
// values in the map will retain their original, un-decoded, JSON values.
var m map[string]json.RawMessage
err := json.NewDecoder(strings.NewReader(js)).Decode(&m) 
if err != nil {
log.Fatal(err) 
}
// We can then access the JSON "genres" value from the map and decode it as normal using 
// the json.Unmarshal() function.
var genres []string
err = json.Unmarshal(m["genres"], &genres) 
if err != nil {
log.Fatal(err) 
}
fmt.Printf("genres: %v\n", genres)
```

解码后得到

```bash
genres: [action romance]
```

### 解码成任意类型

![image-20230112102209838](http://img.golang.space/img-1673490129979.png)

解码成任意类型在以下情况很有用

+ 事先不知道解码的是什么
+ 需要解码包含不同类型的的 array/map

数字解码到任意类型时，为 float64 ，即使它是整数。

如果想获得整数形式(而非 float64)，应该在 `json.Decoder` 实例使用 `UseNumber()` 方法，将会导致解码为 `json.Number` 类型。

```go
js := `10` 
var n any
dec := json.NewDecoder(strings.NewReader(js))
dec.UseNumber() // Call the UseNumber() method on the decoder before using it. 
err := dec.Decode(&n)
if err != nil { 
	log.Fatal(err)
}
// Type assert the any value to a json.Number, and then call the Int64() method 
// to get the number as a Go int64.
nInt64, err := n.(json.Number).Int64() 
if err != nil {
	log.Fatal(err) 
}
// Likewise, you can use the String() method to get the number as a Go string. 
nString := n.(json.Number).String()
fmt.Printf("type: %T; value: %v\n", n, n)
fmt.Printf("type: %T; value: %v\n", nInt64, nInt64)
fmt.Printf("type: %T; value: %v\n", nString, nString)
```

out:

```bash
type: json.Number; value: 10
type: int64; value: 10
type: string; value: 10
```

### struct tag 指令

| 指令                       | 说明                                       | 备注                         |
| -------------------------- | ------------------------------------------ | ---------------------------- |
| `json:"-"`                 | 编解码时忽略( 属性名首字母小写也可以忽略 ) |                              |
| `json:",omitempty"`        | 解码时为零值则忽略                         | 嵌套结构体无效               |
| `json:",omitempty,string"` | 以字符串类型编解码                         | 适用于数字/布尔/数字指针类型 |

### 自定义编码

方法一

在 MarshalJSON 中定义个新的结构体，对其编码

```bash
// Note that there are no struct tags on the Movie struct itself. 
type Movie struct {
  ID        int64 
  CreatedAt time.Time 
  Title     string 
  Year      int32 
  Runtime   int32 
  Genres    []string 
  Version   int32
}
// Implement a MarshalJSON() method on the Movie struct, so that it satisfies the 
// json.Marshaler interface.
func (m Movie) MarshalJSON() ([]byte, error) {
  // Declare a variable to hold the custom runtime string (this will be the empty 
  // string "" by default).
  var runtime string
  // If the value of the Runtime field is not zero, set the runtime variable to be a 
  // string in the format "<runtime> mins".
  if m.Runtime != 0 {
  	runtime = fmt.Sprintf("%d mins", m.Runtime) 
	}
  // Create an anonymous struct to hold the data for JSON encoding. This has exactly 
  // the same fields, types and tags as our Movie struct, except that the Runtime 
  // field here is a string, instead of an int32. Also notice that we don't include 
  // a CreatedAt field at all (there's no point including one, because we don't want 
  // it to appear in the JSON output).
  aux := struct {
    ID      int64    `json:"id"` 
    Title   string   `json:"title"`
    Year    int32    `json:"year,omitempty"`
    Runtime string   `json:"runtime,omitempty"` // This is a string. 
    Genres  []string `json:"genres,omitempty"`
    Version int32    `json:"version"` 
  }{
    // Set the values for the anonymous struct.
    ID:      m.ID,
    Title:   m.Title,
    Year:    m.Year,
    Runtime: runtime, // Note that we assign the value from the runtime variable here. 
    Genres:  m.Genres,
    Version: m.Version, 
}
	return json.Marshal(aux)
}
```

方法二

嵌入别名，为结构体设置别名，以避免序列化死循环。

用一个新的结构体，匿名嵌套上面的别名，并在新结构体里设置同名参数以覆盖。

缺点:

+ 将失去编码后的顺序，如果你的应用场景需要固定顺序，如对 JSON 求 MD5。

```go
// Notice that we use the - directive on the Runtime field, so that it never appears 
// in the JSON output.
type Movie struct {
  ID
  int64     `json:"id"`
  CreatedAt time.Time `json:"-"` 
  Title     string    `json:"title"`
  Year      int32     `json:"year,omitempty"` 
  Runtime   int32     `json:"-"`
  Genres    []string  `json:"genres,omitempty"` 
  Version   int32     `json:"version"`
}
func (m Movie) MarshalJSON() ([]byte, error) {
  // Create a variable holding the custom runtime string, just like before. 
  var runtime string
  if m.Runtime != 0 {
  runtime = fmt.Sprintf("%d mins", m.Runtime) 
  }
  // Define a MovieAlias type which has the underlying type Movie. Due to the way that 
  // Go handles type definitions (https://golang.org/ref/spec#Type_definitions) the 
  // MovieAlias type will contain all the fields that our Movie struct has but,
  // importantly, none of the methods. 
  type MovieAlias Movie
  // Embed the MovieAlias type inside the anonymous struct, along with a Runtime field 
  // that has the type string and the necessary struct tags. It's important that we 
  // embed the MovieAlias type here, rather than the Movie type directly, to avoid
  // inheriting the MarshalJSON() method of the Movie type (which would result in an 
  // infinite loop during encoding).
  aux := struct {
    MovieAlias
    Runtime string `json:"runtime,omitempty"` 
  }{
    MovieAlias: MovieAlias(m), 
    Runtime:    runtime,
  }
  return json.Marshal(aux) 
}
```

### 解码类型

| JSON type | Supported Go types       |
| --------- | ------------------------ |
| boolean   | bool                     |
| string    | string                   |
| number    | `int*,uint*,float*,rune` |
| array     | array,slice              |
| object    | struct, map              |

###  JSON 错误分类

对于面向公众的 API，错误消息本身并不理想。有些令人困惑且难以理解，或暴露了底层 API 细节信息。

Decode 方法，可能会返回 5 种类型的错误

| Error types                | 原因                                                       |
| -------------------------- | ---------------------------------------------------------- |
| json.SyntaxError           | json 语法存在问题                                          |
| io.ErrUnexpectedEOF        | json 语法存在问题                                          |
| json.UnmarshalTypeError    | JSON 值不适用于目标 Go 类型。                              |
| json.InvalidUnmarshalError | 解码目标无效，通常因为它不是指针，这实际上是程序代码的问题 |
| io.EOF                     | json 为空                                                  |

### 反序列时想对部分字段不赋值

客户端传递的 json 是无法控制的。

你可以在反序列化后对指定字段置零，但这显得有点笨拙，如果结构体增加了字段但忘记反序列化后置零，这样的写法会给未来留下技术栈。

建议新建一个结构体用于序列化，时候赋值给指定结构体。如:

```go
type User struct{
  Name string
  Age int
}

func main(){
  var input struct{
    Name string
  }
  s := `{"name":"Nacy"}`
  if err :=  json.UnmarshalJSON([]byte(s), &input);err!=nil{
    panic(err)
  }
  
  user := User{
    Name: input.Name,
  }
  
 	_ = user
}
```



## 参考

此文章内容为 Let's Go Further 读书笔记









