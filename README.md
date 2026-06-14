# 个人脚本合集

这里存放个人常用的 Linux 运维脚本，按用途分类管理。

## 目录结构

```text
.
├── network/
│   └── bbr-auto-tune/
│       ├── bbr-auto-tune.sh
│       └── README.md
└── system/
    └── auto-shutdown/
        ├── install-auto-shutdown.sh
        └── README.md
```

## 脚本列表

| 分类 | 脚本 | 说明 |
| --- | --- | --- |
| 网络优化 | [network/bbr-auto-tune/bbr-auto-tune.sh](network/bbr-auto-tune/bbr-auto-tune.sh) | Linux TCP/BBR 自动检测、计算和推荐 sysctl 参数 |
| 系统管理 | [system/auto-shutdown/install-auto-shutdown.sh](system/auto-shutdown/install-auto-shutdown.sh) | 安装基于 systemd timer 的开机后自动关机工具 |

## 使用建议

1. 先阅读对应目录下的 `README.md`。
2. 涉及系统修改的脚本，优先在测试环境运行。
3. 需要写入系统配置的操作请使用 `sudo` 或 root 权限。
4. 从外部复制到服务器后，建议先检查脚本内容再执行。

## 快速入口

- [BBR/TCP 自动优化脚本说明](network/bbr-auto-tune/README.md)
- [自动关机脚本说明](system/auto-shutdown/README.md)
