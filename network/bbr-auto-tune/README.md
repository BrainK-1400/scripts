# BBR/TCP 自动优化脚本

`bbr-auto-tune.sh` 是面向 Linux 代理服务器的 TCP/BBR 自动优化辅助脚本。

默认运行时只会检测系统、探测网络、计算推荐参数并输出报告，不会修改系统配置。只有显式使用 `--apply` 时才会写入 sysctl 配置。

## 文件

- `bbr-auto-tune.sh`：主脚本

## 主要功能

- 检测 Linux 内核、CPU、内存、虚拟化环境。
- 检测默认网卡、MTU、qdisc、网卡速率。
- 检测当前 TCP 拥塞控制算法和 BBR 可用性。
- 支持公网 IP、ASN、地理位置检测。
- 支持 ping、MTR、tracepath 链路探测。
- 支持中国大陆三网、电信、联通、移动、公共 DNS 和自定义目标。
- 按带宽、RTT、丢包、并发数、内存和优化目标计算推荐 sysctl 参数。
- 支持报告输出、JSON 输出、只打印配置、应用配置和回滚。

## 基本用法

使用 `curl` 下载后运行：

```bash
curl -fsSLO https://raw.githubusercontent.com/BrainK-1400/scripts/main/network/bbr-auto-tune/bbr-auto-tune.sh
bash bbr-auto-tune.sh
```

使用 `curl` 直接运行：

```bash
curl -fsSL https://raw.githubusercontent.com/BrainK-1400/scripts/main/network/bbr-auto-tune/bbr-auto-tune.sh | bash
```

```bash
bash bbr-auto-tune.sh
```

直接运行会进入中文交互向导。

只生成报告，不修改系统：

```bash
bash bbr-auto-tune.sh --non-interactive --bandwidth 1000 --region china --profile throughput
```

只打印推荐 sysctl 配置：

```bash
bash bbr-auto-tune.sh --show-config --bandwidth 1000 --region china
```

应用优化配置：

```bash
sudo bash bbr-auto-tune.sh --bandwidth 1000 --region china --profile throughput --apply
```

回滚最近一次备份：

```bash
sudo bash bbr-auto-tune.sh --rollback
```

## 常用参数

| 参数 | 说明 |
| --- | --- |
| `--interactive` / `-i` | 打开中文交互向导 |
| `--non-interactive` | 不进入交互模式，使用参数和默认值运行 |
| `--apply` | 写入配置并执行 `sysctl --system` |
| `--rollback` | 回滚最近一次应用前的备份 |
| `--show-config` | 只打印推荐配置 |
| `--json` | 输出 JSON 报告 |
| `--no-network` | 跳过公网 IP、ping、MTR、tracepath 检测 |
| `--region` | 客户端地区，例如 `china`、`asia`、`global`、`us`、`eu` |
| `--china-carrier` | 中国线路：`all`、`ct`、`cu`、`cm`、`public` |
| `--targets` | 自定义探测目标，例如 `home=1.2.3.4,ali=223.5.5.5` |
| `--bandwidth` | 服务器套餐带宽，单位 Mbps |
| `--profile` | 优化目标：`balanced`、`throughput`、`latency`、`concurrency` |
| `--protocol` | 协议类型：`tcp`、`quic`、`mixed` |

## 应用后的验证

```bash
sysctl net.ipv4.tcp_congestion_control net.core.default_qdisc
ss -tin | grep -i bbr
```

## 注意事项

- 脚本主要面向 Linux 服务器。
- 默认安全模式不会修改系统。
- `--apply` 需要 root 权限。
- 若虚拟网卡无法识别真实速率，建议手动传入 `--bandwidth`。
- QUIC/UDP 类协议不直接受 TCP BBR 控制，但部分系统 buffer 参数仍可能有参考价值。
