---
title: Kubernetes 开发认证(CKAD)考试心得
description: 通过CKAD考试后，持证者即被认可能够为Kubernetes设计、构建、配置和部署云原生应用，在Kubernetes中能够定义应用程序资源，使用核心功能构建、监控和诊断可伸缩的应用程序。
date: 2022-07-04 
slug: 
image: http://img.golang.space/shot-1656933075470.png
draft: false
categories:
    - Kubernets
tags:
---



[Certified Kubernetes Application Developer (CKAD)](https://www.cncf.io/certification/ckad/)，认证 Kubernetes 应用开发人员。该考试由云原生计算基金会（CNCF）联合Linux基金会推出，旨在考察相关从业者对 Kubernetes 的运维和开发知识了解程度的认证考试。

CKAD 考试是一个完全动手的考试，需要您在多个Kubernetes集群中解决问题。您需要理解、使用和配置与应用程序开发人员相关的Kubernetes原语。 以官方说法，通过CKAD考试后，持证者即被认可能够为Kubernetes设计、构建、配置和部署云原生应用，在Kubernetes中能够定义应用程序资源，使用核心功能构建、监控和诊断可伸缩的应用程序。

这是我的证书。

![](http://img.golang.space/shot-1656929171060.jpg)



## 考试

我在 [Linux Foundation](https://training.linuxfoundation.cn/certificates/4) 购买的认证考试。原价是 2498，建议折扣活动期间购买，我是在黑色星期五买的。

![image-20220704182713362](http://img.golang.space/shot-1656930433445.png)

购买后在 "个人中心" - "我的考试"  可以看到考试券，需要去英文官网激活。

在这里 [预约考试](https://trainingportal.linuxfoundation.org/)，需要提前一天预约。具体步骤和相关说明官方文档都写的很清楚，建议查看 [官方文档](https://docs.linuxfoundation.org/tc-docs/certification/lf-handbook2)。

![Xnip2022-07-03_14-49-57](http://img.golang.space/shot-1656931286664.jpg)

![Xnip2022-07-02_14-55-17](http://img.golang.space/shot-1656931420130.jpg)

有两次模拟考的机会，一次是 36 个小时，模拟考试比正常考试更难，模拟考的题目始终是一样的，建议多刷几遍模拟考。

建议提前半个小时，点击启动考试，此时会跳转到相关页面，下载考试软件。我保留了下载地址分享给你 [考试软件 PSI 下载](https://home.psiexams.com/#/secure-browser)。

如果你的网络不好，软件会弹窗提示你，并只有一个退出选项 ! 我因为网络原因崩了 3 次。

打开软件后，跟着相关步骤操作，允许使用视频和声音，拍摄自己的身份证及考试房间的环境。等待了 10 分钟，会弹出与考官的会话窗口。如果前面的哪些步骤没有达到要求，考官会提示进一步操作。

考试时间是 2 个小时。因为做模拟考的时候感觉时间不是很充裕，所以真实考试时，我先迅速做题，不检查结果。实际上我还有足够的时间再检查一遍。打好基础，不用担心时间不够用。

考试环境的浏览器比较卡顿，页面内文字搜索点击没反应，总结有点不方便在 kubernets 官方寻找 yaml 配置。

注意复制和粘贴功能，windows 电脑需要多按一个 `SHEFT`， `CTRL + SHEFT +c/v`，Mac 电脑改成前面的操作，注意使用 `command +c/v` 是无效的，建议提前练习快捷键。

在考试结束后 24 小时内将会收到邮件，通知你的成绩。

![image-20220704185923134](http://img.golang.space/shot-1656932363215.png)



## 学习资料

[CKAD-exercises](https://github.com/dgkanatsios/CKAD-exercises)

[Kubernets 官方文档](https://kubernetes.io/zh-cn/docs/home/)

