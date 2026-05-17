---
title: 小米 BE7000 路由器部署 AdGuard Home 全攻略
date: 2026-05-17
slug: 
image: 
draft: false
categories:
    - docker
tags:
    - docker
    - 路由器
---



> 适用机型：小米 BE7000（已开启 SSH + Docker）
> 最后验证：2026-05-17

---

## 一、这套方案能干什么

在路由器上跑一个 DNS 广告过滤服务，家里所有设备（手机、电脑、电视、IoT）自动拦截广告，**不需要在每台设备上装任何软件**。

原理：路由器充当 DNS 服务器 → 所有 DNS 请求经过 AdGuard Home → 广告域名返回空地址（0.0.0.0）→ 广告加载失败。

---

## 二、前置条件

| 条件 | 说明 |
|------|------|
| 路由器已 SSH | 小米 BE7000 需要先开启 SSH（网上有教程，搜"小米路由器 SSH"） |
| 路由器已装 Docker | 小米 BE7000 插入 U 盘后自带 Docker 环境 |
| U 盘已挂载 | Docker 和 AdGuard 数据都存在 U 盘上 |
| 电脑能 SSH 连接路由器 | 终端执行 `ssh root@192.168.31.1` 能连上 |

---

## 三、部署步骤

### 第 1 步：SSH 连接路由器

```bash
ssh root@192.168.31.1
```

输入密码后进入路由器终端。

---

### 第 2 步：确认 Docker 可用

```bash
# 查看 Docker 二进制路径（小米路由器的 Docker 在 U 盘上）
ls /mnt/usb-*/mi_docker/docker-binaries/docker

# 测试 Docker 是否正常
/mnt/usb-*/mi_docker/docker-binaries/docker ps
```

如果能看到容器列表，说明 Docker 正常。

---

### 第 3 步：创建 AdGuard 数据目录

```bash
# 创建配置和数据目录（存在 U 盘上，重启不丢失）
mkdir -p /mnt/usb-*/adguard/conf
mkdir -p /mnt/usb-*/adguard/work
```

---

### 第 4 步：启动 AdGuard Home 容器

```bash
/mnt/usb-*/mi_docker/docker-binaries/docker run -d \
  --name adguardhome \
  --network=host \
  --restart=always \
  -v /mnt/usb-*/adguard/conf:/opt/adguardhome/conf \
  -v /mnt/usb-*/adguard/work:/opt/adguardhome/work \
  registry.cn-shanghai.aliyuncs.com/rustc/adguard:latest
```

**参数说明：**
- `--network=host`：使用宿主机网络，容器直接监听路由器的端口（不需要端口映射）
- `--restart=always`：路由器重启后容器自动启动
- `-v`：把配置和数据挂载到 U 盘，重启不丢失
- 镜像用的是阿里云国内源，下载快
- `usb-*` 要换成自己实际的目录

---

### 第 5 步：首次配置 AdGuard Home

浏览器打开 `http://192.168.31.1:3000`，进入初始化向导：

1. **选择语言**：中文
2. **设置管理员账号密码**：自己设一个，**记住它！**
3. **DNS 监听端口**：保持默认 `53`
4. **Web 监听端口**：保持默认有点问题，改成 `3001` 后正常
5. **上游 DNS**：先随便填，后面会改

---

### 第 6 步：解决端口冲突（关键！）

小米路由器自带 `dnsmasq` 服务，它默认也占用 53 端口，会和 AdGuard 打架。必须把 dnsmasq 的 DNS 端口挪走。

```bash
# 把 dnsmasq 的 DNS 端口改成 54（保留 DHCP 功能）
uci set dhcp.@dnsmasq[0].port='54'
uci commit dhcp
/etc/init.d/dnsmasq restart
```

**验证：**
```bash
netstat -tlnup | grep ':53 '
```

应该只看到 `AdGuardHome` 监听 53 端口，不再有 `dnsmasq`。

---

### 第 7 步：配置上游 DNS

路由器访问国外 DNS（如 Quad9、Google DNS）经常超时，需要换成国内 DNS。

编辑容器内的配置文件(也可以在网页上填写)：

```bash
vi /mnt/usb-*/adguard/conf/AdGuardHome.yaml
```

找到 `upstream_dns:` 部分，改成：

```yaml
upstream_dns:
  - 114.114.114.114
  - 223.5.5.5
```

找到 `bootstrap_dns:` 部分，同样改成：

```yaml
bootstrap_dns:
  - 114.114.114.114
  - 223.5.5.5
```

**保存后重启容器：**
```bash
/mnt/usb-*/mi_docker/docker-binaries/docker restart adguardhome
```

**在本地终端验证 DNS 是否生效：**

```bash
nslookup baidu.com 192.168.31.1
```

能解析出 IP 地址就说明成功。

---

### 第 8 步：配置 DHCP 让所有设备自动使用 AdGuard

```bash
# 设置 DHCP 下发的 DNS 服务器地址为路由器自身
uci set dhcp.lan.dns1='192.168.31.1'
uci commit dhcp
/etc/init.d/dnsmasq restart
```

这样所有通过 DHCP 获取 IP 的设备，DNS 会自动指向 `192.168.31.1`（即 AdGuard Home）。

**注意**：已经连接的设备需要重新连接 Wi-Fi 或等 DHCP 租约刷新（通常几小时内自动生效）。

---

## 四、配置广告过滤规则

### 当前推荐的规则组合

| 规则名称 | 规则数量 | 覆盖范围 | 下载地址 |
|---------|---------|---------|---------|
| AdGuard DNS filter | 165,000+ | 全球通用广告和跟踪器 | [filter_1.txt](https://adguardteam.github.io/HostlistsRegistry/assets/filter_1.txt) |
| AdAway Default Blocklist | 10,000+ | 通用广告 | [filter_2.txt](https://adguardteam.github.io/HostlistsRegistry/assets/filter_2.txt) |
| ADgk 中文广告过滤 | 9,000+ | 国内 App 广告（知乎、B站等） | [ADgk.txt](https://raw.githubusercontent.com/banbendalao/ADgk/master/ADgk.txt) |
| EasyList China | 19,000+ | 国内网页广告 | [easylistchina.txt](https://easylist-downloads.adblockplus.org/easylistchina.txt) |
| anti-AD | 114,000+ | 国内最全面的广告域名屏蔽 | [anti-ad-domains.txt](https://raw.githubusercontent.com/privacy-protection-tools/anti-AD/master/anti-ad-domains.txt) |

**总计约 318,000 条规则**，覆盖穿山甲广告、腾讯广告、百度广告、快手广告、知乎、B站等主流平台。

---

### 手动添加规则（通过 Web 界面）

1. 打开 `http://192.168.31.1:3001/#filters`
2. 点击「添加阻止列表」
3. 填写名称和 URL，点保存

**但是！** 路由器直接访问 GitHub 等国外地址会被墙，下载会失败。需要用下面的「离线导入」方法。

---

### 离线导入规则（推荐）

在你的电脑上（能访问 GitHub 的设备）下载规则文件，然后传到路由器上。

**第 1 步：在电脑上下载规则文件**

```bash
# 在你的 Mac/Linux 电脑终端执行
curl -o filter_1.txt 'https://adguardteam.github.io/HostlistsRegistry/assets/filter_1.txt'
curl -o filter_2.txt 'https://adguardteam.github.io/HostlistsRegistry/assets/filter_2.txt'
curl -o filter_3.txt 'https://raw.githubusercontent.com/banbendalao/ADgk/master/ADgk.txt'
curl -o filter_4.txt 'https://easylist-downloads.adblockplus.org/easylistchina.txt'
curl -o filter_5.txt 'https://raw.githubusercontent.com/privacy-protection-tools/anti-AD/master/anti-ad-domains.txt'
```

**第 2 步：传到路由器**

小米路由器的 SSH 不支持 scp/sftp，用 base64 编码传输：

```bash
# 在电脑上执行（逐个传输）
base64 -i filter_1.txt | ssh root@192.168.31.1 "base64 -d > /mnt/usb-*/adguard/work/data/filters/1.txt"
base64 -i filter_2.txt | ssh root@192.168.31.1 "base64 -d > /mnt/usb-*/adguard/work/data/filters/2.txt"
base64 -i filter_3.txt | ssh root@192.168.31.1 "base64 -d > /mnt/usb-*/adguard/work/data/filters/3.txt"
base64 -i filter_4.txt | ssh root@192.168.31.1 "base64 -d > /mnt/usb-*/adguard/work/data/filters/4.txt"
base64 -i filter_5.txt | ssh root@192.168.31.1 "base64 -d > /mnt/usb-*/adguard/work/data/filters/5.txt"
```

**注意**：Mac 上 base64 用 `-i` 参数，Linux 上用 `base64 < file` 管道方式。

**第 3 步：修改配置文件启用规则**

SSH 进路由器，编辑配置：

```bash
vi /mnt/usb-*/adguard/conf/AdGuardHome.yaml
```

找到 `filters:` 部分，替换成：



```yaml
filters:
  - enabled: true
    url: file:///opt/adguardhome/work/data/filters/1.txt
    name: AdGuard DNS filter
    id: 1
  - enabled: true
    url: file:///opt/adguardhome/work/data/filters/2.txt
    name: AdAway Default Blocklist
    id: 2
  - enabled: true
    url: file:///opt/adguardhome/work/data/filters/3.txt
    name: ADgk 中文广告过滤
    id: 3
  - enabled: true
    url: file:///opt/adguardhome/work/data/filters/4.txt
    name: EasyList China
    id: 4
  - enabled: true
    url: file:///opt/adguardhome/work/data/filters/5.txt
    name: anti-AD
    id: 5
```

**第 4 步：重启生效**

```bash
/mnt/usb-*/mi_docker/docker-binaries/docker restart adguardhome
```

---

## 五、定期更新过滤规则

由于路由器访问 GitHub 被墙，规则无法自动更新。需要定期手动更新。

### 更新频率建议

- **每月更新一次**即可，广告规则变化不会特别快
- 如果发现某个 App 广告突然拦不住了，手动更新一次

### 更新方法

和上面「离线导入」步骤一样：在电脑上重新下载最新规则 → base64 传到路由器 → 重启容器。

可以写一个脚本简化操作（在电脑上运行）：

```bash
#!/bin/bash
# update_adguard_filters.sh
# 用法：在电脑上执行此脚本自动更新路由器的广告过滤规则

ROUTER="root@192.168.31.1"
FILTER_DIR="/mnt/usb-35f6643a/adguard/work/data/filters"

echo "正在下载最新规则..."
curl -sL -o /tmp/f1.txt 'https://adguardteam.github.io/HostlistsRegistry/assets/filter_1.txt'
curl -sL -o /tmp/f2.txt 'https://adguardteam.github.io/HostlistsRegistry/assets/filter_2.txt'
curl -sL -o /tmp/f3.txt 'https://raw.githubusercontent.com/banbendalao/ADgk/master/ADgk.txt'
curl -sL -o /tmp/f4.txt 'https://easylist-downloads.adblockplus.org/easylistchina.txt'
curl -sL -o /tmp/f5.txt 'https://raw.githubusercontent.com/privacy-protection-tools/anti-AD/master/anti-ad-domains.txt'

echo "正在传输到路由器..."
for i in 1 2 3 4 5; do
  base64 -i /tmp/f${i}.txt | ssh $ROUTER "base64 -d > ${FILTER_DIR}/${i}.txt"
  echo "  filter_${i}.txt 传输完成"
done

echo "正在重启 AdGuard Home..."
ssh $ROUTER "/mnt/usb-35f6643a/mi_docker/docker-binaries/docker restart adguardhome"

echo "完成！过滤规则已更新。"
```

---

## 六、验证是否生效

### 方法 1：命令行测试

```bash
# 测试广告域名是否被拦截（应返回 0.0.0.0）
nslookup ads.google.com 192.168.31.1
nslookup pos.baidu.com 192.168.31.1
nslookup pagead2.googlesyndication.com 192.168.31.1

# 测试正常域名是否能解析
nslookup baidu.com 192.168.31.1
nslookup qq.com 192.168.31.1
```

广告域名返回 `0.0.0.0` = 拦截成功
正常域名返回真实 IP = 解析正常

### 方法 2：查看 Web 界面

打开 `http://192.168.31.1:3001`，登录后：
- **仪表盘**：能看到查询统计和拦截率
- **查询日志**：能看到每个 DNS 请求的详细记录
- **过滤器**：能看到已启用的规则列表

---

## 七、常见问题排查

### Q1：设备还是能看到广告

1. 确认设备的 DNS 是 `192.168.31.1`（在设备的 Wi-Fi 设置里查看）
2. 部分 App 有广告缓存，清除 App 缓存或等缓存过期
3. 有些广告走的是 IP 直连而非域名，DNS 过滤无法拦截（这种情况很少）

### Q2：某些网站打不开了

可能是被误拦截了。在 AdGuard Web 界面的「查询日志」里找到被拦截的域名，加到「白名单」里。

### Q3：AdGuard Web 界面打不开

```bash
# 检查容器是否在运行
/mnt/usb-*/mi_docker/docker-binaries/docker ps

# 如果没有运行，启动它
/mnt/usb-*/mi_docker/docker-binaries/docker start adguardhome

# 查看日志排查错误
/mnt/usb-*/mi_docker/docker-binaries/docker logs --tail 50 adguardhome
```

### Q4：DNS 解析失败（所有网站都打不开）

```bash
# 检查 AdGuard 是否在监听 53 端口
netstat -tlnup | grep ':53 '

# 如果没有，检查容器日志
/mnt/usb-*/mi_docker/docker-binaries/docker logs adguardhome | grep error

# 常见原因：上游 DNS 不通
# 解决：确保 upstream_dns 配置的是国内 DNS（114.114.114.114、223.5.5.5）
```

### Q5：路由器重启后 AdGuard 没有自动启动

```bash
# 检查容器是否有 --restart=always
/mnt/usb-*/mi_docker/docker-binaries/docker inspect adguardhome | grep RestartPolicy

# 如果没有，重新创建容器（参考第 4 步）
```

---

## 八、技术细节备忘

### 端口分配

| 端口 | 服务 | 说明 |
|------|------|------|
| 53 | AdGuard Home | DNS 服务（TCP + UDP） |
| 54 | dnsmasq | 仅 DHCP，不提供 DNS |
| 3001 | AdGuard Home | Web 管理界面 |

### 文件路径

| 路径 | 用途 |
|------|------|
| `/mnt/usb-*/adguard/conf/AdGuardHome.yaml` | AdGuard 主配置文件 |
| `/mnt/usb-*/adguard/work/data/filters/` | 过滤规则文件存放目录 |
| `/mnt/usb-*/adguard/work/data/querylog.json` | DNS 查询日志 |
| `/mnt/usb-*/adguard/work/data/stats.db` | 统计数据 |

### 配置文件关键字段

```yaml
dns:
  upstream_dns:          # 上游 DNS 服务器
  bootstrap_dns:         # 引导 DNS（用于解析上游 DNS 的域名）
  port: 53               # DNS 监听端口
http:
  address: 192.168.31.1:3001  # Web 界面地址
filters:                 # 过滤规则列表
querylog:
  enabled: true          # 是否记录查询日志
  interval: 720h         # 日志保留时长
```
