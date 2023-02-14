---
title: Flutter 开发插件
description: 
date: 2020-08-04
slug: 
image: 
draft: false
categories:
    - Flutter
tags:
    - Flutter
---

# Flutter 插件



```bash
flutter create -t plugin flutter_plugin_demo
```



## 1 原生插件(调用 java 或其它语言)

1. 通过 android studio 创建,  包含 java 和 ios 选择 flutter plugin , 纯 dart 选择 flutter package ,

2. 在 pubspec.yaml 中声明兼容平台

   ```yaml
     plugin:
       platforms:
         android:
           package: com.example.flutter_plugin_test
           pluginClass: FlutterPluginTestPlugin
         ios:
           pluginClass: FlutterPluginTestPlugin
         macos:
           pluginClass: FlutterPluginTestPlugin
         web:
           pluginClass: FlutterPluginTestPlugin
           fileName: flutter_plugin_test.dart
   ```

3. 在 项目名.dart 中创建方法

![image-20200408103156402](http://img.golang.space/PicGo/1586313116783-image-20200408103156402.png)

4. 调用该方法

![image-20200408103302373](http://img.golang.space/PicGo/1586313182627-image-20200408103302373.png)

5. 进入安卓底层目录, 使用 java 实现数据

![image-20200408103349386](http://img.golang.space/PicGo/1586313229555-image-20200408103349386.png)



> 参考

https://book.flutterchina.club/chapter12/develop_plugin.html



## 2 纯 dart 库

> 参考

https://book.flutterchina.club/chapter12/develop_package.html

1. 创建  flutter  package
2. 修改 pubspec.yaml 包相关信息, 输入 `flutter pub publish --dry-run` 测试是否合格

发布见 3 搭建私有仓库



## 3 搭建私有仓库   

1. 安装 dart

```bash
brew tap dart-lang/dart
brew install dart
```

2. 搭建环境

```bash
git clone https://github.com/dart-lang/pub_server.git
cd pub_server
pub get
dart example/example.dart -d /tmp/package-db
```

3. 将项目发布

```bash
flutter packages pub publish --server=http://localhost:8080
```

4. 谷歌验证

![image-20200408112444945](http://img.golang.space/PicGo/1586316285168-image-20200408112444945.png)

在浏览器中打开地址,  登录谷歌账户即可

![image-20200408112514209](http://img.golang.space/PicGo/1586316314347-image-20200408112514209.png)



参考:

官方提供快速搭建仓库  https://github.com/dart-archive/pub_server

如何上传插件  https://ejin66.github.io/2019/04/11/flutter_private_pub.html