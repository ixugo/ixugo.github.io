---
title: Go 1.23 
description: 
date: 2024-08-12
slug: 
image: 
draft: false
categories:
    - Go
tags:
    - Go
---



## 迭代器

迭代器是将序列的连续元素传递给回调函数的函数。当序列完成或回调返回`false`时，该函数将停止，指示提前停止迭代。

1.23 之前的 stdlib 中的迭代器的一个很好的例子是`sync.Map.Range`方法，它迭代并发安全映射：

```go
var m sync.Map

m.Store("alice", 11)
m.Store("bob", 12)
m.Store("cindy", 13)

m.Range(func(key, value any) bool {
	fmt.Println(key, value)
	return true
})
```

从 Go 1.23 开始，可以在 for-range 循环中使用迭代器。从显式调用变成了隐式调用。

```go
// go 1.22
m.Range(func(key, val any) bool {
	fmt.Println(key, val)
	return true
})

// go 1.23
for key, val := range m.Range {
	fmt.Println(key, val)
}
```

for-range 循环中的`range`子句接受以下任意函数类型：

```go
func(func() bool)
func(func(K) bool)
func(func(K, V) bool)
```

### 迭代器类型

迭代器类型在新的[`iter`](https://tip.golang.org/pkg/iter)包中正式定义：

```go
type (
	Seq[V any]     func(yield func(V) bool)
	Seq2[K, V any] func(yield func(K, V) bool)
)
```

`Seq`产生单个值，而`Seq2`产生对（就像`sync.Map.Range`一样）。

*Yield*参数名称只是一个约定，您可以将其命名为*foo*或*bar*或其他任何名称 - 唯一重要的是函数签名

使用`Seq` / `Seq2`类型使迭代器定义更加简洁。您可以定义一个返回迭代器的函数：

```go
// Reversed returns an iterator that loops over a slice in reverse order.
func Reversed[V any](s []V) iter.Seq[V] {
	return func(yield func(V) bool) {
		for i := len(s) - 1; i >= 0; i-- {
			if !yield(s[i]) {
				return
			}
		}
	}
}
```

还有一个使用迭代器的函数：

```go
// PrintAll prints all elements in a sequence.
func PrintAll[V any](s iter.Seq[V]) {
	for v := range s {
		fmt.Print(v, " ")
	}
	fmt.Println()
}
```

并以方便的方式组合它们：

```go
func main() {
	s := []int{1, 2, 3, 4, 5}
	PrintAll(Reversed(s))
}
```

### 拉迭代器

`Seq`和`Seq2`可以被认为是*推送*迭代器，将值推送到*收益*函数。

有时，范围循环并不是使用序列值的首选方式。在这种情况下，您可以使用`iter.Pull`将推式迭代器转换为*拉式*迭代器：

```go
func main() {
	s := []int{1, 2, 3, 4, 5}
	// uses the Reversed iterator defined previously
	next, stop := iter.Pull(Reversed(s))
	defer stop()

	for {
		v, ok := next()
		if !ok {
			break
		}
		fmt.Print(v, " ")
	}
}
```

`Pull`启动一个迭代器并返回一对函数 - `next`和`stop` - 分别返回迭代器的下一个值并停止它。您调用`next`从迭代器中*提取*下一个值 - 因此得名。

如果客户端不使用序列来完成，则它们必须调用`stop` ，这允许迭代器函数完成并返回。如示例所示，确保这一点的传统方法是使用`defer` 。

### 切片迭代器

[`slices`](https://tip.golang.org/pkg/slices)包添加了几个与迭代器一起使用的函数。

[All](https://tip.golang.org/pkg/slices#All)返回切片索引和值的迭代器：

```go
s := []string{"a", "b", "c"}
for i, v := range slices.All(s) {
	fmt.Printf("%d:%v ", i, v)
}
// 0:a 1:b 2:c
```

[Values](https://tip.golang.org/pkg/slices#Values)返回切片元素上的迭代器：

```go
s := []string{"a", "b", "c"}
for v := range slices.Values(s) {
	fmt.Printf("%v ", v)
}
// a b c
```

[Backward](https://tip.golang.org/pkg/slices#Backward)返回一个倒序切片的迭代器：

```go
s := []string{"a", "b", "c"}
for i, v := range slices.Backward(s) {
	fmt.Printf("%d:%v ", i, v)
}
// 2:c 1:b 0:a
```

[Collect](https://tip.golang.org/pkg/slices#Collect)将迭代器中的值收集到新切片中：

```go
s1 := []int{11, 12, 13}
s2 := slices.Collect(slices.Values(s1))
fmt.Println(s2)
// [11 12 13]
```

[AppendSeq](https://tip.golang.org/pkg/slices#AppendSeq)将迭代器中的值追加到现有切片：

```go
s1 := []int{11, 12}
s2 := []int{13, 14}
s := slices.AppendSeq(s1, slices.Values(s2))
fmt.Println(s)
// [11 12 13 14]
```

[Sorted](https://tip.golang.org/pkg/slices#Sorted)将迭代器中的值收集到新切片中，然后对切片进行排序：

```go
s1 := []int{13, 11, 12}
s2 := slices.Sorted(slices.Values(s1))
fmt.Println(s2)
// [11 12 13]
```

[SortedFunc](https://tip.golang.org/pkg/slices#SortedFunc)与 Sorted 类似，但具有比较函数：

```go
type person struct {
	name string
	age  int
}
s1 := []person{{"cindy", 20}, {"alice", 25}, {"bob", 30}}
compare := func(p1, p2 person) int {
	return cmp.Compare(p1.name, p2.name)
}
s2 := slices.SortedFunc(slices.Values(s1), compare)
fmt.Println(s2)
// [{alice 25} {bob 30} {cindy 20}]
```

[SortedStableFunc](https://tip.golang.org/pkg/slices#SortedStableFunc)与 SortFunc 类似，但使用稳定排序算法。

[Chunk](https://tip.golang.org/pkg/slices#Chunk)返回 s 的最多 n 个元素的连续子切片的迭代器。除最后一个子切片之外的所有子切片的大小均为 n。所有子切片都被剪裁，使其没有超出长度的容量。如果 s 为空，则序列为空：序列中不存在空切片。如果 n 小于 1，Chunk 会发生 panic。

```go
s := []int{1, 2, 3, 4, 5}
chunked := slices.Chunk(s, 2)
for v := range chunked {
	fmt.Printf("%v ", v)
}
// [1 2]-2 [3 4]-2 [5 6]-2 [7]-1

```

### map 迭代器

[`maps`](https://tip.golang.org/pkg/maps)包添加了几个与迭代器一起使用的函数：

[All](https://tip.golang.org/pkg/maps#All)返回映射中键值对的迭代器：

```go
m := map[string]int{"a": 1, "b": 2, "c": 3}
for k, v := range maps.All(m) {
	fmt.Printf("%v:%v ", k, v)
}
// a:1 b:2 c:3
```

[Keys](https://tip.golang.org/pkg/maps#Keys)返回映射中键的迭代器：

```go
m := map[string]int{"a": 1, "b": 2, "c": 3}
for k := range maps.Keys(m) {
	fmt.Printf("%v ", k)
}
fmt.Println()
// c a b
```



