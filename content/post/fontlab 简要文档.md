---
title: Fontlab 7 简要文档
description: 该文档主要帮助您快速了解软件如何操作
date: 2020-10-22
slug:
image: http://img.golang.space/1598929158698-image-20200901105918160.png
lastmod: '2020-10-22'
categories:
    - 杂记
---

# Fontlab 7 简要文档

该文档主要帮助您快速了解软件如何操作

官方英文手册 : https://help.fontlab.com/fontlab/7/manual/


[toc]

## 打开字体

![image-20200901105918160](http://img.golang.space/1598929158698-image-20200901105918160.png)



## 修改字体

您可以使用 `contour` - `create countour controller`  [轮廓](https://help.fontlab.com/fontlab/7/manual/Create-Parallel-Contour/) [描边](https://help.fontlab.com/fontlab/7/manual/Stroke-panel/ ) 或其它任意方式实现相同的功能, 这里仅仅提供一种作为参考



### 字体标记说明
黑线修改未保存
红线名称不合格
![image-20200901110152221](http://img.golang.space/1598929312498-image-20200901110152221.png)

### 字体加粗方法
1. 菜单栏选择  `window` - `panels` - `brush`, 打开画笔工具窗口
2. 确定图层选择的是当前文字, 点击 `set`, 拖动笔触大小, 可拖动箭头更改笔触方向, 完成 Expand
3. 最重要的是, 使用画笔描边必须填充空白部分! 快捷键 `F` 点击文字内空白处 , 避免出现空心字

小技巧 : 按空格键可查看字体效果
![说明](http://img.golang.space/1598930209044-2.gif)

### 字体减细方法
1. 菜单栏选择  `window` - `panels` - `brush`, 打开画笔工具窗口
2. 确定图层选择的是当前文字, 点击 `set`, 拖动笔触大小, 可拖动箭头更改笔触方向, 完成 Expand
3. 双击图层中的外框, 快捷键 `delete` 删除

![](http://img.golang.space/1598930685301-3.gif)

### 修改字体信息
在字体上右键选择`open glyph panel` , 修改第一行 , 快捷键`enter` 保存
![](http://img.golang.space/1598931704256-4.gif)

### 修改某个部首
打开图层, 双击某个部首, 添加新图层即可
其余修改参照 `2.1` `2.2`
![](http://img.golang.space/1598931975528-5.gif)

### 连笔笔画拆分
快捷键 `j` 选择刀具, 在合适位置划一刀, 点击节点割断, 快捷键 `a` 把各自接口重新连接
![](http://img.golang.space/1598933071456-7.gif)




## 保存为 TTF
菜单栏 `File` - `Export Font As...`
选择 `OpenType TT`, 修改保存位置等信息, `Export`根据文件大小稍等时长

![](http://img.golang.space/1598932254170-6.gif)

