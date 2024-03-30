---
title: WebRTC 入门
description: 
date: 2023-11-12 
slug: 
image: 
draft: false
categories:
    - 音视频
tags:
    - WebRTC

---



WebRTC 是 Web 实时通信（Real-Time Communication）的缩写，它既是 API 也是协议。WebRTC 协议是两个 WebRTC Agent 协商双向安全实时通信的一组规则。

可以用 HTTP 和 Fetch API 之间的关系作为类比。WebRTC 协议就是 HTTP，而 WebRTC API 就是 Fetch API。

## WebRTC 协议是一组其他技术的集合体

![image-20231112215721642](http://img.golang.space/img-1699797441816.png)

### 信令：peer 如何在 WebRTC 中找到彼此

当 WebRTC Agent 启动时，它不知道与谁通信以及他们将要通信的内容。信令解决了这个问题！信令用于引导呼叫，以便两个 WebRTC Agent 可以开始通信。

信令使用一种现有的协议 SDP（会话描述协议）。SDP 是一种纯文本协议。每个 SDP 消息均由键 / 值对组成，并包含“media sections（媒体部分）”列表。

任何适合发送消息的架构均可被用于传递 SDP 信息，许多应用程序都使用其现有的基础设施（例如 REST 端点，WebSocket 连接或身份验证代理）来解决适当客户端之间的 SDP 传递问题。

### 使用 STUN/TURN 进行连接和 NAT 穿透 

ICE（交互式连接建立）是 WebRTC 前现有的协议。ICE 允许在两个 Agent 之间建立连接。这些 Agent 可以在同一网络上，也可以在世界的另一端。ICE 是无需中央服务器即可建立直接连接的解决方案。

### 使用 DTLS 和 SRTP 加密传输层 

第一个协议是 DTLS（数据报传输层安全性），即基于 UDP 的 TLS。

第二种协议是 SRTP（安全实时传输协议）。

首先，WebRTC 通过在 ICE 建立的连接上进行 DTLS 握手来进行连接。与 HTTPS 不同，WebRTC 不使用中央授权来颁发证书。相反，WebRTC 只是判断通过 DTLS 交换的证书是否与通过信令共享的签名相符。

接下来，WebRTC 使用 RTP 协议进行音频 / 视频的传输。我们使用 SRTP 来保护我们的 RTP 数据包。我们从协商的 DTLS 会话中提取密钥，用来初始化 SRTP 会话。

### 通过 RTP 和 SCTP 进行点对点通信

RTP（实时传输协议）和 SCTP（流控制传输协议）。我们使用 RTP 来交换用 SRTP 加密过的媒体数据，使用 SCTP 发送和接收那些用 DTLS 加密过的 DataChannel 消息。

