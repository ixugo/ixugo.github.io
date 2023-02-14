---
title: Redis 基础
description: 
date: 2020-05-15
slug: 
image: 
draft: false
categories:
    - 数据库
tags:
    - Redis
---

# Redis

参考文档 :　http://redisdoc.com/



[toc]



## 一 linux 的环境软件安装

```bash
# 安装 服务器端
sudo apt-get install redis-server
# 检查服务器系统进程
ps -agx | grep redis
# 通过命令行访问
redis-cli
```

尝试操作

> 解决中文乱码, 启动时加参数 `--raw`

```bash
redis-cli --raw    # 可解决部分交互环境中出现的中文乱码问题
```

redis 安装完毕, 默认有 16 个数据库, 初始默认使用 0 号库, 编号 0,1,2...15

```bash
# 小试牛刀
set key1 value  # 增加一条记录
# 如果 value 是数字类型,可以自增
INCR key1   # 即+1操作
get key1   # 获取对应的值
select 1  # 切换数据库
keys *   # 查看当前库所有 key
dbsize   # 查看当前 key-val 数量
flushdb  # 清空当前数据库的key-val
flushall # 清空所有数据库的key-val

```



## 2. 基础知识

一般电商场景解决方案

![image-20210622102234872](http://img.golang.space/shot-1624328555140.png)

适用场景

![image-20210622102638951](http://img.golang.space/shot-1624328799167.png)

redis 存储的是 key,value 格式数据

其中的 key  都是字符串, value 有 ==5== 大数据类型

1. 字符串类型

2. 哈希类型   hash:map

3. 列表类型  list: linkedlist格式,支持重复元素

4. 集合类型  set : 不允许重复元素且无序

5. 有序集合类型  sortedset: 不允许重复元素,且元素有序



### 2.1. 使用 help 了解命令

```bash
help incr
```

![image-20210622102534680](http://img.golang.space/shot-1624328734880.png)



### 2.2. string 类型

**单个操作**

```bash
set key value  # set 如果key存在则修改, 不在则添加
get key  			 # get 获取
del key 			 # del 删除
strlen key     # 获取字符串长度
append key value  # 存储则追加，否则新建，返回追加后的长度
```

**多个操作**

```bash
mset mess1 北京 mess2 天安门  # mset 同时设置一个或多个 key-value
mget mess1 mess2  					# mget 同时获取多个值
```

**扩展操作**

```bash
# 增
incr key										# +1，返回+1 后的值
incrby key increment				# +increment 
incrbyfloat key increment		# 浮点操作

# 减
decr key										# -1
decrby key increment				# -increment

# 有效时间
setex message 10 北京天安门 # setex(set with expire) 设置有效时间为 10 秒
psetex key 10 故宫         # 设置有效期 10 毫秒

# 仅当值不存在时，写入
setnx key 13
```

![image-20210622103151314](http://img.golang.space/shot-1624329111510.png)

**操作注意事项**

![image-20210622103401218](http://img.golang.space/shot-1624329241396.png)



**应用场景**

![image-20210622104728443](http://img.golang.space/shot-1624330048662.png)

![image-20210622104737529](http://img.golang.space/shot-1624330057696.png)



### 2.3.  hash 类型

+ 对一系列数据编组，方便管理，典型应用存储对象信息
+ 底层使用 哈希表结构实现数据存储

**单个操作**

```bash
hset key age 15    # json 是这样表示  { "mess": { "age":15 } }
hset key name lucy # json 是这样表示  { "mess": { "age":"15", "name":"locy" } }

hget key field  				 # 获取
hdel key field1 [field2] # 删除
hgetall key  						 # 获取所有的键值对
```

**多个操作**

```bash
# 添加/修改
hmset key field1 value1 field2 value2  
# 获取
hmget key field1 field2
# 获取表中字段数量
hlen key
# 是否存在指定的字段
hexists key field
```

**扩展操作**

```bash
# 获取所有 key 或 value
hkeys key
hvals key

# 设置指定字段的数值增加指定范围的值
hincrby key field increment
hincrbyfloat key field increment

# 仅仅当字段不存在时设置该值
hsetnx key age 11
```

**注意事项**

![image-20210622162212465](http://img.golang.space/shot-1624350132727.png)

**应用场景**

![image-20210622162237279](http://img.golang.space/shot-1624350157495.png)

![image-20210622162334966](http://img.golang.space/shot-1624350215171.png)



### 3 list 类型

redis 列表是简单的字符串列表, 按照插入顺序排序, 可以添加元素到头部或者尾部 (即 队列)

该类型底层实现是双向链表

```bash
# 添加
lpush key value  # 左边添加
rpush key value  # 右边添加
# 获取
lrange key start end  # 范围获取
lrange key 0 -1       # 获取所有元素
# 删除
lpop key  # 弹出列表左边一个元素并返回
rpop key  # 弹出列表左边一个元素并返回
brpop key 5 # 弹出元素, 若是没有,最多等待5秒
```

**扩展操作**

```bash
# 规定时间内获取并移除元素
# 阻塞从链表获取数据，当链表为空时。等待最大时间内，入值就取出来
blpop key1 [key2] timeout   
brpop key1 [key2] timeout

# 移除指定数据
lrem key count value
```

**应用场景**

![image-20210623135848083](http://img.golang.space/shot-1624427928396.png)

![image-20210623135859264](http://img.golang.space/shot-1624427939479.png)

### 4 set 类型

![image-20210623135920728](http://img.golang.space/shot-1624427960948.png)

```bash
# 存储
sadd key member1 [member2]
# 获取
SMEMBERS key  # 获取 set 集合中所有元素
# 删除
SREM key member1 [member2] # 删除 set 集合中的某个元素
# 获取集合数据总量
scard key
# 判断集合中是否包含指定数据
sismember key member
# 随机获取集合中指定的数量的数据
srandmember key [count]
# 随机将数据移除集合
spop key
```

适合应用于随机推荐类信息检索，热点歌单推荐/热点新闻推荐/热卖商品/大 V 推荐/

![image-20210624114950774](http://img.golang.space/shot-1624506591157.png)

![image-20210624115018748](http://img.golang.space/shot-1624506619008.png)

![image-20210630124538714](http://img.golang.space/shot-1625028339037.png)

**注意事项**

+ set 类型不允许数据重复，如果添加的数据在 set 中已存在，将只保留一份
+ set 虽然与 hash 的存储结构相同，但是无法启用 hash 中存储值的空间

**应用场景**

+ 依赖 set 集合数据不重复的特征
+ 根据用户 ID 获取用户所有角色
+ 根据用户所有角色获取用户所有操作权限
+ 根据用户所有角色获取用户的所有数据

![image-20210630124738779](http://img.golang.space/shot-1625028458982.png)

![image-20210630124752214](http://img.golang.space/shot-1625028472415.png)

![image-20210630124822151](http://img.golang.space/shot-1625028502342.png)

![image-20210630124850404](http://img.golang.space/shot-1625028530607.png)





### 5 有序集合 ( sorted_set )

![image-20210630124918408](http://img.golang.space/shot-1625028558590.png)

有序/不允许重复/String类型

每个元素都关联一个 double 类型的数, 根据此数排序

```bash
# 添加
ZADD key score value [score2 value2]
# 获取
zrange key start end
zrange key 0 -1 withscores # 显示数据同时显示分数
zrange key 0 -1  # 获取全部数据
zrevrange key start stop # 倒序
# 删除
zrem key value
# 按条件获取数据
zrangebyscore key min max [withscores] [limit]
zrevrangebyscore key max min [withscores]
# 按条件删除数据
zremrangebyrank key start stop
zremrangebyscore key min max
# 获取集合数据总量
zcard key
zcount key min max
# 集合交/并操作
zinterstore destination numkeys key [key ...]
zunionstore destination numkeys key [key ...]

# 适合做动态排行榜
```

注意:

+ min 与 max 用于限定搜索查询的条件
+ start 与 stop 用于限定查询范围，作用于索引，表示开始和结束索引
+ offset 与 count 用于限定查询范围，作用于查询结果，表示开始位置和数据总量





### 通用命令

```bash
keys *    # 查询所有的键(可匹配正则)
type key  # 查询值的类型
del key   # 删除指定的 key and value
EXPIRE mess 10  // 设置 键为 mess 的元素 有效时间为 10 秒
```



### 持久化

redis 是一个内存数据库, 当 redis 服务器重启, 或者电脑重启, 数据会丢失, 可以将内存中的数据持久化保存到硬盘上



redis 持久化机制( 分别以 reb 和 aof 结尾 ):

+ RDB 默认方式, 不需要进行配置
    + 在一定间隔时间中,检测 key 的变化情况, 然后持久化数据( 见图1 图2)
+ AOF 日志记录的方式, 可以记录每一条命令的操作, 可以每一次命令操作好持久化数据 ( 图3 图4)
    + 即每一次操作都写入文件





# Go 使用 Redis

导入第三方包 :  	``"github.com/garyburd/redigo/redis"``

```go
//
// Author: leafsoar
// Date: 2017-05-04 16:29:03
//

package redic

import (
	"time"

	"github.com/garyburd/redigo/redis"
)

// Client 客户端
type Client struct {
	pool *redis.Pool
}

// NewRedisClient 创建客户端
func NewRedisClient(addr string) *Client {
	ret := &Client{
		pool: &redis.Pool{
			MaxIdle:     3,
			MaxActive:   1000,
			IdleTimeout: time.Second * 180,
			Dial: func() (redis.Conn, error) {
				// fmt.Println("new redis conn ...")
				c, err := redis.Dial("tcp", addr)
				if err != nil {
					return nil, err
				}
				_, _ = c.Do("select", 0)
				return c, nil
			},
		},
	}
	return ret
}

// Close 关闭所有链接
func (c *Client) Close() {
	c.pool.Close()
}

func (c *Client) do(commandName string, args ...interface{}) (reply interface{}, err error) {
	rc := c.pool.Get()
	reply, err = rc.Do(commandName, args...)
	_ = rc.Close()
	return
}

// Do 操作
func (c *Client) Do(commandName string, args ...interface{}) (reply interface{}, err error) {
	return c.do(commandName, args...)
}

// Set 设置值
func (c *Client) Set(key, value string) (err error) {
	_, err = c.do("SET", key, value)
	return
}

// Expire 失效
func (c *Client) Expire(key string, second int) (err error) {
	_, err = c.do("EXPIRE", key, second)
	return err
}

// Get 获取值
func (c *Client) Get(key string) (string, error) {
	return redis.String(c.do("GET", key))
}

// Del 删除
func (c *Client) Del(key string) (err error) {
	_, err = c.do("DEL", key)
	return err
}

// Push 队列
func (c *Client) Push(key string, value interface{}) (err error) {
	_, err = c.do("lpush", key, value)
	return
}

// Pop 默认为 list 的 brpop 操作
func (c *Client) Pop(key string, fn func(string, error)) {
	for {
		func() {
			time.Sleep(time.Millisecond * 800)
			rc := c.pool.Get()
			defer func() {
				_ = rc.Close()
			}()
			for {
				ret, err := redis.Strings(rc.Do("brpop", key, 5))
				if err == redis.ErrNil {
					return
				} else if err != nil {
					fn("", err)
					return
				}
				fn(ret[1], nil)

			}
		}()
	}
}

// PopByte 默认为 list 的 brpop 操作
func (c *Client) PopByte(key string, fn func([]byte, error)) {
	for {
		func() {
			time.Sleep(time.Millisecond * 800)
			rc := c.pool.Get()
			defer func() {
				_ = rc.Close()
			}()
			for {
				ret, err := redis.ByteSlices(rc.Do("brpop", key, 5))
				if err == redis.ErrNil {
					return
				} else if err != nil {
					fn(nil, err)
					return
				}
				fn(ret[1], nil)
			}
		}()
	}
}

```







## 一 连接池

![](http://img.golang.space/PicGo/20200213165147.jpg)

![](http://img.golang.space/PicGo/20200213165311.jpg)





## 二 字符串 set/get

![](http://img.golang.space/PicGo/20200213164955.jpg)



## incr 计数器

用于防止表单重复提交等问题

类似效果的有 `singleFight` ，其间隔时间为执行完当前函数

计数器可以通过设置过期时间，来延长提交间隔，一般 1 / 2 即可

```go
	r, err := uc.Do("incr", "123")
	if err != nil {
		fmt.Println(err)
	}
	k, _ := r.Result()
	// 业务
	if k.(int64) > 1 {
		return
	}
	uc.Do("EXPIRE", "123", 2)
	fmt.Println("开始业务", id)
```





封装计数器

此封装并未实现幂等，

```go
func Incr(k string, s int, fn func() (interface{}, error)) (interface{}, error) {
	r, err := uc.Do("incr", k)
	if err != nil {
		return nil, err
	}
	count, _ := r.Result()
	if count.(int64) != 1 {
		return nil, nil
	}
	_, err = uc.Do("expire", s)
	if err != nil {
		return nil, err
	}
	return fn()
}
```

测试

```go
func TestDemo(t *testing.T) {

	if uc == nil {
		return
	}
	var wg sync.WaitGroup
	for i := 0; i < 1000; i++ {
		wg.Add(1)

		go func(i int) {
			defer wg.Done()

			Incr("123", 2, func() (interface{}, error) {
				fmt.Println("123")
				return nil, nil
			})

		}(i)
	}
	wg.Wait()

}
```

