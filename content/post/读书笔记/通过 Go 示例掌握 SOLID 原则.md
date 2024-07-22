---
title: 通过 Go 示例掌握 SOLID 原则
description: 
date: 2024-07-10
slug: 
image: 
draft: false
categories:
    - Golang
tags:
    - 读书笔记
    - Golang
---

SOLID 原则是一组设计指南，可帮助开发人员编写更可维护、可扩展和可测试的代码。

构建软件是一个不断变化的挑战。为了应对这种复杂性，开发人员依靠经过验证的设计原则来编写健壮、适应性强且易于管理的代码。其中一组原则是 SOLID（由 Robert C. Martin 首先提出）。

SOLID 代表：单一职责、开闭式、里氏替换、接口隔离和依赖倒置。每条原则在提高程序的可维护性、可扩展性和可测试性方面都发挥着至关重要的作用。

![image-20240718163153573](http://img.golang.space/img-1721291513669.png)

尽管Golang不是纯粹的面向对象语言，但我们仍然可以应用SOLID原则来改进我们的Go代码。在这篇文章中，我们将深入研究每个原则，探索其含义，并发现如何在 Go 中有效地利用它。

## S - 单一责任原则

单一职责原则 (Single Responsibility Principle) 规定结构/包应专注于单个明确定义的功能区域。将每个结构想象成具有特定专业知识的专家。这可以使您的代码保持井井有条并降低复杂性。对结构功能的更改是隔离的，使维护和未来的更新变得轻而易举。

> *A class should have one, and only one, reason to change.*
>
> *Robert C. Martin*

Go 擅长结构体，而不是类。但不用担心，SRP 建议在这里仍然适用。将每个结构想象为一个紧密结合的模块，负责一个明确定义的任务。这种模块化方法可以保持代码整洁、降低复杂性并提高可维护性。

SRP 的魔力也延伸到了 Go 包中。理想情况下，包应该专注于单一功能领域。这可以最大限度地减少依赖性并使事情井井有条。通过在结构和包中采用 SRP，您可以为干净、可维护和可扩展的 Go 应用程序奠定基础。

一些好的包的例子：

+ coding/json - 提供 JSON 的编码/解码。
+ net/url - 解析 URL。

不太好的例子：

+ utils - 杂项垃圾场？

让我们看一个 Go 中的示例，其中有一个 struct Survey，其中包含一些属性和几个方法：GetTitle()、Validate() 和 Save()：

```go
package survey

type Survey struct {
	Title string
	Questions []string
}

func (s *Survey) GetTitle() string {
	return s.Title
}

func (s *Survey) Validate() bool {
	return len(s.Questions) > 0
}

func (s *Survey) Save() error {
	// saves the survey to the database
	return nil
}
```

我们当前的 Survey 结构似乎设计得很好，除了 Save() 方法之外。它的存在违反了 SRP。由于数据存储和调查逻辑位于同一结构中，维护、测试和扩展变得更具挑战性。

为了遵守 SRP，我们应该区分这些问题：

```go
package survey

type Survey struct {
	Title     string
	Questions []string
}

func (s *Survey) GetTitle() string {
	return s.Title
}

func (s *Survey) Validate() bool {
	return len(s.Questions) > 0
}

type Repository interface {
	Save(survey *Survey) error
}

// One of many possible implementations
type InMemoryRepository struct {
	surveys []*Survey
}

func (r *InMemoryRepository) Save(survey *Survey) error {
	r.surveys = append(r.surveys, survey)
	return nil
}

func SaveSurvey(survey *Survey, repo Repository) error {
	return repo.Save(survey)
}
```

现在，Survey 结构只负责管理调查数据，而 Repository 接口和 InMemoryRepository 结构则处理数据库操作。

## O——开闭原则

开闭原则 (Open-Closed Principle) 是良好软件设计的基石。它规定软件实体（类、模块、功能等）的设计应考虑到未来的增长。这意味着它们应该开放扩展，允许添加新特性和功能，同时保持关闭修改。修改现有代码来适应新的需求是有风险的，因为它可能会引入错误并使未来的维护成为一场噩梦。

> *A module should be open for extension but closed for modification.*
>
> *Robert C. Martin* 

回到我们的调查示例。让我们向结构体添加一个新方法 - Export()，它可以将调查数据导出到某些外部服务/存储中。由于可能有多个导出目标，因此 Export() 方法有一个 switch 块。

```go
package survey

// ...

func ExportSurvey(s *Survey, dst string) error {
	switch dst {
	case "s3":
		// export to s3
		return nil
	case "gcs":
		// export to gcs
		return nil
	default:
		return nil
	}
}
```

如果我们需要添加对其他服务的支持，则当前的实现需要修改，这违反了 OCP。

为了遵守 OCP，我们可以定义一个 Exporter 接口，这样我们就可以为不同的目标添加新的导出器，而无需修改现有的代码库。

这遵循 OCP，提高了代码的灵活性和可维护性。我们的代码对扩展开放（我们可以添加新的导出器），但对修改关闭（我们不需要更改 Export() 函数）。

## L - 里氏替换原理

里氏替换原则 (Liskov Substitution Principle) 确保可以在不破坏程序的情况下交换对象。虽然 Go 缺乏传统的继承，但接口实现了这一点。任何类型都可以通过具有与其签名相匹配的方法来“实现”接口。这提高了灵活性——使用接口的代码可以与各种类型一起工作，只要它们履行合同。

> *If S is a subtype of T, then objects of type T may be replaced with objects of type S, without breaking the program*
>
> *B. Liskov*

在 Go 中，LSP 的一个很好的例子是 io.Writer 接口：

```go
type Writer interface {
     Write(buf []byte) (n int, err error)
}
```

io.Writer 的神奇之处在于它能够将字节切片写入任何流：文件、HTTP 响应等。

现在回到我们的 Survey 结构，我们可以添加一个方法 Write() 来将调查对象写入某处。我们可以简单地让它接受 io.Writer，这样实现就可以决定将其写入何处。

这个函数的用户现在有很大的灵活性，因为他们只需要使用一些实现 io.Writer 的结构，例如：

```go
file, err := os.Open("file.go")
if err != nil {
	log.Fatal(err)
}

survey := &Survey{Title: "Feedback Form"}
WriteSurvey(&Survey, file)
```

## I——接口隔离原则

接口隔离原则 (Interface Segregation Principle) 规定客户端不应被迫依赖于他们不使用的接口。这一原则鼓励创建更小、更集中的界面，而不是大型、单一的界面。

> *Clients should not be forced to depend on methods they do not use.*
>
> *Robert C. Martin*

同样，Go 的 io 包就是一个很好的例子。它有多个小接口及其组合，例如 io.Reader、io.ReadWriter、io.ReadCloser、io.ReadWriteCloser 等。

在我们的调查示例中，假设我们有多种问题类型：文本和下拉列表。我们可以定义一个通用的 Question 接口。

```go
type Question interface {
	SetTitle()
	AddOption()
}

type TextQuestion struct {
	Title string
}

func (q *TextQuestion) SetTitle(title string) {
	q.Title = title
}

func (q *TextQuestion) AddOption(option string) {
	// not supported as text fields don't have options
}

type DropdownQuestion struct {
	Title   string
	Options []string
}

func (q *DropdownQuestion) SetTitle(title string) {
	q.Title = title
}

func (q *DropdownQuestion) AddOption(option string) {
	q.Options = append(q.Options, option)
}
```

Question 界面中的 AddOption() 方法很突出。这对于 TextQuestion 来说没有意义并且违反了 ISP。以下是我们如何遵循 ISP 并改进设计：将问题界面拆分为更小、更集中的界面：

```go
type Question interface {
	SetTitle()
}

type QuestionWithOptions interface {
	Question
	AddOption()
}

type TextQuestion struct {
	Title string
}

func (q *TextQuestion) SetTitle(title string) {
	q.Title = title
}

type DropdownQuestion struct {
	Title   string
	Options []string
}

func (q *DropdownQuestion) SetTitle(title string) {
	q.Title = title
}

func (q *DropdownQuestion) AddOption(option string) {
	q.Options = append(q.Options, option)
}
```

## D - 依赖倒置原则

依赖倒置原则 (Dependency Inversion Principle) 规定高级模块不应依赖于低级模块。两者都应该依赖于抽象。

简单来说，DIP 建议您的代码应该依赖于接口或抽象类，而不是具体的类或函数。这种控制反转减少了软件不同部分之间的耦合，使其更加模块化、可扩展且易于测试。

> *Abstractions should not depend on details. Details should depend on abstractions.*
>
> *Robert C. Martin* 

作为示例，我们可以引入一个处理调查创建的 SurveyManager 结构，您可以想象它依赖于数据库。

```go
type InMemoryRepository struct {
	surveys []*Survey
}

type SurveyManager struct {
	store InMemoryRepository
}

func NewSurveyManager() *SurveyManager {
	return &SurveyManager{
		store: InMemoryRepository{},
	}
}

func (m *SurveyManager) Save(survey *Survey) error {
	return m.store.Save(survey)
}
```

这里糟糕的设计是它严重依赖InMemoryRepository，违反了高层模块不应该依赖低层模块的原则。

同样，接口和构造函数可以帮助我们解耦事物：

```go
type Repository interface {
	Save(survey *Survey) error
}

type SurveyManager struct {
	store Repository
}

func NewSurveyManager(store Repository) *SurveyManager {
	return &SurveyManager{
		store: store,
	}
}

func (m *SurveyManager) Save(survey *Survey) error {
	return m.store.Save(survey)
}
```

## 结论

SOLID 原则是构建干净、可维护和可扩展软件的基石。虽然具体的实现细节可能会因编程语言的不同而有所不同（例如在 Go 中使用接口组合而不是继承），但 SOLID 的核心原则仍然普遍适用。通过遵循这些原则，开发人员可以编写更具适应性、更容易测试并最终更能适应变化的代码，无论他们选择哪种语言。

## 参考

本文翻译于 [Mastering SOLID Principles with Go Examples ](https://packagemain.tech/p/mastering-solid-principles-with-go)