---
title: SQLite 实现双写 DB 让读性能翻倍
description: 
date: 2025-11-25
slug: 
image: 
draft: false
categories:
    - Go
tags:
    - 实践笔记
---



## 背景说明

流媒体服务不同于传统服务，有着高并发，高负载，高带宽等特性，当 24 小时不间断写录像时，磁盘 IO 瓶颈造成的最明显问题，是读取数据变慢了。

在机械硬盘上测试，PostgreSQL 与 SQLite 在磁盘 IO 高负载的情况下，读取速度几乎无差别，因嵌入式的特性，服务与数据库也没办法分离到多台服务器。

有哪些办法解决这个问题呢? 使用 Redis 缓存当然是一个好办法，但需要维护一份 Redis 实例，为了确保数据库与 Redis 的数据同步，启动时需要将数据库全部内容有结构的缓存到 Redis，启动效率会变慢。当有结构以后，分页查询，数据更新等等，应用层的代码逻辑会更复杂。

所以希望能有一个代码复杂度较低，能够保证数据一致性，简单性，适合嵌入式的缓存方案。

在避免大量改动代码的情况下，从调用上来说缓存还得用数据库，内存数据库，有以下两种解决方案。

+ 单内存 DB + 定期持久化到磁盘
+ 双 DB (内存 + 磁盘)

前者数据一致性弱，在上一次持久化结束到下一次持久化之前，期间发生崩溃数据就会丢失，每次持久化要全量持久化，每次持久化时会增加磁盘 IO。

后者还是读写数据库，缺点是要写两个数据库，一个内存数据库，一个磁盘数据库，其写性能会略有下降，读性能翻倍提升。

接下来围绕双写 DB 说说实践，核心特点:

+ 读只读内存数据库，毫秒级响应
+ 写入同时写入内存和磁盘，保持持久化
+ 对业务层完全透明，无需修改任何 GORM 代码
+ 支持崩溃恢复，启动时从磁盘恢复数据

## SQLite

### Memory

使用特殊文件名 `:memory:` 打开内存数据库，执行以下命令，不会打开任何磁盘文件，只会在内存中创建一个新的数据库。

+ 一旦数据库连接关闭，该数据库将不复存在
+ 打开多个，会创建多个独立的内存数据库

```bash
# 以下三种命令都是打开内存数据库
rc = sqlite3_open(":memory:", &db);
rc = sqlite3_open("file:memory:", &db);
ATTACH DATABASE 'file::memory:' AS aux1;
```

### ATTACH DATABASE

将另一个数据库文件添加到当前数据库连接中，方便数据恢复。

## GORM

业务中使用 GORM 库，gorm 获取 `ConnPool` 处理 SQL，所以自定义的 DualDB 要实现该接口。

+ 写入路径:  GORM -> QueryContext (磁盘库 + 内存库)
+ 查询路径: GORM -> QueryContext(内存库)
+ DDL 路径: GORM -> ExecContext(内存库 + 磁盘库)
+ 崩溃恢复: ATTACH -> 将结构/数据/索引完整复制到内存DB

```go
type ConnPool interface {
	PrepareContext(ctx context.Context, query string) (*sql.Stmt, error)
	ExecContext(ctx context.Context, query string, args ...interface{}) (sql.Result, error)
	QueryContext(ctx context.Context, query string, args ...interface{}) (*sql.Rows, error)
	QueryRowContext(ctx context.Context, query string, args ...interface{}) *sql.Row
}
```

+ **PrepareContext** 在内存库上准备 SQL 语句
+ **ExecContext** 执行 DDL/DML，双写
+ **QueryContext** 主要执行查询(读内存)，或智能双写，尤其要注意，含有 `RETURNING` 子句的 `Create/Update/Delete` 是由此函数执行，而非 `ExecContext`，需要检测 SQL 前缀判断是否应该双写数据库。
+ **QueryRowContext** 执行单行查询(读内存)

实现事务支持

```go
type ConnPoolBeginner interface {
	BeginTx(ctx context.Context, opts *sql.TxOptions) (ConnPool, error)
}
type TxCommitter interface {
	Commit() error
	Rollback() error
}
```

+ **BeginTx** 开始双写事务
+ **Commit** 事务提交
+ **Rollback** 事务回滚

## 结果对比

在磁盘 IO 高负载的环境下，机械硬盘上进行测试，这里对比了三种模式。

+ 第一种模式不做任何优化
+ 第二种模式是 durlDB，牺牲一定的写性能，换取翻数倍的读取性能
+ 第三种模式是采用 SQLite 配置缓存优化，需要同时提升读写性能可以根据 SQLite 官方文档优化

| 模式 | 写入 TPS | 读取 TPS | 写入延迟 | 读取延迟 |
|------|----------|----------|----------|----------|
| 模式 1: 默认 | 144.50 | 146.80 | ~4.34s | ~4.26s |
| 模式 2: DualDB | 52.00 | **1046.30** | ~12.42s | **~490.30ms** |
| 模式 3: 默认+缓存优化 | **440.10** | 443.00 | **~1.20s** | ~1.20s |

DualDB 适合以下场景:

+ 读多写少
+ 对读取延迟敏感的场景
+ 磁盘 IO 成为瓶颈的场景

如果需要同时提升读写性能，可以参考，首次是没有缓存的，高负载情况下，首次读取还是很慢的。

```go
dsn := "data.db?" +
    "_pragma=cache_size(-307200)&" +  // 300MB 页缓存
    "_pragma=mmap_size(314572800)&" + // 300MB 内存映射
    "_pragma=synchronous(NORMAL)&" +  // 减少 fsync
    "_pragma=journal_mode(WAL)&" +    // WAL 模式
    "_pragma=temp_store(MEMORY)"      // 临时表在内存
```
