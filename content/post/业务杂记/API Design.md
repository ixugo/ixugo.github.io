---
title: API 设计模式
description: 
date: 2024-03-30
slug: 
image: 
draft: false
categories:
    - 后端
tags:

---

# API 设计模式

# 约定

结构体名 RequestQuery 表示请求的 query 参数，实际业务应该名为 业务名+Input。

结构体名为 RequestBody 表示请求的 body 参数。

结构体名为 ResponseBody 表示响应的 body 参数。

## 设计原则

**命名**

名字的寿命可能比项目的生命周期还要长。从变量命名，结构体命名，包名，函数名，到业务名，无处不在，如果变量叫 Channel，业务名叫通道，销售经理叫管道，函数名叫 Pipe，这种割裂感，每位项目参与者真的能明白对方想表达的是什么东西吗?

代码内的命名还好，一旦是开放的 API ，就不能轻易的更名，所以选择一个清晰简洁通俗易懂的名称，是非常必要的。

数据请求/响应参数的命名，有大驼峰/小驼峰/蛇形，重点不在于选择哪种方式，而在于统一。看看以下 JSON，你会觉得很享受吗? 每次填写参数的时候，你是否要考虑一下，这个参数是小驼峰还是蛇形来着?

跟着公司旧项目的命名方式走即可，如果没有旧项目? 可以参考你喜欢的公司用怎样的命名方式，例如看看 ChatGPT ，Twitter(X)，百度等等，选一个作为参考即可。

```json
{
  "page_number":1,
  "maxPageLimit" 2
}
```

量词命名应当结尾带上单位，例如开始时间 startAtMs 开始时间戳毫秒，StartAtS 开始时间戳秒。文件大小 sizeBytes，这种明细的单位不用查询文档即可知道其含义。当接口发生变更时(例如更换单位)，新增一个变量名即可，例如 SizeMbypes 。

**简单性**

好的 API 应该非常简单的调用，不应该为了一些隐藏或兼容功能，提高调用复杂度。API 不应试图过度减少接口数量，而应该尽可能以最直接的方式公开用户想实现业务的功能。

**可预测性**

在某些 API 中使用了 page 作为分页，那么在相同查询列表的接口中，也应该使用相同的单词，所有接口使用一致的命名规则能够使 API 的参数可以被预测。如果有些接口中叫 `page`，有些接口叫 `page_num`，有些接口叫 `page_size` ，另外的接口用 `pageSize`，调用者会很混乱，同一个东西为什么要起这么多名字? 是有什么特殊性吗? 

个人编写代码可能会出现这种情况，但更多是因为团队开发才出现这种情况，团队开发者如果明确知道这个模型已经定义了，应当先去了解已定义的模型，而不是自己想当然的创建新模型。

```go
// 以下函数都是为了分页查询消息。
func findMessages(page,size int) ([]Message,error){}
func findMessagesByUserID(pageNum,maxSize int) ([]Message,error){}
func findMessagesByUsername(pageSize,max_limit int) ([]Message,error){}
func findInformatiI( size,limit int) ([]Message,error){}
// What Fuck?
```



**富有表现力**

接口能够清楚的表达他们想做的事情。例如，将文本转换成另外一种语言，用户可能会频繁的调用接口去判断字符串属于哪个语言? 这属于业务上的需求，如果直接提供一个 `detectLanguage` 接口而不是让用户调用大量接口去猜测，情况会好得多。

## 分页模式

大量数据被同时查询，会增加接口耗时，对于用户体验不是很好，每次打开客户端，都要等几秒才能看到结果? 正确使用分页模式，将消息分片，每次返回一部分。

例如用户的消息。

`GET /users/:id/messages?page=1&size=10`

```go
type RequestQuery struct{
  Page int // page 用来表示请求的哪一页
  Size int // size 表示最大取多少条数据
}
```

响应

```json
{ "items":[], "total": 200, "next":""}
```

items 表示内容列表，total 和 next 一般是二选一存在，当遇到支持跳页时，应该返回 total 表示消息总数，前端可以通过 total 来计算分多少页。 当遇到顺序翻页时( 滚动翻页 )，应当返回 next ，此值是获取下一页的方法。

## 导入/导出模式

通常导入导出涉及到查询进度，查询状态，历史记录，下载位置等问题。

以导出用户信息为例:

`POST /users/:id/messages:export`

导入/导出是一个行为动作，所以此处应用 POST 动词加上特殊语法来区分，这不是标准 REST API操作。

```go
type RequestBody struct{
   Compression int  // 指定文件压缩级别 <=0 不压缩，1-9 压缩级别
}
```

导入/导出模式应该持续响应进度，可以返回具体的量值，由前端根据需要是计算百分比，还是显示实际的量值。

```go
type ResponseMetadata struct{
  Total int  // 总任务量
  Current int  // 当前执行到第一个任务?
  Success int  // 顺利完成任务总量
  Failure int  // 操作失败的任务总量
  Err  string  // 如果当前任务执行失败时存在此信息，否则为 undefined
}
```

最终任务完成时，返回文件信息。

```go
type ResponseBody struct{
  Path string  // 文件地址(如果是本地文件应当返回 path 路径，若是 s3 存储应当返回完整 url 路径)
  Compression int // 压缩信息
}
```

其中导出模式，应当另外提供获取文件的接口。