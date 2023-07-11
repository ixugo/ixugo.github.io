---
title: RESTful API 设计指南
description: 
date: 2020-05-21 
slug: 
image: 
draft: false
categories:
    - HTTP
tags:
    - 读书笔记
    - RESTful
---



# API design

+ `*` 表示必须遵守，没有则为建议

## 请求

### 提供用于自检的请求 ID

在每个 API 响应中包含一个 Request_ID 标头，并采用 UUID 值填充。通过在客户机、服务器和任何后台服务上记录这些值，它提供了一种跟踪、诊断和调试请求的机制。

### *在请求体中接收序列化的 JSON

在 PUT/PATCH/POST 请求体接收序列化的 JSON，而不是表单编码

例如

```bash
curl -X POST https://service.com/apps \
    -H "Content-Type: application/json" \
    -d '{"name": "demoapp"}'

{
  "id": "01234567-89ab-cdef-0123-456789abcdef",
  "name": "demoapp",
  "owner": {
    "email": "username@example.com",
    "id": "01234567-89ab-cdef-0123-456789abcdef"
  },
  ...
}
```

### *REST API

**资源名**

资源名使用复数版本，除非所涉及的资源是系统中的单例

```bash
/user		 # Bad
/users   # Good
```

**Request Method**

| 资源       | POST       | GET          | PUT          | DELETE       |
| ---------- | ---------- | ------------ | ------------ | ------------ |
| /users     | 创建新客户 | 检索所有客户 | 批量更新客户 | 删除所有客户 |
| /users/:id | -          | 检索指定客户 | 更新指定客户 | 删除指定客户 |

+ POST 创建资源，不应具有不相关的副作用
+ PUT  更新资源，该请求必须是幂等的。
+ GET  获取资源
+ DELETE 删除资源

避免实现琐碎的 POST / PUT / DELETE 操作。

在实际 API 开发中，有些操作可能不能很好的映射为 REST 资源，如禁言某用户，可以参考以下做法:

+ 将操作变为资源的属性， `/users/id?active=false`，缺点是一个接口要处理多种参数组合，尽可能将属性相关的放在一起，不然建议新增一个接口。
+ 下级资源 `/users/id/active`，通过不同的请求方式决定增删，优点是接口作用明晰，缺点是接口数量会很大，我认为，接口明晰更重要。
+ 以上不能解决，有时可以打破规范，如登录就`/login`

#### 分页 / 过滤 / 排序 / 搜索

如 `/users`  列出所有用户，需要提供分页功能。

滚动翻页，可以使用 `/users?limit=10&since=10000` ，since 是前一页最后一条数据的 ID 或序号。

跳转分页，可以使用 `/users?limit=10&page=1`，page 表示第几页

过滤属性，如果用户不需要资源的全部属性，可以在 uri 参数中指定需要哪些，`/users?fields=email,username,address`

排序，`/users?sort=age desc`，`/users?sort=id,age desc` ，注意 `id ，age desc`应该与例子中等价，多余的空格可以忽略

搜索，`/users?key=zhangsan`

关于分页的补充

默认 limit = 20 ， limit < 100，要指定上限防止拒绝服务攻击

``` go
type Response struct{
  Data any  // 分页数据
  Next string // 下一页的 since，在请求下一页时应该带上这个参数
}
```

#### 重复请求

服务端能够通过此ID来检测请求是否重复，保证请求只被处理一次。

```go
// 用于检测冗余请求的唯一标识符
// 这个字段应该命名为 `request_id`
string request_id = ...;
```



**异步操作**

有时，POST、PUT、PATCH 或 DELETE 操作可能需要处理操作需要一段时间才能完成。 如果需要等待该操作完成后才能向客户端发送响应，可能会造成不可接受的延迟。 在这种情况下，请考虑将该操作设置为异步操作。

应公开一个可返回异步请求状态的终结点，使客户端能够通过轮询状态终结点来监视状态。

异步请求

```bash
GET /service/restart


状态码 : 201
{
		"url" : "/service/status"   
}
```

通过访问 URL 可以知道当前异步执行的状态



#### Action

明确以行动前缀详细说明

```bash
/resources/:resource/actions/:action
```

例如停止某一特定的运行:

```bash
/runs/{run_id}/actions/stop
```

对集合的操作也应该最小化。如果需要，应该使用一个顶级的动作延长来避免名称空间冲突，并清楚地显示动作的范围:

```bash
/actions/:action/resources
```

例如重启所有服务器

```bash
/actions/restart/servers
```

#### *一致的路径格式

使用小写和破折号分隔的路径名

```bash
service-api.com/users
service-api.com/app-setups
```

最小化路径嵌套，优先在资源的父路径上定位资源来限制嵌套深度

避免超过 2 层的资源嵌套，建议将其它资源 转换为?参数，

```bash
# Bad
/orgs/{org_id}/apps/{app_id}/dynos/{dyno_id}
```

```bash
# Good
/orgs/{org_id}
/orgs/{org_id}/apps
/apps/{app_id}
/apps/{app_id}/dynos
/dynos/{dyno_id}
```



## 响应

#### *返回适当的状态代码

+ `200 OK` 请求成功
+ `400 Bad Request` 请求参数有误
+ `401 Unauthorized` 用户身份未验证
+ `403 Forbidden` 用户没有访问该资源权限
+ `500 Internal Server Error` 服务器异常

#### 响应提供全部资源

在响应中尽可能提供完整的资源表示(即包含所有属性的对象)。

```bash
$ curl -X DELETE \
  https://service.com/apps/1f9b/domains/0fd4

HTTP/1.1 200 OK
Content-Type: application/json;charset=utf-8
...
{
  "created_at": "2012-01-01T12:00:00Z",
  "hostname": "subdomain.example.com",
  "id": "01234567-89ab-cdef-0123-456789abcdef",
  "updated_at": "2012-01-01T12:00:00Z"
}
```

#### 提供资源 UUID

默认情况下为每个资源提供一个 id 属性。除非有充分的理由，否则请使用 uuid。

```bash
"id": "01234567-89ab-cdef-0123-456789abcdef"
```

#### 提供标准时间戳

只接受和返回 UTC ( 世界标准时间 )时间。以 ISO8601格式呈现时间。

```bash
{
  // ...
  "created_at": "2012-01-01T12:00:00Z",
  "updated_at": "2012-01-01T13:00:00Z",
  // ...
}
```

#### *提供标准的响应类型

当为 `null` 时，可以忽略该参数

+ 字符串 string || `null` 
+ 布尔     false || true
+ 数字     number || `null`  ，注意:一些 JSON 解析器将返回精度超过15位的数字作为字符串。
+ 数组      [] ， 没有值时返回空数组
+ 对象     object || `null`

#### *使用嵌套对象序列化

```bash
# Bad
{
  "name": "service-production",
  "owner_id": "5d8201b0...",
  // ...
}
```

```bash
# Good
{
  "name": "service-production",
  "owner": {
    "id": "5d8201b0..."
  },
  // ...
}
```

这种方法可以在不改变响应结构或引入更多顶级响应字段的情况下内联更多关于相关资源的信息，例如:

```bash
{
  "name": "service-production",
  "owner": {
    "id": "5d8201b0...",
    "email": "alice@heroku.com"
  },
  // ...
}
```

注意要为子集提供唯一值，避免不一致和混淆，如 `id` 字段

#### *生成结构化错误

对错误生成一致的，结构化的响应。

+ 包括一个机器可读的错误 ID，可以通过该 ID 判断出哪类错误，字段用 `code` 表示。
+ 包括一个用户可读的错误消息，以及错误详情，如有需要可以增加`URL` ，向客户端提示如何解决错误的地址。

http 的状态码不要使用太多，建议需要以下3个

+ 200 - 请求成功
+ 400 - 发生错误
+ 401 - 未登录或身份令牌过期 导致的身份验证失败

**经过更多的实验与学习，认为 英文错误码 比 数字错误码 更适合大多数场景，以下方案仅供了解**

Code 设计规范，纯数字表示，如`10101`，1 开头的通用模块适合所有项目，其它数字开头的业务错误针对业务设计。

+ 1，通用
+ 01，资源模块
+ 01，错误码序号，比如该序号表示请求频繁

| 服务 | 模块 | 说明                    |
| ---- | ---- | ----------------------- |
| 1    | 01   | 通用 - 基本错误         |
| 1    | 02   | 通用 - 数据库类错误     |
| 1    | 03   | 通用 - 认证授权类错误   |
| 1    | 04   | 通用 - 编解码类错误     |
| 2    | 01   | 用户服务 - 历史登录模块 |

| HTTP 状态码 | 错误码 | 说明                                        |      |
| ----------- | ------ | ------------------------------------------- | ---- |
| 200         | 0      | 实际上也无需返回 code，正常返回业务数据即可 |      |
| 400         | 10101  | 未知错误                                    |      |
| 400         | 10102  | 请求参数有误                                |      |
| 400         | 10201  | SQL 语法错误                                |      |
| 401         | 10301  | token 验证失败                              |      |
| 400         | 10302  | 操作了不属于自己的资源                      |      |
| 400         | 10401  | json 编解码出错                             |      |
| 400         | 20101  | 记录用户登录出错                            |      |
|             |        |                                             |      |

#### 错误信息规范

+ 对外暴露的错误要简介，能准确说明问题
+ 错误说明，应该是该怎么做，而不是哪里错了。
+ 错误中不能出现敏感的信息，比如数据库的错误提示，用户某某资源提示
+ 

```go
HTTP/1.1 400 Bad Requests

{
  "code":      10101,
  "msg": "Account reached its API rate limit.",
  "details": []
}
```

#### 速率限制

速率限制来自客户的请求，以保护服务的健康和维护其他客户的高服务质量。您可以使用令牌桶算法来量化请求限制。可以在 RateLimit-Remaining response header 中返回每个请求的请求标记的剩余数量。

#### 在所有回复中保持 JSON 的简化

额外的空白为请求增加了不必要的响应大小，最好尽量减少 JSON 响应。

```bash
# Bad
{
  "beta": false,
  "email": "alice@heroku.com"
}
```

```bash
# Good
{"beta":false,"email":"alice@heroku.com"}
```



## 对于项目要求

+ 提供团队可读的文档

+ 提供可执行的示例

  



## 参考

[Google API 设计指南](https://google-cloud.gitbook.io/api-design-guide/standard_methods) 

## 了解更多 RESTful API 设计

[Heroku RESTful API Design](https://geemus.gitbooks.io/http-api-design/content/en/)

[Microsoft RESTful API 设计](https://docs.microsoft.com/zh-cn/azure/architecture/best-practices/api-design)

[Github RESTful API 设计](https://docs.github.com/cn/rest)

