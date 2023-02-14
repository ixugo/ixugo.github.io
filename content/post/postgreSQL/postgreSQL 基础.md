---
title: PostgreSQL 基础
description: 
date: 2020-02-23 12:00:00
slug: 
image: 
draft: false
categories:
    - 数据库
tags:
    - PostgreSQL

---



#  PostgreSQL



[toc]



## 1. 安装

### 1.1. linux 命令行安装

```bash
sudo apt-get install postgresql
su - postgres
psql
```

 linux 服务管理命令 service

```bash
service postgresql status     // 查看状态
service postgresql stop       // 停止
service postgresql start      // 开始                                                               
```

### 1.2. 使用 docker-compose

```bash
mkdir plv8 && cd plv8
vim docker-compose.yml
```

```yaml
postgres:
  restart: always
  image: ionx/postgres-plv8:12.2
  environment:
    - POSTGRES_PASSWORD=123456789
    - TZ=Asia/Shanghai
  volumes:
    - $PWD/data:/var/lib/postgresql/data
    - /etc/localtime:/etc/localtime
  ports:
    - "8001:5432"      # 端口映射
```





`postgresql.conf` 配置文件

```bash
listen_addresses = '*'   # 监听 IP 地址, 若是 localhost 表示仅本地可以连接
port = 5432              # 数据库端口

logging_collector = on   # 日志收集
log_directory = 'log' 	 # 日志目录

shared_buffers = 128MB   # 共享内存大小, 有足够内存时, 可以设置大一些
work_mem = 4M            # 单 sql 执行时, 排序,hash join 使用的内存
```

> 日志方案 1 每天新生成一个文件
>
> ```bash
> log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'
> log_truncate_on_rotation = on				
> log_rotation_age = 1d								# 循环
> log_rotation_size = 0								
> ```

> 日志方案 2 写满一定大小, 如 10m 则切换日志
>
> ```bash
> log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'
> log_truncate_on_rotation = off				
> log_rotation_age = 0							
> log_rotation_size = 10M					
> ```

> 日志方案 3 保留 7 天日志, 循环覆盖
>
> ```bash
> log_filename = 'postgresql-%a.log'
> log_truncate_on_rotation = on
> log_rotation_age = 1d							
> log_rotation_size = 0					
> ```



## 2. SQL 简单提一下

SQL 区分 DQL (查询), DML(插入/更新/删除数据) , DDL(创建/修改/删除表)

### 2.1. DDL

创建表

```sql
create table <tab_name> (
	col_name integer
  age integer
);
```

删除表

```sql
drop table <tab_name>
```

### 2.2. DML

插入数据

```sql
Insert INTO <tab_name> VALUES(2);
```

指定列插入数据

```sql
Insert INTO <tab_name>(age) VALUES(17);
```

更新语句 , 不设置条件会更新表中所有数据

```sql
update <tab_name> SET age = 18;
```

更新多条且设置 where 条件

```sql
update <tab_name> SET col_name = 1,age=19 WHERE age=18;
```

`DELETE FROM` 删除 , 当没有 `where` 关键词时, 表示删除整个表, 

```sql
DELETE FROM <tab_name> WHERE age = 19;
```

### 2.3. DQL

排序 `order by `

```sql
SELECT * FROM <tab_name> ORDER BY age DESC,col_name;
```

分组查询 `group by` 需要使用聚合函数

```sql
SELECT age,count(id) FROM <tab_name> GROUP BY age;
```

### 2.4. 其它 SQL 语句

`union` 两张表查询的数据整合到一起

+ `union` 重复的数据会合并为一条
+ `union all` 不合并重复数据

```sql
SELECT * FROM <tab_name> WHERE age = 18
UNION
SELECT * FROM <tab_name> WHERE col_name >= 2
```

删除表

+ `truncate table` 丢弃旧表, 创建新表, 重建索引
+ `delete from ` 一条条删除数据



### 3. PSQL

### 3.1. 使用方法

```bash
\l   						# 列出所有数据库
\c <database>		# 连接数据库
\d  						# 显示数据库中的表/序列/视图/索引
\d+             # 展示更多信息
\d <table>      # 显示表结构
\q   						# 退出
```

数据库安装好后, 有三个数据库

+  `postgre`  默认数据库
+  `template0` 最简化模板数据库
+  `template1` 用户新建数据库时, 默认从 `template1` 克隆, 通常可以定制 `template1` 的内容 , 

使用 PSQL 连接数据库

```bash
psql -h <ip> -p <5432> [数据库名称] [用户名称]
```

### 3.2. 常用命令

```bash
\dt # 列出表
\di # 列出索引
\ds # 列出序列
\dv # 列出视图
\df # 列出函数
\dn # 列出 schema
\db # 列出表空间
\du # 列出用户
\z  # 列出表的权限分配
\i <文件名> # 执行外部文件 SQL
\?  # 命令提示


\timing on  # 列出 sql 执行时间
```

### 3.3. 事务

```sql
begin;
-- dml 
commit;  
-- 或者
rollback;
```



## 4. 数据类型

### 4.1. 表格

| 类型       | 说明                                                         | 其它数据库对比                                               |
| ---------- | ------------------------------------------------------------ | ------------------------------------------------------------ |
| 布尔       | `boolean`                                                    | 与 mysql 类型相同, 一字节                                    |
| 整型       | `smallint` 2 字节 <br>`int` 4 字节 <br>`bigint` 8 字节       |                                                              |
| 浮点       | `real` 和 `double precision` <br>`money` 8 字节的货币类型 <br>`numeric(m,n)` 10 进制精确类型 |                                                              |
| 字符类型   | `varchar(n)` 变长字符 <br>`char(n)`  定长, 不足补空格 <br>`text` 长变文本,无限制 | Postgresql 的 varchar 最大可存储 1G <br>mysql 的 varchar 最大可存储 64kb |
| 二进制     | bytea                                                        | 对应 mysql 的 blob 和 longblob                               |
| 二进制位串 | `bit(n)`  <br>`bit varying(n)`                               | 无                                                           |
| 日期       | `date` 年月日 <br>`time` 时分秒 <br>`timestamp` 年月日时分秒 <br> |                                                              |
| 网络地址   | `cidr` 7-19字节, 网络地址 <br>`inet` 7-19字节, 网络或主机地址<br>`macaddr` 6 字节, 以太网 mac 地址 | 无                                                           |
| 数组类型   |                                                              |                                                              |
| 枚举类型   | 略                                                           |                                                              |
| 几何类型   | 略                                                           |                                                              |
| 复合类型   | 类似结构体                                                   |                                                              |
| xml        |                                                              |                                                              |
| json       | `json` 和 `jsonb`                                            |                                                              |
| range      | 范围类型                                                     |                                                              |
| 其它类型   | 不好分类的类型, 如 UUID                                      |                                                              |

### 4.2. 类型转换

方法一 标准 SQL 转换函数 `CAST`

```sql
select cast('5' as int),cast('2014-07-17' as date);
```

方法二 psql 双冒号转换

```sql
select '5'::int
```

### 4.3. boolean 类型

使用 boolean 类型, 可以约束非空, 设置默认值, 避免 SQL查询时还需要判断空的情况

### 4.4. 布尔类型操作符

AND

+ a,b 都是 null 为 null
+ a,b 都是 true, 为 true, 否则 false

OR

+ 存在 true 则为 true ,  
+ 若 a,b 都是 false ,存在 null 则为 null

NOT

+ `not null = null`
+ `not true = false`
+ `not false = true`

IS

布尔类型使用 `is` 比较

### 4.5. 字符串函数与操作符

拼接字符串

```sql
'Post' || 'greSQL'     # PostgreSQL
```

求字符串长度

```sql
char_length('post')    # 4
```

### 4.6. 二进制类型

适合存储图片/视频/文件类型

### 4.7. 时间类型

SELECT LOCALTIMESTAMP(0) - interval '15 day' 

`extract` 提取时间中的子域, 如年/月/日/时/分/秒

![image-20200705002012721](http://img.golang.space/1593879613247-image-20200705002012721.png)

### 4.8. 枚举类型

创建枚举, 插入时如果不是枚举中存在的字符串, 则报错

该类型大小写敏感,  `Sun` != `sun`

```sql
create type week as ENUM ('Sun','Mon','Tues','Wed','Thur','Fri','Sat')
```

查询所有枚举类型

```bash
\dT
```

### 4.9. json 类型

`json` 类型保留空格/格式/顺序

`jsonb` 类型存入时会转换二进制, 取用时不用再次转换, 更高效; 且不会保留空格/格式/顺序等

**操作符**

| 操作符 | 描述                                                         |
| ------ | ------------------------------------------------------------ |
| `->`   | 下标取数组元素  [1,2,3]::json->1  <br>key 取子对象  {"a":12,"b":13}::json->'a' |
| `->>`  | 同上, 取出来的结果是 text 类型                               |
| `#>`   | 取嵌套对象  {"a":{"b":{"c":1}}} :: json #> '{a,b}'           |
| `#>>`  | 同上, 取出来的结果是 text 类型                               |

有一些操作符仅可用于 `jsonb`

| 操作符 | 演示                                     | 说明                                      |
| ------ | ---------------------------------------- | ----------------------------------------- |
| `=`    | jsonb '[1,2]' = jsonb '[1,2]'            |                                           |
| `@>`   | jsonb '[1,2]' @> jsonb '[1]'             | 左边对象是否包含右边对象                  |
| `<@`   | ...                                      |                                           |
| `?`    | Jsonb '{"a":1,"b":1}' ? 'a'              | a 是否存在于对象的 key 或字符串类型元素中 |
| `?|`   | Jsonb '{"a":1,"b":1}' ?\| array['a','b'] |                                           |
| `?&`   | Jsonb '{"a":1,"b":1}' ?\| array['a','b'] | 数组中的内容是否都在 json 中              |

### 4.9.1. jsonb 类型创建索引

```sql
create index idx_name ON table_name USING gin (index_col)
```



## 5. 逻辑结构管理

修改数据库最大连接数

```sql
alter database testdb01 connection limit 10;
```

修改表名

```sql
alter table posts rename to postsNew
```

删除数据库

```sql
drop databse [if exists] name;
```

### 5.1. 创建模式

schema 是数据库的概念, 可以理解为命名空间或目录;

创建模式

```sql
create schema schema_name [authorization username];
```

删除模式

```sql
drop schema schema_name;
```

修改所有者

```sql
alter schema name owner to new_owner;
```

修改模式名

```sql
alter schema name rename to new_name;
```



### 常用函数

#### NULLIF

两个参数相等时，返回空值，否则返回 v1

```sql
NULLIF(v1,v2)
```

#### COALESCE

返回第一个非控参数的值，所有参数都为空时返回空

```sql
COALESCE(v1,[,...])
```

#### CASE

条件表达式

```sql
CASE 
	WHEN <条件> THEN <结果>
	[WHEN ...]
ELSE <结果>
END
```



