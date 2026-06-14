# 自动关机安装脚本

`install-auto-shutdown.sh` 用于在 Linux 系统中安装一个基于 systemd timer 的自动关机工具。

安装后会生成 `asd` 命令，可通过菜单查看状态、暂停、恢复、修改时间、关闭、开启或卸载自动关机功能。

## 文件

- `install-auto-shutdown.sh`：安装脚本

## 适用场景

- 个人服务器临时使用后希望自动关机。
- 云服务器按时长计费，需要避免忘记关机。
- 测试机、下载机、临时环境需要开机后自动倒计时关机。

## 安装

默认开机后 1 小时自动关机：

```bash
sudo bash install-auto-shutdown.sh
```

指定默认倒计时时间：

```bash
sudo DELAY=2h bash install-auto-shutdown.sh
```

支持的时间示例：

```text
30min
1h
2h
90min
```

## 安装后使用

打开菜单：

```bash
asd
```

查看状态：

```bash
asd status
```

暂停本次自动关机：

```bash
sudo asd pause
```

恢复本次倒计时：

```bash
sudo asd resume
```

修改自动关机时间：

```bash
sudo asd time 2h
```

永久关闭自动关机：

```bash
sudo asd off
```

重新开启自动关机：

```bash
sudo asd on
```

卸载：

```bash
sudo asd uninstall
```

## 安装后创建的文件

| 路径 | 说明 |
| --- | --- |
| `/usr/local/bin/asd` | 管理命令 |
| `/etc/auto-shutdown.conf` | 自动关机时间配置 |
| `/etc/systemd/system/auto-shutdown.service` | systemd service |
| `/etc/systemd/system/auto-shutdown.timer` | systemd timer |

## 注意事项

- 安装脚本需要 root 权限。
- 依赖 systemd，适合常见 Debian、Ubuntu、CentOS、Rocky、AlmaLinux 等系统。
- `asd pause` 只暂停本次倒计时，下次开机仍会自动开始。
- `asd off` 会永久关闭自动关机，直到执行 `asd on`。
