---
title: TUN & TAP
description: 
date: 2025-07-15
slug: 
image: 
draft: false
categories:
tags:
---



## 是什么?

tap 和 tun 都是虚拟网络内核接口，在创建网络连接方面起着至关重要的作用，在 `Linux Kernel 2.4.x` 版本后实现。

Tap（也称为以太网分流器）是在 OSI 模型的第 2 层运行的虚拟网络接口。它可用于将虚拟机、容器或其他网络设备连接到物理网络。Tap 接口通常用于桥接网络。

Tun 是 Tunnel 的缩写，是在 OSI 模型的第 3 层运行的虚拟网络接口。与 tap 接口不同，tun 用于点对点网络连接，通常用于 VPN（虚拟专用网络）实施。

在 `Linux Kernel 2.6.x` 之后的版本中， `tun/tap` 对应的字符设备文件分别为:

+ tap: /dev/tap0
+ tun: /dev/net/tun

当应用程序打开设备文件时，驱动程序就会创建并注册相应的虚拟设备接口，一般以 `tunX` 或 `tapX` 命名。当应用程序关闭文件时，驱动也会自动删除 `tunX` 和 `tapX` 设备，还会删除已经建立起来的路由等信息。

## 怎么用?

**tap**

```bash
# 创建
sudo ip tuntap add tap0 mode tap
# 查看
sudo ip link set tap0 up
# 分配 ip 地址
sudo ip addr add 192.168.0.1/24 dev tap0
```

**tun**

```bash
# 创建
sudo ip tuntap add tun0 mode tun
# 启动
sudo ip link set tun0 up
# 分配 ip 地址
sudo ip addr add 10.0.0.1/24 dev tun0
```

### 用 Golang 调用

注意，这里使用 `github.com/songgao/water` 库

通过文件字符设备读数据实验

```go
package main

import (
	"os"
	"os/signal"
	"syscall"

	"github.com/fatih/color"
	"github.com/songgao/water"
	flag "github.com/spf13/pflag"
)

var (
	tunName        = flag.String("dev", "", "local tun device name")
)

func main() {
	flag.Parse()

	// create tun/tap interface
	iface, err := water.New(water.Config{
		DeviceType: water.TUN,
	})
	if err != nil {
		color.Red("create tun device failed,error: %v", err)
		return
	}

	// 起一个协程去读取数据
	go IfaceRead(iface)

	sig := make(chan os.Signal, 3)
	signal.Notify(sig, syscall.SIGINT, syscall.SIGABRT, syscall.SIGHUP)
	<-sig
}

/*
	IfaceRead 从 tun 设备读取数据
*/
func IfaceRead(iface *water.Interface) {
	packet := make([]byte, 2048)
	for {
		// 不断从 tun 设备读取数据
		n, err := iface.Read(packet)
		if err != nil {
			color.Red("READ: read from tun failed")
			break
		}
		// 在这里你可以对拿到的数据包做一些数据，比如加密。这里只对其进行简单的打印
		color.Cyan("get data from tun: %v", packet[:n])
	}
}
```

通过文件字符设备写数据实验

```go
func IfaceReadAndWrite(iface *water.Interface) {
	packet := make([]byte, 2048)
	for {
		// 不断从 tun 设备读取数据
		n, err := iface.Read(packet)
		if err != nil {
			color.Red("READ: read from tun failed")
			break
		}

		// 再把数据原封不动写入 tun 设备
		_,err= iface.Write(packet[:n])
		if err != nil {
			color.Red("WRITE: write to tun failed")
			break
		}
	}
}
```

## Tap/Tun 的区别

`tun、tap` 作为虚拟网卡，除了不具备物理网卡的硬件功能外，它们和物理网卡的功能是一样的，此外tun、tap负责在内核网络协议栈和用户空间之间传输数据。

`tun` 和 `tap` 都是虚拟网卡设备，但是:

- `tun` 是三层设备，其封装的外层是 `IP` 头
- `tap` 是二层设备，其封装的外层是以太网帧`(frame)`头
- `tun` 是 `PPP` 点对点设备，没有 `MAC` 地址
- `tap` 是以太网设备，有 `MAC` 地址
- `tap` 比 `tun` 更接近于物理网卡，可以认为，tap设备等价于去掉了硬件功能的物理网卡

## 参考

[Tap vs Tun: A Comprehensive Guide](https://mangohost.net/blog/tap-vs-tun-a-comprehensive-guide/)

[Tun Tap and Veth for Fun](https://medium.com/@jain.sm/tun-tap-and-veth-for-fun-f86bceaf0366)

[Linux虚拟网络设备之tun/tap](https://www.ctyun.cn/developer/article/422668135063621)