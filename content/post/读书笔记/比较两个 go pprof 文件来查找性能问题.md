---
title: 比较两个 go pprof 文件来查找性能问题
description: 
date: 2025-06-30
slug: 
image: 
draft: false
categories:
    - Go
tags:
    - 读书笔记
    - 翻译
---



我费了好大劲才弄清楚，为什么这样一个看似无关紧要的变化会导致如此巨大的性能差异。最终，最有帮助的是 Go 工具链中一个很棒的工具：使用 `-base` 选项可视化两个性能配置文件之间的差异， `pprof` 。

## 使用 `pprof` 获取两个配置文件的差异

Go 语言自带一个强大的性能分析工具 `pprof` 。与其他一些语言不同，您必须在代码中显式启用它才能获取性能分析结果；您无法事后或使用命令行参数启用它。这很简单，但您必须编写代码才能实现。在我们的例子中，我将其直接放在要分析的测试方法中。

```go
func TestRegressionTests(t *testing.T) {
	// We'll only run this on GitHub Actions, so set this environment variable to run locally
	if _, ok := os.LookupEnv("REGRESSION_TESTING"); !ok {
		// t.Skip()
	}

	p := profile.Start(profile.CPUProfile)
	defer p.Stop()
```

此代码片段的最后两行启动 CPU 性能分析，并在方法完成时停止。它使用了 `github.com/pkg/profile` 包，该包为内置性能分析器库提供了一个更符合人体工程学的包装器。运行执行此操作的代码，您将看到如下输出：

```bash
2025/06/20 14:10:40.548730 profile: cpu profiling disabled, C:\Users\ZACHMU~1\AppData\Local\Temp\profile1113350212\cpu.pprof
```

这是运行生成的配置文件的位置，您应该记下它或将其复制到具有更容易记住的名称的其他位置。

为了测试，我想看看 `main` 分支和当前分支之间的性能变化，所以我在每个分支上都启用了性能分析功能，并进行了测试。现在，我可以使用 `-base` 参数和 `pprof` 来比较它们。

## 检查性能差异

获得每个分支的概况后，现在我只需要对它们进行比较。

```bash
go tool pprof -http=:8090 -base main.pprof branch.pprof
```

`-base` 标志告诉 `pprof` 在报告性能数据时，从另一个配置文件中“减去”指定的配置文件。在本例中，我想查看 `branch.pprof` 中发生的情况，而不是 `main.pprof` 运行太慢了。我还一直使用 `-http` 参数，它会运行一个交互式 Web 服务器，而不是命令行界面。我发现在分析性能配置文件时，使用这个参数要方便得多。

当我运行该命令时，我的 Web 浏览器会启动到默认显示界面，即一张按函数大致拓扑排序的累计 CPU 采样图，这样你就可以看到哪些函数调用了哪些函数。与普通的配置文件分析不同，这里显示的数字严格来说是两个配置文件之间的差异，而不是它们的绝对运行时间。以下是我在 Web 视图中看到的内容：

![cpu profile diff](http://img.golang.space/img-1751246974283.png)

`Database.tableInsensitive` 函数用于获取查询引擎使用的表对象。不知何故，尽管我没有直接修改它，但我的修改却使这个函数变得非常非常慢。有了这个线索，我找到了性能问题。

```go
// from tableInsensitive()

    ...

	tableNames, err := db.getAllTableNames(ctx, root, true)
	if err != nil {
		return doltdb.TableName{}, nil, false, err
	}

	if root.TableListHash() != 0 {
		tableMap := make(map[string]string)
		for _, table := range tableNames {
			tableMap[strings.ToLower(table)] = table
		}
		dbState.SessionCache().CacheTableNameMap(root.TableListHash(), tableMap)
	}

	tableName, ok = sql.GetTableNameInsensitive(tableName, tableNames)
	if !ok {
		return doltdb.TableName{}, nil, false, nil
	}
```

如果所有表名尚未缓存在会话中，则代码片段的第一行会从数据库中加载它们。这是必要的，因为我们的表名存储时区分大小写，而 SQL 不区分大小写。因此，在从数据库加载表的过程中，我们需要将查询中请求的不区分大小写的名称更正为区分大小写的名称，以便在存储和 I/O 层使用。但是，对 `db.getAllTableNames()` 的调用包含一个最终参数： `includeGeneratedSystemTables` 。它被硬编码为 true，这意味着它总是调用新的、更昂贵的方法来获取生成的系统表的列表，其中包括潜在的磁盘访问以获取数据库模式集，然后对它们进行大量的迭代。

```go
schemas, err := root.GetDatabaseSchemas(ctx)
	if err != nil {
		return nil, err
	}

	// For dolt there are no stored schemas, search the default (empty string) schema
	if len(schemas) == 0 {
		schemas = append(schemas, schema.DatabaseSchema{Name: doltdb.DefaultSchemaName})
	}

	for _, schema := range schemas {
		tableNames, err := root.GetTableNames(ctx, schema.Name)
		if err != nil {
			return nil, err
		}

		for _, pre := range doltdb.GeneratedSystemTablePrefixes {
			for _, tableName := range tableNames {
				s.Add(doltdb.TableName{
					Name:   pre + tableName,
					Schema: schema.Name,
				})
			}
		}

		// For doltgres, we also support the legacy dolt_ table names, addressable in any user schema
		if UseSearchPath && schema.Name != "pg_catalog" && schema.Name != doltdb.DoltNamespace {
			for _, name := range doltdb.DoltGeneratedTableNames {
				s.Add(doltdb.TableName{
					Name:   name,
					Schema: schema.Name,
				})
			}
		}
	}
```

事实证明，硬编码的 `true` 完全是错误的——该方法根本不需要考虑系统生成的表名。但在我让生成这些名称的过程变得更加昂贵之前，这是一个相对无害的错误，并且多年来一直存在于代码中而未被注意到。将此值更改为 `false` 以消除不必要的工作，修复了性能回归问题，并且还稍微加快了 Dolt 的基准测试速度。

| read_tests 读取测试               | from_latency | to_latency 延迟 | percent_change 百分比变化 |
| --------------------------------- | ------------ | --------------- | ------------------------- |
| covering_index_scan 覆盖索引扫描  | 0.68         | 0.67            | -1.4                      |
| groupby_scan                      | 19.65        | 19.29           | -1.83                     |
| index_join 索引连接               | 2.57         | 2.52            | -1.95                     |
| index_join_scan 索引连接扫描      | 1.44         | 1.44            | 0.0                       |
| index_scan 索引扫描               | 30.26        | 29.72           | -1.78                     |
| oltp_point_select                 | 0.29         | 0.28            | -3.45                     |
| oltp_read_only                    | 5.37         | 5.28            | -1.68                     |
| select_random_points 选择随机点   | 0.61         | 0.6             | -1.64                     |
| select_random_ranges 选择随机范围 | 0.64         | 0.62            | -3.13                     |
| table_scan 表扫描                 | 32.53        | 31.94           | -1.81                     |
| types_table_scan 类型表扫描       | 127.81       | 125.52          | -1.79                     |

如果没有 `-base` 标志为我指明正确的方向，我不确定我是否能找出这种低效率的根源。

## 参考

本文翻译于 [Finding performance problems by diffing two Go profiles](https://www.dolthub.com/blog/2025-06-20-go-pprof-diffing/)