---
title: nginx 入门
description: 
date: 2020-03-15 15:00:00
slug: 
image: 
draft: false
categories:
    - Golang
tags:
    - Go
---

# nginx



## 1. 配置文件语法

1. 每条指令以`;`结尾 , 指令与参数间以空格符号分隔;
2. 时间单位 :   `s m h d w M y`       `yyyy-MM-dd hh:mm:ss`
3. 支持正则表达式  ` localtion ~* \.(jpg | png | jpeg)$ {}`
4. 空间单位 :  不写单位默认是 byte ;   kb,mb,gb,  分别用 `k  m  g` 表示

常用变量

```bash
$binary_remote_addr    // 远端地址
```



##  2. nginx 命令行

重载配置文件 - 不停止服务

```bash
nginx -s reload
```

  

日至切割

> 手动切割

```bash
mv access.log access.log.back
nginx -s reopen
```



![image-20201205135525354](http://img.golang.space/1607147725951-image-20201205135525354.png)



## 3. 配置静态服务器

配置文件结构

![image-20201205195611772](http://img.golang.space/1607169372262-image-20201205195611772.png)

```bash
vim conf.d/default.conf
```

server 包含在 http 中

```nginx
http {
  
  gzip on;							# 开启压缩
  gzip_min_length 1k;  # 小于多少就不在压缩
  gzip_comp_level 2;    # 压缩级别
  gzip_types text/plain application/javascript application/x-javascript text/css application/xml text/javascript application/x-httpd-php image/jpeg image/gif image/png application/vnd.ms-fontobject font/ttf font/opentype font/x-woff image/svg+xml;

  
  server {
		listen 				8080;  			 #监听端口
		server_name		domain.org;  # 域名
		access_log		logs/domain.access.log main;  # 日志
		
		location / {
				alias lib/;  					# 所有的请求都去访问 lib/ 文件下
      
      
      # 反向代理
      proxy_set_header Host $host;		
      proxy_set_header X-Real-IP $remote_addr;  # 传递用户 IP
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for; # 用于传递所有 ip
      proxy_redirect off;
      proxy_pass http://127.0.0.1:8089
		}
		

	}
}
```



[http 核心模块文档](https://www.nginx.cn/doc/standard/httpcore.html)

> X-Forwarded-For 会记录每次跳转的 IP, 每一次反向代理都会记录 IP 到数组头部
>
> X-Real-IP 用户的公网 IP 



### server 块

**listen** 端口监听

```nginx
listen     8080; 
listen     127.0.0.1:8080;  # 只能本机的进程访问
```

可以监听端口 , 或者 ip 

**server_name** 域名

```nginx
server_name blog.golang.space;  
server_name blog.golang.space test.golang.space;# 可以配置多个域名
server_name *.golang.space;   # 所有子域名
server_name .golang.space;   # 主域名及子域名都包含
server_name_in_redirect off;  # on/off , on 表示会重定向到主域名(第一个参数)
```

![image-20201205215936515](http://img.golang.space/1607176776976-image-20201205215936515.png)

> 匹配顺序
>
> 1. 精确匹配
> 2. *在前的泛域名
> 3. *在后的泛域名
> 4. 文件顺序匹配正则表达式
> 5. default server
>    1. 第一个
>    2. listen 指定 default

![image-20201205222910376](http://img.golang.space/1607178550831-image-20201205222910376.png)

**rewrite ** 重定向

```nginx
rewrite regex replacement [flag]
rewrite ^/(.*) http://golang.space/$1 permanent;
```

> flag
>
> `last` 用 replacement URI 新的匹配
>
> `break`  指令停止
>
> `redirect` 302 临时重定向
>
> `permanent` 301 永久重定向

**location** 路径匹配

代码实例以优先级排序

```nginx
location = /xxx {}			# 精准匹配
location ^~ /images/ {} # 匹配以 /images/ 路径
location ~ /xxx {}	# 正则匹配所有 /xxx 开头路径
location ~* \.(gif|jpg|png)${} # 匹配 gif..结尾的路径
location / {}		# 优先级最低，匹配所有
```

> 优先级
>
> `=` 	>	 `/x/y`	 >	 `^~`	  >	 `~ `/`~*`	 >	 `/x` 	>	 `/`



## 3 ssl https 自动创建

**安装**

```bash
apt-get install python2-certbot-nginx
```

**执行**

```bash
certbot --nginx --nginx-server-root=/user/local/conf/ -d blog.golang.space
```

指定 nginx 配置文件, 获取证书并部署



### 常用关键字

### alias 分配指定位置的路径 

```nginx
location /i/ {
   alias /spool/w3/images/;
}
```

访问 `\i\top.gif` 时, 实际 nginx 访问路径 `/spool/w3/images/top.gif`

> 特征

1.  必须以 `/` 结尾
2.  只能在 location 块中
3.  会替换掉监听的路径 , 如上面的 `/i/`
4.  在正则匹配中 , 必须捕捉要匹配的内容 ( 此处还未理解如何使用 )

### root 指定请问文档根目录

```nginx
location /i/ {
  root /spool/w3;
}
```

访问 `/i/top.gif` 时, 实际 nginx 访问路径 `/spool/w3/i/top.gif`

> 特征

1. 结尾有没有 `/` 无所谓
2. 可以在 http , server, location, if 等多个块中使用
3. 实际访问路径是   root + path

### index 确定初始页

主要用于访问根目录时 , 文件夹目录时返回页面

```nginx
location / {
  index index.html;
}
```

当访问 `/` 的时候 , 没有指定任何文件, 会默认去访问 index.html;

> 特征

1. 这里并不是直接指定目录下 index.html 文件, 而是发起一个内部请求到 /index.html , 意味着可以加一个正则匹配, 如 `location ~ \.html${ root /data/www }` , 将真实请求地址设置为 `/data/www/index.html`

### try_files 尝试查找文件

```nginx
location / {
  try_files $uri $uri/ /index.html;
}
```

请求地址  :  `http://location/example`  ,  变量 `$uri` 就是 `/example`

此处先去查找这个文件, 没有找到就找目录, 还是没有就转到  `http://location/index.html`





## 4. 指令的继承规则

1. 子块继承父块
2. 子块存在则覆盖父块





## 非对称加密

![image-20201205183931722](http://img.golang.space/1607164772044-image-20201205183931722.png)

### 对称加密

![image-20201205183949884](http://img.golang.space/1607164790164-image-20201205183949884.png)







## 参考

https://juejin.im/post/6844903944267759624