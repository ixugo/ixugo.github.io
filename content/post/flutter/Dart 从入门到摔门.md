---
title: Dart 语法基础
description: 
date: 2020-03-10
slug: 
image: 
draft: false
categories:
    - Flutter
tags:
    - Dart
---

# Dart 入门到摔门而去



[toc]






一切皆对象, null 都是对象 , 全部继承于 Object



## 概览

Dart 是一门强类型语言, 但是可以使用 var and dynamic , 前者用来自动识别类型, 后者标记为不确定类型 ;

支持泛型 : `List<int>`

标识符以下划线开头表示私有: `_private`

`Assert( boolean )`  方法可在开发过程中进行判断, boolean 是 false 时会抛出异常



## 语法基础

### 1. 入口函数
程序执行的入口函数, 有且只能有一个  main

### 2. 字符串输出方式

```dart
String str = "123";
print("该字符串是  $str");
// 如果是对象
print("该对象的 xx 字段是  ${obj.xx}");
// 多行字符串
var  str = """123
123
123
321""";
```
使用 `r` 前缀可以使特殊字符作为普通字符串



### 3. 内置类型

+ numbers
+ strings
+ booleans
+ lists
+ sets
+ maps
+ runes
+ symbols

>  numbers 包含 int 和 double

### 3.1 list
值可以重复, 类型可以不同
使用  `list.add()`  添加对象
`list.lenght` 获取长度

### 3.2 set
值不可以重复, 类型必须相同
`set.addAll()`  同类型集合添加现有集合

### 3.3 map
```dart
var git = {"h":1};
git["k"] = 2;  // 添加
var result = git["h"];  // 取, 如果没有则为 null, git 必须存在
```

### 4. 运算符

`is` 表示判断, `as` 表示转换
```dart
print("string" is String);  // true , 表示 前者是字符串类型
print("1" as String);          // 1, 如果 "1" 是 string 类型正常输出, 否则报错
// 常用在 if+is 判断类型, 使用一个 as 即可完成
if(emp is UserModel){
	emp.name = "";
}
// ->
(emp as UserModel).name = ""  // 如果 emp 为 null,或者不是 UserModel 对象,第一段代码不做任何事, 第二段代码报错
```

`??=`  赋值操作符
`kk ??= "123"`   如果 kk 为 null, 则 kk = "123" , 否则 kk=kk, 常用于样式中填充数据

`::` 级联符号
通过级联符号可以快速操作同一对象,  `emp.name="123"::age=15::sex="男"`

`?.` 条件成员访问符号
```dart
var name = emp?.name   // 如果 emp 为空, 则 name 为空 
```

以上符号组合常用场景
> 从 api 获取数据时
```dart
var name = data["name"]
...Text(name??="用户名")
```



```dart
// Valid compile-time constants as of Dart 2.5.
const Object i = 3; // Where i is a const Object with an int value...
const list = [i as int]; // Use a typecast.
const map = {if (i is int) i: "int"}; // Use is and collection if.
const set = {if (list is List<int>) ...list}; // ...and a spread.
```



### 5. 闭包

在函数中嵌套匿名函数并返回, 就会形成闭包, 以图片为例, 变量 n 会递增

<img src="http://img.golang.space/PicGo/image-20200510131236514.png" alt="image-20200510131236514" style="zoom:50%;" />



### 6 类的构造函数

![image-20200510133420016](http://img.golang.space/PicGo/image-20200510133420016.png)

> 常量对象

![image-20200510133739598](http://img.golang.space/PicGo/image-20200510133739598.png)



![image-20200510134401592](http://img.golang.space/PicGo/image-20200510134401592.png)



#### 6.1 访问器和存储器   get set

![image-20200510140210737](http://img.golang.space/PicGo/image-20200510140210737.png)

![image-20200510140241531](http://img.golang.space/PicGo/image-20200510140241531.png)



### 7 工厂构造方法

![image-20200510140933912](http://img.golang.space/PicGo/image-20200510140933912.png)

![image-20200510141122986](http://img.golang.space/PicGo/image-20200510141122986.png)



### 8 仿真函数

让类向方法一样调用

![image-20200510141456100](http://img.golang.space/PicGo/image-20200510141456100.png)



### 9 继承

![image-20200510142018848](http://img.golang.space/PicGo/image-20200510142018848.png)

方法和变量重写

![image-20200510142321937](http://img.golang.space/PicGo/image-20200510142321937.png)

子类重写父类构造方法

![image-20200510142627434](http://img.golang.space/PicGo/image-20200510142627434.png)





### ### 10 抽象类

![image-20200510143131500](http://img.golang.space/PicGo/image-20200510143131500.png)



### 11 接口

![image-20200510143913774](http://img.golang.space/PicGo/image-20200510143913774.png)

![image-20200510145520381](http://img.golang.space/PicGo/image-20200510145520381.png)



### 11 混合 

被混合的类不能有 显示构造方法 实现多继承的一种方式

<img src="http://img.golang.space/PicGo/image-20200510145934793.png" alt="image-20200510145934793" style="zoom:50%;" />

![image-20200510150004749](http://img.golang.space/PicGo/image-20200510150004749.png)



### 12 枚举

<img src="http://img.golang.space/PicGo/image-20200510152122226.png" alt="image-20200510152122226" style="zoom:50%;" />



### 13 泛型约束函数

<img src="http://img.golang.space/PicGo/image-20200510153026428.png" alt="image-20200510153026428" style="zoom:50%;" />

 类泛型

![image-20200510153143167](http://img.golang.space/PicGo/image-20200510153143167.png)





### 异步方法



#### 使用 future 

![image-20200510161120291](http://img.golang.space/PicGo/image-20200510161120291.png)





#### 使用 async 和 await



![image-20200510160923617](http://img.golang.space/PicGo/image-20200510160923617.png)

#### 多请求并发执行

![image-20200510163114722](http://img.golang.space/PicGo/image-20200510163114722.png)

链式请求执行

![image-20200510163255888](http://img.golang.space/PicGo/image-20200510163255888.png)



### 三种库

![image-20200510163438991](http://img.golang.space/PicGo/image-20200510163438991.png)

![image-20200510163653683](http://img.golang.space/PicGo/image-20200510163653683.png)

![image-20200510163948581](http://img.golang.space/PicGo/image-20200510163948581.png)

![image-20200510164511188](http://img.golang.space/PicGo/image-20200510164511188.png)



### 流

![image-20200510165502007](http://img.golang.space/PicGo/image-20200510165502007.png)

创建一个流控制器, 监听流, 如果发现添加数据, 就输出

sink 插入

stream 弹出

![image-20200510165349844](http://img.golang.space/PicGo/image-20200510165349844.png)



### 值传递与引用传递

基础数据类型都是值传递

+ string
+ int
+ bool
+ double

对象都是引用传递

+ set
+ map
+ class



