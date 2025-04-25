---
title: typora 导出带图片的 html 
description: 
date: 2024-12-01
slug: 
image: 
draft: false
categories:
tags:
---



typora 在导出 HTML 文件时，其图片位置是根据写 markdown 时间定义的，比如在 markdown 中是网络图片，则导出 HTML 也是网络图片。

图片在编辑者本地，或图片在网络但 HTML 使用在离线环境，此时图片是无法正确加载的。

通过设置 typora 导出后执行命令，将图片替换成 base64 来解决以上问题。

### 测试环境

typora 1.9.4 

Macbook Pro

### 解决方案

1. 在 typora 导出设置中，给 html 类型导出后执行自定义命令 `~/typora_format_html ${outputPath}`，``~/typora_format_html` 是用于格式化 html 的可执行文件， `${outputPath}` 是导出后的文件路径。

![image-20241203001922342](http://img.golang.space/img-1733156369791.png)

![image-20241203002004434](http://img.golang.space/img-1733156404593.png)

2. 下载可执行文件 `https://github.com/ixugo/typora_plugin/releases/tag/v0.0.1`

此可执行文件由 Golang 编写，下载后存放路径要与第一步中填写路径名称相同。

正常执行导出 HTML 操作，查看文件可以发现图片已经是 base64。

![image-20241203002348395](http://img.golang.space/img-1733156628540.png)