# 三协议轻量一键安装脚本

`install-vless-reality.sh` 用于在 Linux 服务器上一键安装和管理以下三种协议：

- `vless-reality`：VLESS + TCP + REALITY，基于 Xray，默认协议
- `vless-xhttp-reality`：VLESS + XHTTP + REALITY，基于 Xray
- `hy2`：Hysteria2，基于 sing-box

脚本会自动生成所需参数，并在安装完成后输出客户端链接。

## 文件

- `install-vless-reality.sh`：主脚本

## 系统要求

- Linux 服务器
- root 权限
- systemd
- 支持的包管理器之一：`apt-get`、`dnf`、`yum`、`apk`、`zypper`

脚本会按需安装常用依赖，例如 `curl`、`openssl`、`jq`、`unzip`、`tar`、`iproute2`。

## 快速使用

使用 `curl` 下载后运行：

```bash
curl -fsSLO https://raw.githubusercontent.com/BrainK-1400/scripts/main/network/vless-reality/install-vless-reality.sh
sudo bash install-vless-reality.sh
```

使用 `curl` 直接运行默认协议：

```bash
curl -fsSL https://raw.githubusercontent.com/BrainK-1400/scripts/main/network/vless-reality/install-vless-reality.sh | sudo bash
```

使用 `curl` 直接运行并指定参数：

```bash
curl -fsSL https://raw.githubusercontent.com/BrainK-1400/scripts/main/network/vless-reality/install-vless-reality.sh | sudo bash -s -- --protocol vless-xhttp-reality --port 443 --sni www.example.com
```

默认安装 `VLESS + TCP + REALITY`：

```bash
sudo bash install-vless-reality.sh
```

安装 `VLESS + TCP + REALITY`：

```bash
sudo bash install-vless-reality.sh --protocol vless-reality
```

安装 `VLESS + XHTTP + REALITY`：

```bash
sudo bash install-vless-reality.sh --protocol vless-xhttp-reality
```

安装 `Hysteria2`：

```bash
sudo bash install-vless-reality.sh --protocol hy2
```

指定端口和 SNI：

```bash
sudo bash install-vless-reality.sh --protocol vless-reality --port 443 --sni www.example.com
```

指定输出链接中的服务器地址：

```bash
sudo bash install-vless-reality.sh --protocol vless-reality --host your.server.ip
```

## 常用安装示例

### VLESS + TCP + REALITY

```bash
sudo bash install-vless-reality.sh \
  --protocol vless-reality \
  --port 443 \
  --sni www.microsoft.com \
  --host your.server.ip \
  --remark my-vless-reality
```

### VLESS + XHTTP + REALITY

```bash
sudo bash install-vless-reality.sh \
  --protocol vless-xhttp-reality \
  --port 443 \
  --sni www.microsoft.com \
  --path /xhttp-demo \
  --host your.server.ip \
  --remark my-vless-xhttp
```

### Hysteria2

```bash
sudo bash install-vless-reality.sh \
  --protocol hy2 \
  --port 443 \
  --sni www.bing.com \
  --host your.server.ip \
  --remark my-hy2
```

## 参数说明

| 参数 | 说明 |
| --- | --- |
| `--protocol` | 协议类型：`vless-reality`、`vless-xhttp-reality`、`hy2` |
| `--port` | 监听端口，默认随机选择 `10000-60000` |
| `--sni` | REALITY SNI 或 Hysteria2 证书 CN，默认随机常见域名 |
| `--dest` | REALITY `dest`，默认为 `SNI:443` |
| `--host` | 输出客户端链接中的服务器地址，默认自动检测公网 IPv4/IPv6 |
| `--uuid` | VLESS UUID，默认自动生成 |
| `--password` | Hysteria2 密码，默认自动生成 |
| `--path` | XHTTP 路径，默认随机生成，仅 `vless-xhttp-reality` 使用 |
| `--remark` | 客户端链接备注 |
| `--short-id` / `--sid` | REALITY shortId，默认自动生成 |
| `--private-key` | REALITY 私钥，默认自动生成 |
| `--public-key` | REALITY 公钥，通常无需手动传入 |
| `--fingerprint` / `--fp` | REALITY fingerprint，默认 `chrome` |
| `--no-firewall` | 不自动放行 `ufw` / `firewalld` 端口 |
| `--skip-install` | 不下载核心，只重写配置并重启服务 |
| `--yes` / `-y` | 卸载时跳过确认 |

## 管理命令

查看上次安装保存的客户端链接：

```bash
bash install-vless-reality.sh --show-link
```

查看服务状态：

```bash
bash install-vless-reality.sh --status
```

查看服务日志：

```bash
bash install-vless-reality.sh --logs
```

重启服务：

```bash
sudo bash install-vless-reality.sh --restart
```

更新当前协议所需核心并重启：

```bash
sudo bash install-vless-reality.sh --update-core
```

卸载本脚本创建的服务和配置：

```bash
sudo bash install-vless-reality.sh --uninstall
```

跳过确认卸载：

```bash
sudo bash install-vless-reality.sh --uninstall --yes
```

## 安装后文件位置

| 路径 | 说明 |
| --- | --- |
| `/usr/local/etc/vless-lite/state.env` | 上次安装状态，用于重新输出链接和管理服务 |
| `/usr/local/etc/vless-lite/xray.json` | Xray 配置 |
| `/usr/local/etc/vless-lite/sing-box.json` | sing-box 配置 |
| `/usr/local/etc/vless-lite/certs/` | Hysteria2 自签证书目录 |
| `/etc/systemd/system/vless-lite-xray.service` | Xray systemd 服务 |
| `/etc/systemd/system/vless-lite-singbox.service` | sing-box systemd 服务 |
| `/usr/local/bin/xray` | Xray 核心 |
| `/usr/local/bin/sing-box` | sing-box 核心 |

## 服务命令

Xray 服务：

```bash
systemctl status vless-lite-xray --no-pager -l
journalctl -u vless-lite-xray -e --no-pager
systemctl restart vless-lite-xray
```

sing-box 服务：

```bash
systemctl status vless-lite-singbox --no-pager -l
journalctl -u vless-lite-singbox -e --no-pager
systemctl restart vless-lite-singbox
```

## 注意事项

- `vless-reality` 和 `vless-xhttp-reality` 使用 TCP 端口。
- `hy2` 使用 UDP 端口。
- 如果服务器启用了安全组、防火墙或云厂商防火墙，需要手动放行对应端口。
- REALITY 的 `SNI` 建议使用可正常访问的真实 HTTPS 域名。
- Hysteria2 默认使用自签证书，客户端链接中带有 `insecure=1`。
- `--uninstall` 会删除 `/usr/local/etc/vless-lite` 和本脚本创建的 systemd 服务，但不会删除 `/usr/local/bin/xray` 和 `/usr/local/bin/sing-box`。
