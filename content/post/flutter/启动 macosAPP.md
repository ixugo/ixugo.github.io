---
title: Flutter 开发 Mac 应用
description: 
date: 2020-12-10
slug: 
image: 
draft: false
categories:
    - Flutter
tags:
    - Flutter
---

# MacOS



1 开启

```bash
flutter config --enable-macos-desktop
```



2 创建( 或已有项目添加 macOS )

```bash
flutter create .  # 这里的 . 号是在当前文件夹创建
```



3 运行

```bash
flutter run -d macOS
```



4 打包

```bash
flutter build macos
```



5 在 vscode 中创建启动驱动

```json
        {
            "name": "macOS",
            "request": "launch",
            "type": "dart",
            "deviceId": "macOS"
        },
```

![image-20200513140744769](http://img.golang.space/PicGo/image-20200513140744769.png)





## 开启网络权限



![image-20200603152634183](http://img.golang.space/PicGo/image-20200603152634183.png)











iphone7 

iOS 13 占70%，iOS 12 占23%，iOS 11 及之前版本占7%。

![image-20210331145001776](https://img.golang.space/1617173424650-1617173402063-image-20210331145001776.png)

