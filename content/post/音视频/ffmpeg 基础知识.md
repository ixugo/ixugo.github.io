---
title: FFmpeg 基础知识
description: 
date: 2022-11-25
slug: 
image: 
draft: false
categories:
    - 音视频
tags:
    - FFmpeg
---

# FFmpeg 基础知识

## ffmpeg 处理流程

从一种编码转换到另一种编码。

![image-20221113220831698](http://img.golang.space/img-1668348511785.png)

![image-20221113221212952](http://img.golang.space/img-1668348733039.png)

## 基本信息查询命令

| 命令      | 说明                | 命令       | 说明               |
| --------- | ------------------- | ---------- | ------------------ |
| -version  | 版本                | -formats   | 显示可用的格式     |
| -demuxers | 显示可用的 demuxers | -protocols | 显示可用的协议     |
| -muxers   | 显示可用的 muxers   | -filters   | 显示可用的过滤器   |
| -devices  | 显示可用的设备      | -pix_fmts  | 显示可用的像素格式 |
| -decoders | 显示可用的解码器    | -layouts   | 显示 channel 名称  |
| -encoders | 显示所有编码器      | -colors    | 显示识别的颜色名称 |
| -bsfs     | 显示比特率 filter   |            |                    |

![image-20221124165310226](http://img.golang.space/img-1669279990311.png)

+ `D` 表示解码器
+ `E` 表示编码器

## 录制命令

**使用 ffmpeg 录制屏幕**

```bash
ffmpeg -f avfoundation -r 30 -i 2 out.yuv
```

+ `-f`: 指定使用 avfoundation 采集数据，mac 下专用于音视频处理
+ `-i`: 指定从哪儿采集输入，是一个文件索引号
+ `-r`: 指定帧率



**使用 ffplay 播放视频**

```bash
ffplay -video_size 2560x1440 -pixel_format uyvy422 out.yuv
```

+ `-video_size`: yuv 中不包含视频大小，需要指定尺寸，在上面录制时就已给定。
+ `-pixel_format`: 播放帧格式与录制的格式必须相同，才能真确播放



**上面提到 -i 指定采集输入，如何查看索引号呢?**

```bash
ffmpeg -f avfoundation -list_devices true -i ""
```

**使用 ffmpeg 录制音频**

```bash
ffmpeg -f avfoundation -i :2 out.wav
# 播放音频
ffplay out.wav
```

+ 注意这次序号前面加了`:`，冒号前面表示视频设备，冒号后面表示音频设备。

## 分解/复用命令

![image-20221124173349335](http://img.golang.space/img-1669282429474.png)

**将 mp4 转成 flv**

```bash
ffmpeg -i out.mp4 -vcodec copy -acodec copy out.flv
```

+ `-vcodec`: 视频编码处理方式，copy 表示使用原始格式q
+ `-acodec`: 音频编码处理方式

**抽取视频**

```bash
ffmpeg -i video.MP4 -an -vcodec copy out.h264
```

**抽取音频**

```bash
ffmpeg -i video.MP4 -vn -acodec copy out.aac
```

+ `-an`: audio null，表示过滤掉音频
+ `-vn`: video null，表示过滤掉视频

## 处理原始数据命令

**提前 YUV 数据**

```bash
ffmpeg -i video.MP4 -an -c:v rawvideo -pixel_format yuv420p out.yuv
```

+ `-c`: 指定编解码器
+ `-c:v`: 限定只处理视频画面，例如 `-c:v libx264`表示转换为 h264，`-c:v rawvideo`表是提取 YUV 数据，也可以`-c:v h264` 直接操作。
+ `-c:a`: 限定只处理音频声音，例如 `-c:a libmp3lame`，表示转换 mp3，也可以`-c:a mp3`直接操作。
+ `-c:s`: 限定只处理字幕

**提取 PCM 数据**

```bash
ffmpeg -i video.MP4 -vn -ar 44100 -ac2 -f s16le out.pcm
```

+ `-ar`: audio rate，指定音频采样率
+ `-ac`: audio channel，指定声道，2 表示双声道
+ `-f`: 指定格式，`s`有符号，`16`表示每个数值是 16 位

**播放 PCM 数据**

跟提取时一样，也要指定相关参数

```bash
ffplay -ar 44100 -ac 2 -f s16le out.pcm
```

## 裁剪与合并命令

**视频裁剪**

```bash
ffmpeg -i video.MP4 -c copy -ss 00:00:00 -t 10 out.ts
```

+ `-ss`: 开始裁剪时间，指定时分秒
+ `-t`: 裁剪市场，单位秒

**视频合并**

在合并之前，需要创建包含所有切片的文件

```bash
# input.txt
file '1.ts'
file '2.ts'
```

```bash
ffmpeg -f concat -i input.txt out.mp4
```

+ `-f concat`: 指定合并

## 图片/视频互转命令

**视频转图片**

配合视频裁剪有奇效。

```bash
ffmpeg -i video.MP4 -r 1 -f image2 image-%3d.jpeg

ffmpeg -i video.MP4 -ss 00:00:00 -t 5 -r 1 -f image2 image-%2d.jpeg
```

+ `-r`: 指定转换图片的帧率，`1` 表示每秒转出一张图片
+ `-f image2`: 指定 jpeg 编码器
+ `%3d.jpeg`: 这是一个动态增长的文件名，最大 3 位数，不足补 0。

**图片转视频**

```bash
ffmpeg -i image-%2d.jpeg out.mp4
```

## 直播推/拉流

**直播推流**

```bash
ffmpeg -re -i video.mp4 -c copy -f flv "rtmp://server/live/streamName"
```

+ `-re`: 减慢帧率速度，对于直播流来说，让帧率与声音保持同步
+ `-c copy`: 不做音视频编码

**直播拉流**

```bash
ffmpeg -i "rtmp://server/live/streamName" -c copy dump.flv
```

## 滤镜命令

倍速，画中画，修改长宽等。

![image-20221124195241972](http://img.golang.space/img-1669290762148.png)

**调整宽高**

```bash
ffmpeg -i video.MP4 -vf crop=in_w-200:in_h-200 -c:v libx264 -c:a copy out.mp4
```

+ `-vf`: 指定滤镜
+ `crop=in_w-200:in_h-200`: 修改宽高
+ `-c:v`: 视频编码

