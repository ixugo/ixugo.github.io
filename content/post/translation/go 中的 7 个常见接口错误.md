---
title: Go 中的 7 个常见接口错误
description: 
date: 2024-07-01
slug: 
image: 
draft: false
categories:
    - Go
    - 翻译
tags:
    - 读书笔记
---



Go 仍然是一门新语言，如果你正在使用它，它很可能不是你的第一门编程语言。

不同的语言，既为你带来了经验，也带来了偏见。你用以前的任何语言做的事情，在 Go 中用相同的方法可能不是一个好主意。

学习 Go 不仅仅是学习一种新的语法。这也是学习一种新的思维方式来思考你的程序：

> *Go is a language for writing Go programs, not Java programs or Haskell programs or any other language’s programs. You need to think a different way to write good Go programs. But that takes time and effort, more than most will invest. So the usual story is to translate one program from another language into Go and see how it turns out. But translation misses idiom. A first attempt to write, for example, some Java construct in Go will likely fail, while a different Go-specific approach might succeed and illuminate. After 10 years of Java programming and 10 minutes of Go programming, any comparison of the language’s capabilities is unlikely to generate insight, yet here come the results, because that’s a modern programmer’s job.*
>
> **Rob Pike** *—* [Esmerelda’s Imagination](https://commandcenter.blogspot.com/2011/12/esmereldas-imagination.html)

正如 Rob Pike 所建议的那样，如果你想提高围棋技能，需要投入时间和精力来学习这门语言的习语。

Go 在几件事上与其他传统语言不同，在本文中，我将重点介绍其中之一：接口。

下面列出了人们在编写 Go 接口时常犯的错误。这些在其他语言中可能不是错误，但在 Go 中，你需要忘记它们。或者至少，给一个机会，暂时不和他们一起工作，看看这会把你引向何方。

## 但在这之前

以下是阅读本文时要记住的事项列表。如果你已经熟悉它们，请随意跳过。

+ 接口隔离原则：不应强制客户端实现它不使用的接口，也不应强制客户端依赖于它们不使用的方法。

+ 多态性：一段代码根据它收到的具体数据改变其行为。

+ Liskov 替换原则：如果你的代码依赖于抽象，那么一个实现可以被另一个实现替换，而无需更改你的代码。

  > *抽象的目的不是模糊不清，而是创造一个新的语义层次，在这个层次上可以绝对精确。— E.W.迪克斯特拉*

接口是精确包含用于编写程序的想法的概念。

以正确的方式使用接口可以带来简单性、可读性和 organic code 设计。

organic code 是代码会根据你在某个时间点所需的行为而增长。它不会强迫你提前考虑你的类型以及它们之间的关系，因为你很可能无法正确理解它们。

这就是为什么说 Go 偏爱组合而不是继承。你有一小组行为，你可以从中编写任何你想要的，而不是预定义由其他类型继承的类型并希望它们适合问题域。

Rob Pike 在 golang-nuts 论坛上解释了这种方法：

![img](http://img.golang.space/img-1719847716977.png)

Go 的接口不是 Java 或 C# 接口的变体，它们远不止于此。它们是大规模编程和适应性强的演进设计的关键。

无论如何，理论已经足够了，让我们来看看最常见的错误：

## 1. 你创建了太多的接口

接口过多的术语称为接口污染 [interface pollution](https://www.ardanlabs.com/blog/2016/10/avoid-interface-pollution.html).。当你在编写具体类型之前开始抽象时，就会发生这种情况。由于你无法预见你需要什么抽象，所以很容易写出太多的接口，这些接口在以后要么是错误的，要么是无用的。

Rob Pike 有一个很好的指南，可以帮助我们避免界面污染：

> *Don’t design with interfaces, discover them.*
>
> **Rob Pike**

Rob 在这里指出的是，你不需要提前考虑你需要什么抽象。你可以使用具体结构开始设计，并仅在设计需要时创建接口。通过这样做，你的代码会顺其自然的增长到预期的设计。

我仍然看到人们提前创建接口，因为他们认为他们将来可能需要多个实现。

我对他们说：

![img](http://img.golang.space/img-1719848026883.png)

以一种好的方式懒惰。创建接口的最佳时机是你真正需要它的时候，而不是你预测需要它的时候。下面是一个通过提前思考创建接口的示例，以及它导致了什么。

无用的接口往往只有一个实现。它们只是增加了一个额外的间接级别，迫使程序员在真正想要实现时总是通过它们。

接口是有代价的：这是您在推理代码时需要记住的一个新概念。正如 Djikstra 所说，理想的界面必须是“a new semantic level in which one can be absolutely precise.”。

如果你的代码需要 `Box` 的概念，仅由 Box 实现的名为 Container 的额外接口没有带来任何好处，除了混淆。

因此，在创建接口之前，先问问自己：接口有多个实现吗？我强调使用了‘有’，因为‘将会有’假设了你能预测未来，而你不能。

## 2. 你有太多的方法

在 PHP 项目中，看到 10 种方法接口是很常见的。在 Go 中，接口很小，标准库中所有接口上的平均方法数为 2。

**The bigger the interface the weaker the abstraction**，这是 Go 谚语之一。正如 Rob Pike 所说，这是接口最重要的一点，这意味着接口越小，它就越有用。

接口可以拥有的实现越多，它的通用性就越强。如果你有一个包含大量方法的接口，则很难有它的多个实现。您拥有的方法越多，接口就越具体。它越具体，不同类型显示相同行为的可能性就越低。

有用接口的一个很好的例子是 io.Reader 和 io.Writer，它们具有数百个实现。或者 error 接口，它非常强大，可以在 Go 中实现整个错误处理。

请记住，你可以稍后用其他接口组合接口。例如， `ReadWriteCloser` 下面是由 3 个较小的接口组成的：

```go
type ReadWriteCloser interface {
	Reader
	Writer
	Closer
}
```

## 3. 你不编写行为驱动的接口

在传统语言中，名词接口如 User、Request、等等都是很常见的。在 Go 中，大多数接口都有一个 `er` 后缀： `Reader`  `Writer` `Closer` 等。这是因为，在 Go 中，接口公开了行为，它们的名称指向了该行为。

正如我之前在 IO 基础中所写的，在 Go 中定义接口时，你定义的不是某物是什么，而是它提供了什么——行为，而不是事物！这就是为什么 Go 中没有 `File` 接口，而是  `Reader` 和  `Writer` ： 这些是行为，并且是 `File` 实现 `Reader` 和 `Writer` 的东西。

在官方指南《Effective Go》中也提到了同样的想法：

> *Go 中的接口提供了一种指定对象行为的方法：如果某些东西可以做到这一点，那么它可以在这里使用。*

在编写接口时，请尝试考虑操作或行为。如果你定义了一个名为的 `Thing` 接口，问问自己为什么 `Thing` 不是一个结构。

## 4. 你在生产者端编写接口

我经常在代码审查中看到这一点：人们在编写具体实现的同一包中定义接口。

但是，也许客户端不想使用生产者界面中的所有方法。请记住，从接口隔离原则中，“不应强迫客户端实现它不使用的方法”。下面是一个示例：

```go
package main

// ====== producer side

// This interface is not needed
type UsersRepository interface {
    GetAllUsers()
    GetUser(id string)
}

type UserRepository struct {
}

func (UserRepository) GetAllUsers()      {}
func (UserRepository) GetUser(id string) {}

// ====== client side

// Client only needs GetUser and
// can create this interface implicitly implemented
// by concrete UserRepository on his side 
type UserGetter interface {
    GetUser(id string)
}
```

如果客户想使用 producer 的所有方法，他可以使用具体结构。该行为已通过 struct 方法提供。

即使客户端想要解耦其代码并使用多个实现，他仍然可以创建一个包含他这边所有方法的接口：

![img](http://img.golang.space/img-1719849001610.png)

这些东西是通过 Go 中的接口隐式满足这一事实来实现的。客户端代码不再需要导入某些接口并写入 `implements` ，因为 Go 中没有这样的关键字。如果 `Implementation` 具有与 `Interface` 相同的方法，则 `Implementation` 已满足该接口，并且可以在客户端代码中使用。

## 5. 你的方法返回接口

如果方法返回接口而不是具体结构，则调用该方法的所有客户端都将强制使用相同的抽象。你需要让客户决定他们需要什么抽象，因为代码是他们的庭院。

当你想使用结构中的某些内容但不能使用时，这很烦人，因为接口没有公开它。这种限制可能有原因，但并非总是如此。这里有一个人为的例子：

```go
package main

import "math"

type Shape interface {
    Area() float64
    Perimeter() float64
}

type Circle struct {
    Radius float64
}

func (c Circle) Area() float64 {
    return math.Pi * c.Radius * c.Radius
}

func (c Circle) Perimeter() float64 {
    return 2 * math.Pi * c.Radius
}

// NewCircle returns an interface instead of struct
func NewCircle(radius float64) Shape {
    return Circle{Radius: radius}
}

func main() {
    circle := NewCircle(5)

    // we lose access to circle.Radius
}
```

在上面的例子中，我们不仅失去了对 `circle.Radius` 的访问权限，而且每次我们想要访问它时，我们都需要用类型断言填充我们的代码：

```go
shape := NewCircle(5)

if circle, ok := shape.(Circle); ok {
    fmt.Println(circle.Radius)
}
```

要遵循波斯特尔定律，“**你接受什么是自由的，而你发送什么是保守的**”，从你的方法中返回具体的结构，并选择用接口接收。

在 Dave Cheney 的 Practical Go 中，有一篇很好的文章  [a nice write-up](https://dave.cheney.net/practical-go/presentations/qcon-china.html#_let_functions_define_the_behaviour_they_requires)  解释了为什么以下代码：

```go
// Save writes the contents of doc to the file f.
func Save(f *os.File, doc *Document) error
```

通过接受接口进行改进：

```
// Save writes the contents of doc to the supplied
// Writer.
func Save(w io.Writer, doc *Document) error
```

## 6. 你创建接口纯粹是为了测试

这是接口污染的另一个原因：创建一个只有一个实现的接口，只是因为你想模拟这个实现。

如果通过创建许多模拟来滥用接口，则最终会测试从未在生产中使用过的模拟，而不是应用程序的实际逻辑。在你的实际代码中，你现在有 2 个概念（正如 Djikstra 所说，语义级别）可以在其中执行。这只是为了你想要测试的东西。你想在每次创建新测试时将语义级别提高一倍吗？

例如，你始终可以使用 testcontainers 而不是模拟你的数据库。或者，如果 `testcontainers` 尚不支持，则只需拥有自己的容器。

或者，也许你需要 mock 一些东西，但不是整个事情。例如，如果你有一个包含 10 种方法的结构，也许你不需要模拟整个结构。也许你只能模拟一小部分，你可以在测试中使用你的具体结构。模拟整个结构体是一种非常懒惰的测试解决方案。

如果你编写一个 API，你不需要向你的客户端提供一个接口，这样他们就可以用它来模拟。如果他们想编写模拟，他们可以通过指定自己的接口来自己完成（参见第 4 点）

## 7. 您不验证接口合规性

假设你有一个包，该包导出了名为 `User` 的类型，并且n你实现了该 `Stringer` 接口，因为出于某种原因，当你打印它时，你不希望显示电子邮件：

```go
package users

type User struct {
    Name  string
    Email string
}

func (u User) String() string {
    return u.Name
}
```

客户端具有以下代码：

```
package main

import (
    "fmt"

    "pkg/users"
)

func main() {
    u := users.User{
       Name:  "John Doe",
       Email: "john.doe@gmail.com",
    }
    fmt.Printf("%s", u)
}
```

这将正确输出： `John Doe` 。

现在，假设您重构，并且错误地删除或注释了 `String()` 实现，并且您的代码如下所示：

```go
package users

type User struct {
    Name  string
    Email string
}
```

在这种情况下，代码仍将编译并运行，但输出现在将为 `{John Doe john.doe@gmail.com}` “没有反馈强制执行之前的意图”。

当您有接受 User 的方法时，编译器会为您提供帮助，但在上述情况下，编译器不会。

为了强制执行某个类型实现接口的事实，我们可以执行以下操作：

```go
package users

import "fmt"

type User struct {
    Name  string
    Email string
}

var _ fmt.Stringer = User{} // User implements the fmt.Stringer

func (u User) String() string {
    return u.Name
}
```

现在，如果我们删除该 `String()` 方法，我们将在构建时得到以下内容：

```
cannot use User{} (value of type User) as fmt.Stringer value in variable declaration: User does not implement fmt.Stringer (missing method String)
```

我们在那一行中所做的是，尝试将一个空 `User{}` 分配给类型 `fmt.Stringer` 。由于停止实现 `fmt.Stringer` ， `User{}` 收到了投诉。我们使用 `_` 作为变量名称，我们并没有真正使用它所以不会执行任何分配。

上面我们有 `User` 实现接口。 `User` 并且是 `*User` 不同的类型。因此，如果你想实现它， `*User` 你可以做这样的事情：

```go
var _ fmt.Stringer = (*User)(nil) // *User implements the fmt.Stringer
```

我也喜欢在这样做时，我的Goland IDE会向我显示一个“实现缺少的方法”选项：

如需了解详情，请查看 [article from Mat Ryer](https://medium.com/@matryer/golang-tip-compile-time-checks-to-ensure-your-type-satisfies-an-interface-c167afed3aae) 或  [Uber Go Style](https://github.com/uber-go/guide/blob/master/style.md#verify-interface-compliance) 的指南。

虽然这是一个很酷的技巧，但你不需要对每个实现接口的类型都这样做，如果我们有需要接口的函数，如果你尝试使用不实现它们的类型，编译器已经抱怨了。我自己不得不思考一段时间才能为本文想出一个例子，所以真的，这是一个罕见的案例。

正如我们在 Effective Go 中被警告的那样：

> *The appearance of the blank identifier in this construct indicates that the declaration exists only for the type checking, not to create a variable. Don’t do this for every type that satisfies an interface, though. By convention, such declarations are only used when there are no static conversions already present in the code, which is a rare event.*

就这些了! 



## 参考

本文翻译于[ <7 Common Interface Mistakes in Go>](https://medium.com/@andreiboar/7-common-interface-mistakes-in-go-1d3f8e58be60)

