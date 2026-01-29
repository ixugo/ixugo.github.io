---
title: Livekit Egress
description: 
date: 2026-01-25 
slug: 
image: 
draft: false
categories:
    - WebRTC
tags:
    - Go
    - Livekit
---

LiveKit Egress 是 LiveKit 实时音视频平台中的一个核心功能模块，用于将实时音视频导出为录制文件，并支持上传到云存储。它会以虚拟参与者的身份加入指定 Room，接收音视频流，使用 GStreamer 或 FFmpeg 等多媒体框架进行合成，编码和输出。

一个房间录像大概占用 4 核 CPU。

## Livekit Egress 录像

LiveKit 通过 Redis 与 LiveKit Egress 通信，使用 SDK 调用录像开启和停止，但是如何知道录像的状态呢?

LiveKit 提供了 [webhook](https://docs.livekit.io/intro/basics/rooms-participants-tracks/webhooks-events/)，其中有关于 Egress 存在 3 种回调:

**Egress Updated 出口已更新**

```typescript
interface WebhookEvent {
  event: 'egress_updated';
  egressInfo: EgressInfo;
}
```

**Egress Ended 出口已关闭**

```typescript
interface WebhookEvent {
  event: 'egress_ended';
  egressInfo: EgressInfo;
}
```

**Egress Started Ingress 已启动**

```typescript
interface WebhookEvent {
  event: 'egress_started';
  ingressInfo: EgressInfo;
}
```

**三种回调的触发流程如下**

1. SDK 调用启动录像，收到 `egress_started`，状态为 `EGRESS_STARTING`
2. 激活录像，收到`egress_updated`，状态为 `EGRESS_ACTIVE`
3. SDK 调用停止录像，收到 `egress_updated`，状态为 `EGRESS_ENDING`
4. 录制结束，收到 `egress_ended`，状态为 `EGRESS_COMPLETE`

### 输出文件

录制完成后，存储里面会增加 2 个文件，一个是 `<egress_id>.json` ，另一个是 `xxx.mp4`。

前者用于描述录像的开始时间，结束时间，房间号等信息，数据结构如下。

```json
{"egress_id":"EG_n2CdKF8XU4vD",
 "room_id":"RM_uidV4uaQornX",
 "room_name":"ro9ng2u",
 "started_at":1768979059503804853,
 "ended_at":1768979081731428616,
 "files":[{"filename":"/records/meeting/ro9ng2u_20260121_150418.mp4",
           "location":"/records/meeting/ro9ng2u_20260121_150418.mp4"}]
}
```

有 webhook 回调过来包含了以上数据，可以指定 `DisableManifest=true` 禁用这个文件的创建，节省存储空间。

```go
req.FileOutputs = []*livekit.EncodedFileOutput{
		{
			FileType:        livekit.EncodedFileType_MP4,
			Filepath:        recordPath,
			DisableManifest: true,
		},
	}
```

可以在 SDK 指定上传到 s3

```go
req.FileOutputs[0].Output = &livekit.EncodedFileOutput_S3{
  S3: &livekit.S3Upload{},
}
```

了解以上知识后，可以通过 webhook 将录像的元数据存入数据库，根据业务需要查询录像，录像文件存储到 s3 云存储，通过接口重定向到含有鉴权的 MP4 播放地址。

### 回调重试

Webhook 是由 LiveKit 发送到指定后端的 HTTP 请求。由于该协议基于推送的特性，无法保证其交付成功。

LiveKit 旨在通过多次重试 Webhook 请求来缓解瞬态故障。每条消息在被放弃之前都会经过多次投递尝试。如果多个事件排队等待投递，LiveKit 会对其进行正确的排序；仅在较旧的事件投递或放弃后才投递较新的事件。

如果后端服务不稳定无法接收处理请求，是有概率导致丢失未入库的! 

1. 通过负载均衡确保后端服务高可用
2. 订阅三种事件，都做入库处理

上传 s3 时还可以放到临时目录，收到录像完成事件则移动到正式目录，可以定期遍历临时目录，进行同步。

## 参考

[LiveKit WebHook](https://docs.livekit.io/intro/basics/rooms-participants-tracks/webhooks-events/)

