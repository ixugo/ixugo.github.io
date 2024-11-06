---
title: TCP
description: 
date: 2024-04-05
slug: 
image: 
draft: true
categories:
    - Go
tags:
    - 读书笔记
---

TCP 允许您在网络上的节点之间可靠地传输数据。

TCP 是可靠的，因为它克服了数据包丢失或乱序接收数据包的影响。当数据无法到达目的地时，就会发生*数据包丢失*，通常是由于数据传输错误（例如无线网络干扰）或网络拥塞。当节点尝试通过网络连接发送超出连接处理能力的数据时，就会发生*网络拥塞*，导致节点丢弃多余的数据包。例如，您无法通过 10  (Mbps) 连接以 1  (Gbps) 的速率发送数据。 10Mbps 连接很快就会饱和，参与数据流的节点会丢弃多余的数据。

*TCP 会话*允许您向接收者传送任意大小的数据流，并接收接收者收到数据的确认。这可以帮助您避免通过网络发送大量数据而在传输结束时发现收件人没有收到数据的低效情况。

**通过 TCP 握手建立会话**

作为握手的第一步，客户端向服务器发送带有*同步 (SYN) 标志*的数据包。此 SYN 数据包通知服务器客户端的功能以及其余对话的首选窗口设置。我们很快就会讨论接收窗口。接下来，服务器用自己的数据包进行响应，并设置*确认 (ACK)*和 SYN 标志。 ACK 标志告诉客户端服务器确认收到客户端的 SYN 数据包。服务器的 SYN 数据包告诉客户端在会话期间它同意的设置。最后，客户端回复ACK数据包以确认服务器的SYN数据包，完成三向握手。

握手过程完成后建立 TCP 会话，然后节点可以交换数据。 TCP 会话保持空闲状态，直到任何一方有数据要传输。不受管理且长时间空闲的 TCP 会话可能会导致内存的浪费。

![image-20240819002002360](http://img.golang.space/img-1723998002525.png)

**使用序列号确认数据包的接收**

每个 TCP 数据包都包含一个*序列号*，接收者用它来确认收到每个数据包并正确排序数据包以呈现给您的 Go 应用程序。

一个 ACK 数据包可以确认从发送方收到一个或多个数据包。发送方使用 ACK 数据包中的序列号来确定是否需要重传任何数据包。例如，如果发送方发送了一堆序列号高达 100 的数据包，但随后从接收方收到了序列号为 90 的 ACK，则发送方知道需要重新发送序列号为 91 到 100 的数据包。

![image-20240819002241003](http://img.golang.space/img-1723998161125.png)

**接收缓冲区和窗口大小**

由于 TCP 允许单个 ACK 数据包确认收到多个传入数据包，因此接收方必须在发送确认之前向发送方通告其接收缓冲区中有多少可用空间。*接收缓冲区*是为传入数据保留的内存块在网络连接上。接收缓冲区允许节点从网络接受一定量的数据，而不需要应用程序立即读取数据。客户端和服务器都维护自己的每个连接接收缓冲区。当您的 Go 代码从网络连接对象读取数据时，它会从连接的接收缓冲区读取数据。

ACK 数据包包含一条特别重要的信息：*窗口大小*，即发送方无需确认即可传输到接收方的字节数。如果客户端向服务器发送窗口大小为 24,537 的 ACK 数据包，则服务器知道在期望客户端发送另一个 ACK 数据包之前可以向客户端发送 24,537 字节。窗口大小为零表示接收器的缓冲区已满并且无法再接收附加数据。我们将在本章稍后讨论这种情况。

客户端和服务器都跟踪彼此的窗口大小，并尽力完全填满彼此的接收缓冲区。这种在 ACK 数据包中接收窗口大小，发送数据，在下一个 ACK 中接收更新的窗口大小，然后发送更多数据的方法称为*滑动窗口*，如图[3-3](blob:https://app.immersivetranslate.com/574e00b2-1b37-4bec-a53c-8b65d92ed0e2#figure3-3)所示。连接的每一端都提供一个可以随时接收的数据窗口。

![image-20240819002951052](http://img.golang.space/img-1723998591189.png)

**优雅地终止 TCP 会话**

客户端通过向服务器发送FIN报文发起终止。

![image-20240819003132553](http://img.golang.space/img-1723998692693.png)

客户端的连接状态从ESTABLISHED变为FIN_WAIT_1，这表明客户端正在从一端断开连接，并等待服务器的确认。服务器确认客户端的 FIN 并将其连接状态从 ESTABLISHED 更改为 CLOSE_WAIT。服务器发送自己的 FIN 数据包，将其状态更改为 LAST_ACK，表示它正在等待客户端的最终确认。客户端确认服务器的FIN并进入TIME_WAIT状态，其目的是让客户端的最终ACK数据包到达服务器。客户端等待最大段生存期的两倍（根据 RFC 793，段生存期任意默认为两分钟，但您的操作系统可能允许您调整此值），然后将其连接状态更改为 CLOSED，无需来自客户端的任何进一步输入服务器。*最大分段生命周期*是指在发送方认为已放弃 TCP 分段之前，该分段可以保持传输状态的持续时间。在收到客户端的最后一个 ACK 数据包后，服务器立即将其连接状态更改为 CLOSED，完全终止 TCP 会话。

close_wait 是接收到对端的 fin 报文，但本地程序还没有调用 close 来关闭连接。

time_wait 是连接的主动关闭方，为了确保对方能收到最后一次握手的 ack 确认，而等待的一个固定时间。

**处理不太优雅的终止**

并非所有连接都会礼貌地终止。在某些情况下，打开 TCP 连接的应用程序可能会崩溃或由于某种原因突然停止运行。发生这种情况时，TCP 连接立即关闭。从前一个连接的另一端发送的任何数据包都会提示连接的关闭端返回*重置 (RST) 数据包*。 RST 数据包通知发送方，接收方的连接已关闭，将不再接受数据。发送方应该关闭自己的连接端，因为知道接收方会忽略它未确认的任何数据包。

中间节点（例如防火墙）可以向连接中的每个节点发送 RST 数据包，从而有效地从中间终止套接字。

**绑定、侦听和接受连接**

`net.Listen`函数接受网络类型以及由冒号分隔的 IP 地址和端口。该函数返回一个`net.Listener`接口和一个`error`接口。如果函数成功返回，则侦听器将绑定到指定的 IP 地址和端口。*绑定*意味着操作系统已将给定 IP 地址上的端口独占分配给侦听器。操作系统不允许其他进程侦听绑定端口上的传入流量。如果您尝试将侦听器绑定到当前绑定的端口， `net.Listen`将返回错误。

可以选择将 IP 地址和端口参数留空。如果端口为零或空，Go 将随机分配一个端口号给您的侦听器。您可以通过调用其`Addr`方法来检索侦听器的地址。同样，如果省略 IP 地址，您的侦听器将绑定到系统上的所有单播和任播 IP 地址。省略 IP 地址和端口，或者为`net.Listen`的第二个参数传递冒号，将导致您的侦听器使用随机端口绑定到所有单播和任播 IP 地址。

在大多数情况下，您应该使用`tcp`作为`net.Listener`第一个参数的网络类型。您可以通过传入`tcp4`将侦听器限制为仅使用 IPv4 地址，或者通过传入`tcp6`将侦听器专门绑定到 IPv6 地址。

**了解超时和临时错误**

需要一种方法来确定错误是暂时的还是需要完全终止连接的错误。 `error`界面没有提供足够的信息来做出该决定。

从`net`包中的函数和方法返回的错误通常实现`net.Error`接口，其中包括两个值得注意的方法： `Timeout`和`Temporary` 。如果操作系统告诉 Go 资源暂时不可用、调用将阻塞或连接超时，则`Timeout`方法在基于 Unix 的操作系统和 Windows 上返回`true`。

```go

// 三次握手
// 65218 → 54321 [SYN] Seq=0 Win=65535 Len=0 MSS=16344 WS=64 TSval=3559524061 TSecr=0 SACK_PERM
// 54321 → 65218 [SYN, ACK] Seq=0 Ack=1 Win=65535 Len=0 MSS=16344 WS=64 TSval=445334927 TSecr=3559524061 SACK_PERM EE0B=0 ECEB=0 EE1B=0
// 65218 → 54321 [ACK, ACE=0] Seq=1 Ack=1 Win=408256 Len=0 TSval=3559524061 TSecr=445334927

// [TCP Window Update] 54321 → 65218 [ACK, ACE=0] Seq=1 Ack=1 Win=408256 Len=0 TSval=445334927 TSecr=3559524061

// 四次挥手
// 65218 → 54321 [FIN, ACK, ACE=0] Seq=1 Ack=1 Win=408256 Len=0 TSval=3559524061 TSecr=445334927
// 54321 → 65218 [ACK, ACE=0] Seq=1 Ack=2 Win=408256 Len=0 TSval=445334927 TSecr=3559524061
// 54321 → 65218 [FIN, ACK, ACE=0] Seq=1 Ack=2 Win=408256 Len=0 TSval=445334927 TSecr=3559524061
// 65218 → 54321 [ACK, ACE=0] Seq=2 Ack=2 Win=408256 Len=0 TSval=3559524061 TSecr=445334927
func TestListener2(t *testing.T) {
	// 在 IP 地址 127.0.0.1 上创建一个侦听器，客户端将连接到该侦听器。
	// 省略了端口号，因此 Go 会为您随机选择一个可用的端口
	l, err := net.Listen("tcp", "127.0.0.1:54321")
	if err != nil {
		t.Fatal(err.Error())
	}
	done := make(chan struct{})
	go func() {
		defer func() {
			done <- struct{}{}
		}()

		// 除非只接受单个传入连接，否则要使用 for 循环
		for {
			// 此方法将阻塞，直到侦听器检测到传入连接并完成客户端和服务器之间的 TCP 握手过程。
			conn, err := l.Accept()
			// 如果握手失败或侦听器关闭，则错误接口将为nil
			// 此错误不一定是失败，因此您只需记录它并继续。
			if err != nil {
				if nErr, ok := err.(net.Error); ok && !nErr.Timeout() {
					t.Log("超时错误")
					return
				}

				t.Log("listener err:", err.Error())
				return
			}
			fmt.Println("remote: ", conn.RemoteAddr())
			// 为了同时处理客户端连接，您可以派生一个 goroutine 来异步处理每个连接
			go func(c net.Conn) {
				// 应当主动调用 close ，以确保优雅的而关闭
				// 在 goroutine 退出之前调用连接的Close方法 ，通过向服务器发送 FIN 数据包来优雅地终止连接。
				defer func() {
					c.Close()
					done <- struct{}{}
				}()

				// 它一次会从套接字读取最多 1024 个字节并记录它收到的内容
				buf := make([]byte, 1024)
				for {
					n, err := c.Read(buf)
					if err != nil {
						fmt.Println("read err:", err)
						// io.EOF错误，向侦听器代码表明您关闭了连接一侧。
						if !errors.Is(err, io.EOF) {
							t.Error("read err-:", err)
						}
						return
					}
					t.Logf("received: %q", buf[:n])
				}
			}(conn)
		}
	}()

	fmt.Println("server:", l.Addr().String())
	// 由于 IPv6 地址包含冒号分隔符，因此必须将 IPv6 地址括起来在方括号中。
	// 例如， "[2001:ed27::1]:https"指定 IPv6 地址 2001:ed27::1 处的端口 443
	conn, err := net.Dial("tcp", l.Addr().String())
	if err != nil {
		fmt.Println("dial err:", err)
	}
	fmt.Println("client conn close")
	conn.Close()
	<-done
	l.Close()
	<-done
}
```

**使用 DialTimeout 函数对连接尝试进行超时**

例如，如果您在交互式应用程序中使用`Dial`功能，并且操作系统在两小时后超时连接尝试，则应用程序的用户可能不想等待那么长。

您可能想要启动与低延迟服务的连接，该服务在可用时可以快速响应。如果服务没有响应，您将希望快速超时并转到下一个服务。

```go
func DialTimeout(network, address string, timeout time.Duration) (Conn, error) {
	d := Dialer{Timeout: timeout}
	return d.Dial(network, address)
}
```

**实施期限**

Go 的网络连接对象允许您包含读取和写入操作的截止日期。截止时间允许您控制网络连接可以保持空闲状态的时间长度，此时没有数据包经过连接。您可以使用连接对象上的`SetReadDeadline`方法控制`Read`截止时间，使用`SetWriteDeadline`方法控制`Write`截止时间，或使用`SetDeadline`方法控制两者。当连接达到其读取截止时间时，所有当前阻止的和未来对网络连接的`Read`方法的调用都会立即返回超时错误。同样，当连接达到其写入截止时间时，网络连接的`Write`方法会返回超时错误。

Go 的网络连接默认没有设置任何读写操作的截止时间，这意味着你的网络连接可能会长时间保持空闲状态。这可能会阻止您及时检测网络故障，例如拔出的电缆，因为当没有流量传输时，检测两个节点之间的网络问题更加困难。

```go

func TestDeadline(t *testing.T) {
	sync := make(chan struct{})
	lis, err := net.Listen("tcp", "127.0.0.1:")
	if err != nil {
		t.Fatal(err)
	}
	go func() {
		conn, err := lis.Accept()
		if err != nil {
			t.Log(err)
			return
		}
		defer func() {
			conn.Close()
			close(sync)
		}()
		// 设置 5 秒的读写超时
		// 如果您在指定的时间内没有收到远程节点的消息，您可以假设远程节点已经消失并且您从未收到其 FIN 或者它处于空闲状态。
		if err := conn.SetDeadline(time.Now().Add(5 * time.Second)); err != nil {
			t.Error("err:", err)
			return
		}
		buf := make([]byte, 1)
		_, err = conn.Read(buf) // blocked until remote node sends data
		if err != nil {
			nErr, ok := err.(net.Error)
			if !ok || !nErr.Timeout() {
				t.Error("exported timeout")
			}
			fmt.Println("err:", err)
		}

		sync <- struct{}{}

		// 可以通过再次推迟截止日期来恢复连接对象的功能
		if err := conn.SetDeadline(time.Now().Add(5 * time.Second)); err != nil {
			t.Error(err)
			return
		}

		n, err := conn.Read(buf)
		if err != nil {
			t.Error(err)
		} else {
			fmt.Println(string(buf[:n]))
		}
	}()

	conn, err := net.Dial("tcp", lis.Addr().String())
	if err != nil {
		t.Fatal(err)
	}
	defer conn.Close()

	<-sync

	if _, err := conn.Write([]byte("1")); err != nil {
		t.Fatal(err)
	}

	buf := make([]byte, 1)
	if _, err := conn.Read(buf); err != io.EOF {
		t.Error("exported EOF,buf actual", err)
	}
}
```

**实施心跳**

