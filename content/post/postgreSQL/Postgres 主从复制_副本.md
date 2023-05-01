# 基于 docker-compose 模拟 PostgreSQL 12.2 主从

主服务器和后备服务器一起工作来提供高可用集群能力。主服务器在连续归档模式下操作，每一个后备服务器在连续恢复模式下操作并且持续从主服务器读取 WAL 文件。要启用这种能力不需要对数据库表做任何改动，因此它相对于其他复制方案降低了管理开销。这种配置对主服务器的性能影响也相对较低。

PostgreSQL通过一次一文件（WAL 段）的 WAL 记录传输实现了基于文件的日志传送。日志传送是异步的，即 WAL 记录是在事务提交后才被传送。正因为如此，在一个窗口期内如果主服务器发生灾难性的失效则会导致数据丢失，还没有被传送的事务将会被丢失。基于文件的日志传送中这个数据丢失窗口的尺寸可以通过使用参数`archive_timeout`进行限制，它可以被设置成低至数秒。但是这样低的设置大体上会增加文件传送所需的带宽。

[参考 **高可用、负载均衡和复制**](http://postgres.cn/docs/12/warm-standby.html)

## docker-compose 配置文件

```yaml
services:
  pg_master:
    restart: always
    image: postgres:12.2
    environment:
      - POSTGRES_PASSWORD=123456789
      - TZ=Asia/Shanghai
    volumes:
      - $PWD/master:/var/lib/postgresql/data:rw
    ports:
    - "1556:5432"
    extra_hosts:
      - "postgres_master:172.22.0.2"
      - "postgres_standby:172.22.0.3"
    networks:
      localnet:
        ipv4_address: 172.22.0.2
  pg_standby:
    restart: always
    image: postgres:12.2
    environment:
      - POSTGRES_PASSWORD=123456789
      - TZ=Asia/Shanghai
    volumes:
      - $PWD/standby:/var/lib/postgresql/data:rw
    ports:
    - "1557:5432"
    extra_hosts:
      - "postgres_master:172.22.0.2"
      - "postgres_standby:172.22.0.3"
    networks:
      localnet:
        ipv4_address: 172.22.0.3


networks:
  localnet:
    driver: bridge
    ipam:
      config:
        - subnet: "172.22.0.0/16"
          gateway: "172.22.0.1"
```



## 具体操作

如果是在多台服务器上部署，建议所有设备上修改 `/etc/hosts` 文件，增加相关配置

```bash
postgres_master 172.22.0.2
postgres_standby 172.22.0.3
```

### 主库

1. 创建含有相关权限的用户，专用于流复制。

```sql
CREATE ROLE replica login replication encrypted password 'xxxxxxxxxxx';

\du   # 查看用户列表
```

2. 修改 `data/pg_hba.conf` 文件，该文件用于配置是否允许其它主机访问。

   [参考文档](http://postgres.cn/docs/12/auth-pg-hba-conf.html)

   格式:  `host replication 同步用的用户名 备库IP地址或域名/24 trust`

   从库可以加上主库的，便于以后主从切换

```bash
host replication replica postgres_two trust

# 如果某个网段都可以允许
host replication replica 192.168.0.0/24 trust
```

3. 配置主库的配置文件 `data/postgres,conf`，为了方便以后做主从切换，建议所有从库配置相同参数

   修改完成后重启

```bash
# 监听所有地址的客户端连接
listen_addresses = '*' 
# 来自客户端并发连接的最大数量，后备服务器必须 >= 该值
max_connections = 500

# 设置 WAL 归档
archive_mode = on
archive_command = 'cp %p /var/lib/postgresql/data/pg_archive/%f'
restore_command = 'cp /var/lib/postgresql/data/pg_archive/%f %p'
recovery_target_timeline = latest
# 日志格式
wal_level = replica
# 设置流复制保留的最多段数目
wal_keep_segments = 64
# 中断那些停止活动超过这个时间量的复制连接
wal_sender_timeout = 30s
# 来自后备服务器并发连接的最大数量，官方文档建议 > max_connections
max_wal_senders=50
# 开启日志
logging_collector = on
log_directory = '/var/lib/postgresql/data/log'
log_filename = 'pg-%Y-%m-%d_%H%M%S.log'
log_file_mode = 0600
log_rotation_age = 72h

# 恢复期间，允许连接并查询
hot_standby = on
# 流复制最大延迟，默认 30s
max_standby_streaming_delay = 30s
# 向主报告状态，默认 10s
wal_receiver_status_interval = 10s
```

4. 备库设置

```bash
# 备份之前的数据
cp data ../data_back
# 删除数据
rm -rf data/*

# 进入容器，切换 postgres 用户，拉取主库的数据
docker exec -it 5123123 sh
su postgres
pg_basebackup -h postgres_one -U replica -Fp -P -R -D  /var/lib/postgresql/data
```

| 参数 | 说明                                                         |
| ---- | ------------------------------------------------------------ |
| `-h` | host                                                         |
| `-U` | 用户名                                                       |
| `-F` | p 是默认输出格式，t 表示 tar 格式                            |
| `-P` | 显示进度                                                     |
| `-D` | 输出到指定目录                                               |
| `-R` | 建立 `standby.signal` 并附加连接设置到`postgresql.auto.conf` 来简化设置一个后备服务器 |
|      |                                                              |

5. 检查是否成功

   进入主库查询，如显示备库表示成功

```bash
psql
select client_addr,sync_state from pg_stat_replication;
```







