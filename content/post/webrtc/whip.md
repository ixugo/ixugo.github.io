---
title: 什么是 WHIP 和 WHEP
description: 
date: 2023-11-21
slug: 
image: 
categories:
    - WebRTC
---



## 什么是 WHIP 和 WHEP ?

WHIP 表示 WebRTC-HTTP 入口协议，WHEP 表示 WebRTC-HTTP 出口协议。

WebRTC 明确决定不适用任何信令协议，以便开发人员能够选择任何现有信令协议。对于流媒体行业来说不是一件好事，大家需要一个众所周知的协议和现成的实现，于是乎产生了 WHIP 和 WHEP。

在直播例子中，主播将本地媒体传到媒体服务器，就是 WHIP 的用武之地，另一端用户可以在媒体服务器出口端获取流。

在视频会议中，WebRTC 消除了很多复杂性，对于用户来说可能仅仅是加载网页就能开始会议。

流媒体行业不同，它依赖 3 个组件，这 3 个组件可能来源于不同的提供者。

1. 媒体服务器
2. 媒体源，通常是网络摄像机
3. 观众

WHIP 和 WHEP 正是连接三者的答案，WHIP 将媒体源连接到媒体服务器，WHEP 将媒体服务器连接观众。

在流媒体行业，WebRTC 可能是临时方案，未来更可能是 `WebTransport+WebCodecs+WebAssembly ` 的替代方案。



## 参考

[翻译 WHIP & WHEP: Is WebRTC the future of live streaming?](https://bloggeek.me/whip-whep-webrtc-live-streaming/#h-what-are-whip-and-whep)