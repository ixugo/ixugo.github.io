---
title: Kafka
description: 
date: 2022-04-01 
slug: 
image: 
draft: true
categories:
    - 消息队列
tags:
    - 读书笔记
---



# Kafka



## 消息队列的两种模式

1. 点对点模式

   消费者主动拉取数据，消息收到后清除消息

2. 发布/订阅模式

   可以有多个 topic 主题

   消费者消费数据后，不删除数据

   每个消费者互相独立，都可以消费到数据

![image-20220612180752506](http://img.golang.space/shot-1655028472678.png)

## Kafka 基础架构

一个 topic 分为多个 partition

![image-20220612181459422](http://img.golang.space/shot-1655028899517.png)

