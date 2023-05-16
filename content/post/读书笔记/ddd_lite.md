---
title: Go 项目的思考与架构设计
description: 知道自己正在做什么，搞清楚为什么这样做，这样做的道理和效果，这样可以做出更好的设计决策。
date: 2023-05-15
slug: 
image: 
draft: false
categories:
    - 架构设计
tags:
    - 读书思考
---



# Go 项目的思考与架构设计

读完《Domain-Driven Design with Golang》这本书后，我有了一些感悟。

领域驱动设计广泛应用于解决大型复杂项目的问题。然而，将 DDD 应用于 CURD 程序可能会过度设计，并且会使交付速度变缓且更加繁琐。在实际开发中，我们面临更多中小型项目快速落地的情景，因此需要寻求开发效率和架构设计之间的平衡点。

同时，在保证高效率开发和可扩展性的前提下，应避免过度设计，确保代码具有良好的可读性、稳定性和可测试性。

如果您想深入了解领域驱动设计，可以阅读相关的专业书籍。对我而言，将其中的优点应用于我所遇到的项目，不会完全按照DDD规范去设计和开发，有时可能还会采用反模式。

### 从分层架构到分模型架构

通常，编写的应用程序中最多的是 CRUD。在这类项目中，分层架构得到了广泛应用。无论怎样变化，它大致都被分为 API/Service/DAO 三层。随着业务的发展，可能会出现一层内有 20 或 30 个文件，并且一个结构体的方法可能分布在不同的文件中。因此，组件也很难被复用于其他项目。

那么，为什么架构设计需要分层呢？分层架构的优点在于关注点分离、分而治之、低耦合和高内聚。

同样具备这些优点的是分模型架构，所谓分模型架构，基于模型驱动设计的思想，将复杂系统拆分为几个相关的模型。每个模型具有独立的职责，并且负责处理特定的功能，这种架构需要架构师对业务领域非常熟悉。

相比分层架构，它对行为上下文进行了更加明确的界限，使开发者可以专注于自己的领域模型。

领域就像积木，有简单的基层子域，也有依赖子域实现的更复杂领域。领域和子域几乎可以互换使用，这取决于对话上下文。

考虑到并不完全采用 DDD，但基于模型驱动设计，接下来将以“DDD lite”的方式称之，因 DDD 一语双关，D 可以是 Domain，可以是 Data。

## DDD lite 

Golang 有许多谚语，例如 `不要通过共享内存来进行通信，而是通过通信来共享内存`。 遵循这样的谚语可以提高编程体验和代码质量。

以下是与 DDD lite 相关的谚语，这些谚语甚至本身就是设计模式。它将帮助我们实现更好的架构设计。在设计时，应考虑到未来可能的需求变化，具备高度的可扩展性和灵活性；而在开发过程中，则需要根据当前的需求和限制，注重实现和可维护性，以达成交付可靠代码的目标。

### 通用语言

团队应该使用统一的术语表，这样在针对业务的讨论中就可以更加精准，不会出现词不达意、两个人说的不是同一件事的情况。

开发者应该在代码中使用这些术语、函数名和变量名，例如用“宝箱的开关”代替“设置属性为 true”。

有些人思维敏捷，可能会在上一秒谈论这个问题，下一秒谈论另一个问题。对于相似行为的页面，使用同一术语很容易造成误解，甚至在没有图片的情况下很难理解对方在说什么。

构建一种健壮、无处不在的语言，需要花费时间，没有捷径可走。在沟通和设计阶段，应记录任何术语，并将其添加到术语表中与其他同事分享。

尽管尝试在多个项目、团队甚至整个公司应用一种共通的语言可能很诱人，但这样做会导致术语失去严谨性，可能会造成混乱。因此，应谨慎考虑并选择最适合特定团队和项目的共通术语。

### 依赖倒置

以存储库为例，核心业务依赖于具体存储库的实现，则需要考虑到难以进行扩展，例如从 MySQL 迁移到 PostgreSQL。

为了方便解耦和测试，可以使核心业务与数据库无关，核心业务依赖抽象接口，实现一个简单的 `mockStore` 即可进行测试。

再举一个例子，当数据库成为瓶颈时，可以引入 Redis 缓存。由于核心业务依赖于抽象接口，因此可以扩展缓存实现接口来优化性能。

### 实战 REST ful 

我们按照以下的方式组织代码

```bash
.
├── config  		 # 配置相关代码
├── config.toml  # 配置文件
├── go.mod
├── go.sum
├── internal  	 # 项目业务
│   ├── api
│   │   ├── api.go
│   │   ├── message.go
│   │   └── user.go
│   └── core  # 核心业务
│       ├── message  # 消息领域
│       │   ├── message.go
│       │   ├── model.go
│       │   └── store
│       │       └── messagedb
│       │           └── db.go
│       └── user     # 用户领域
│           ├── model.go
│           ├── store
│           │   └── userdb
│           │       ├── db.go
│           │       ├── db_test.go
│           │       ├── record.go
│           │       └── user.go
│           ├── user.go
│           └── user_test.go
├── main.go
└── pkg     	# 工具包
```

代码的组织方式有很多种，这种较为简单，如果有多个 main 函数，即多个程序时，建议创建 `cmd` 文件夹，或更改目录结构以符合最适合业务的方式。

`internal` 是一个特殊的目录，它将限制包的导入范围，我们将业务所需全部放在该目录下。

底下包含两个主要目录，`api` 和 `core`。

+ api 是 REST ful Web 的具体实现。
+ core 是核心业务，包含的每个文件夹即是一个领域。
  + store 是数据存储，使用依赖倒置原则，领域行为依赖于抽象接口，存储库依赖于领域模型。

领域模型与数据库模型如果拆分，将需要写许多转换函数，通过依赖倒置原则，store 直接依赖领域模型。

接下来会涉及 Go 代码，写这篇文章时，我的安装的版本是 Go1.20.3。

案例: 查询两个用户对话的历史消息。

在 `[core] - [message]` 文件夹下，创建 `model.go` 文件，写入模型。

```go
type Message struct {
	orm.Model
  SenderID   int    `gorm:"notNull;default:0;index;comment:发送者"`   
  ReceiverID int    `gorm:"notNull;default:0;index;comment:接收者"`     
  Type       string `gorm:"type:text;notNull;default:'';comment:类型"`
  SessionID  int    `gorm:"notNull;default:0;index;comment:会话id"`     
	Content    []byte `gorm:"type:bytea; notNull; comment:消息"`
}

func (*Message) TableName() string {
	return "messages"
}
```

在 `[core]-[message]` 文件夹下，创建 `message.go` 文件，写入行为。

```go
// 数据存储抽象
type Storer interface{
  InsertOne(b orm.Tabler) error
  FindMessages(ms []Message, uid,sessionID,limit int)
}

type Core struct{
  ctx context.Context
  // 我非常确定，整个项目周期不会更换日志组件，这里直接依赖实现
  Log *zap.SugaredLogger 
  // 数据交互
  store Storer
}

// 使用值对象的优势是不用担心副作用
func NewCore(log *zap.SugaredLogger, store Storer) Core {
  return Core {
    ctx:     context.Background(),
		Log:     log,
		store:   store,
  }
}

// 每次访问，我们将使用 with 创建一个新的对象
// 拥有当前访问的下上文，以及记录追踪 ID 的日志
// 通过日志追踪，可以详细了解用户的操作行为
func (c Core) With(ctx context.Context, log *zap.SugaredLogger) Core {
	c.ctx = ctx
	c.Log = log
	return c
}

func (c Core) FindMessages(ms *[]*Message, uid,sessionID,limit int) error {
  if uid == 0 {
    return fmt.Errorf("uid 不能为空")
  }
  return c.store.FindMessages(
    ms, 
    uid,
    sessionID,
    limit,
  )
}
```

在 `[api]-[message.go]` 文件中实现 REST ful 

```go
type Message struct{
  core message.Core
}
func messageAPI(g *gin.Engine, cfg Config) error {
  store := messagedb.NewDB(cfg.DB)
  if err := store.AutoMigrate();err!=nil {
    return err
  }
  
  core := message.NewCore(zap.S(), store)
  m := Message{core:core}
  
  chat := g.Group("/chat", mid.AuthMiddleware(cfg.JWTSecret))
  chat.Get("/messages", m.FindMessages)
}

func (m Message) FindMessages(ctx *gin.Context) {
  core := m.core.With(
    ctx.Request.Context(), 
    m.core.Log.With("traceid", mid.TraceID(ctx))
  )
  
  var input struct {
    SessionID int `form:"session_id"`
  }
  if err:=ctx.ShouldBindQuery(&input);err!=nil{
    web.Fail(ctx, err)
    return
  }
  
  // ....
}
  
  

```



### 实战 gRPC

未完结，欲知后事如何，请听下回分解。

