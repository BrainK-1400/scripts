#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "请使用 root 权限运行：sudo bash install-auto-shutdown.sh"
  exit 1
fi

DELAY="${DELAY:-1h}"
CONF="/etc/auto-shutdown.conf"
ASD="/usr/local/bin/asd"

case "$DELAY" in
  ""|*[!0-9A-Za-z._-]*)
    echo "时间格式错误，请使用 30min、1h、2h、90min 这种格式"
    exit 1
    ;;
esac

mkdir -p /usr/local/bin

cat > "$CONF" <<EOF
DELAY='$DELAY'
EOF

cat > "$ASD" <<'EOF'
#!/bin/sh
set -eu

SERVICE_NAME="auto-shutdown.service"
TIMER_NAME="auto-shutdown.timer"
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME"
TIMER_FILE="/etc/systemd/system/$TIMER_NAME"
CONF="/etc/auto-shutdown.conf"
SELF="/usr/local/bin/asd"

get_delay() {
  DELAY="1h"
  if [ -f "$CONF" ]; then
    . "$CONF"
  fi
  printf '%s' "${DELAY:-1h}"
}

need_root() {
  if [ "$(id -u)" -ne 0 ]; then
    if command -v sudo >/dev/null 2>&1; then
      exec sudo "$SELF" "$@"
    else
      echo "需要 root 权限，请使用 root 用户执行。" >&2
      exit 1
    fi
  fi
}

validate_time() {
  t="$1"

  case "$t" in
    ""|*[!0-9A-Za-z._-]*)
      echo "时间格式错误，请使用 30min、1h、2h、90min 这种格式"
      return 1
      ;;
  esac

  if command -v systemd-analyze >/dev/null 2>&1; then
    if ! systemd-analyze timespan "$t" >/dev/null 2>&1; then
      echo "systemd 不识别该时间格式：$t"
      echo "示例：30min、1h、2h、90min"
      return 1
    fi
  fi
}

write_units() {
  delay="$1"
  shutdown_bin="$(command -v shutdown 2>/dev/null || printf '%s\n' /usr/sbin/shutdown)"

  cat > "$SERVICE_FILE" <<EOF2
[Unit]
Description=Auto shutdown after boot delay

[Service]
Type=oneshot
ExecStart=$shutdown_bin -h now "自动关机：开机后 $delay 已到。"
EOF2

  cat > "$TIMER_FILE" <<EOF2
[Unit]
Description=Auto shutdown $delay after boot

[Timer]
OnActiveSec=$delay
AccuracySec=1s
Unit=$SERVICE_NAME

[Install]
WantedBy=timers.target
EOF2
}

apply_cmd() {
  need_root apply

  delay="$(get_delay)"
  validate_time "$delay"

  write_units "$delay"
  systemctl daemon-reload
  systemctl enable --now "$TIMER_NAME" >/dev/null

  echo "已启用：开机后 $delay 自动关机。"
  systemctl list-timers --all "$TIMER_NAME" || true
}

status_cmd() {
  delay="$(get_delay)"
  enabled="$(systemctl is-enabled "$TIMER_NAME" 2>/dev/null || true)"
  active="$(systemctl is-active "$TIMER_NAME" 2>/dev/null || true)"

  echo "当前设置：开机后 $delay 自动关机"
  echo "开机自启：${enabled:-unknown}"
  echo "本次倒计时：${active:-unknown}"
  echo
  systemctl list-timers --all "$TIMER_NAME" 2>/dev/null || true
}

pause_cmd() {
  need_root pause

  systemctl stop "$TIMER_NAME"
  echo "已暂停本次自动关机。"
  echo "下次开机后仍会自动重新开始倒计时。"
}

resume_cmd() {
  need_root resume

  systemctl restart "$TIMER_NAME"
  echo "已恢复本次自动关机倒计时。"
  systemctl list-timers --all "$TIMER_NAME" || true
}

time_cmd() {
  if [ "$#" -lt 1 ]; then
    echo "用法：asd time 30min"
    echo "示例：asd time 1h"
    exit 1
  fi

  new_time="$1"
  validate_time "$new_time"

  need_root time "$new_time"

  printf "DELAY='%s'\n" "$new_time" > "$CONF"

  write_units "$new_time"
  systemctl daemon-reload
  systemctl enable "$TIMER_NAME" >/dev/null
  systemctl restart "$TIMER_NAME"

  echo "已修改为：开机后 $new_time 自动关机。"
  echo "本次倒计时已重新开始。"
  systemctl list-timers --all "$TIMER_NAME" || true
}

off_cmd() {
  need_root off

  systemctl disable --now "$TIMER_NAME"
  echo "已永久关闭自动关机。"
  echo "如需重新开启，请执行：asd on"
}

on_cmd() {
  need_root on

  systemctl enable --now "$TIMER_NAME"
  echo "已开启自动关机。"
  systemctl list-timers --all "$TIMER_NAME" || true
}

uninstall_cmd() {
  need_root uninstall

  systemctl disable --now "$TIMER_NAME" >/dev/null 2>&1 || true
  rm -f "$SERVICE_FILE" "$TIMER_FILE" "$CONF"
  systemctl daemon-reload
  rm -f "$SELF"

  echo "已卸载自动关机功能。"
}

pause_enter() {
  printf "\n按回车返回菜单..."
  read -r _ || true
}

menu_cmd() {
  while :; do
    delay="$(get_delay)"
    enabled="$(systemctl is-enabled "$TIMER_NAME" 2>/dev/null || true)"
    active="$(systemctl is-active "$TIMER_NAME" 2>/dev/null || true)"

    echo
    echo "========== 自动关机菜单 =========="
    echo "当前设置：开机后 $delay 自动关机"
    echo "开机自启：${enabled:-unknown}"
    echo "本次倒计时：${active:-unknown}"
    echo
    echo "1) 查看状态/倒计时"
    echo "2) 暂停本次自动关机"
    echo "3) 恢复本次倒计时"
    echo "4) 修改自动关机时间"
    echo "5) 永久关闭自动关机"
    echo "6) 开启自动关机"
    echo "7) 卸载"
    echo "0) 退出"
    echo "=================================="
    printf "请选择 [0-7]: "

    read -r choice || exit 0

    case "$choice" in
      1)
        "$SELF" status || true
        pause_enter
        ;;
      2)
        "$SELF" pause || true
        pause_enter
        ;;
      3)
        "$SELF" resume || true
        pause_enter
        ;;
      4)
        echo
        echo "请输入新时间，例如：30min、1h、2h、90min"
        printf "新时间: "
        read -r t || true
        if [ -n "${t:-}" ]; then
          "$SELF" time "$t" || true
        fi
        pause_enter
        ;;
      5)
        "$SELF" off || true
        pause_enter
        ;;
      6)
        "$SELF" on || true
        pause_enter
        ;;
      7)
        printf "确认卸载自动关机功能？[y/N]: "
        read -r yn || true
        case "${yn:-}" in
          y|Y|yes|YES)
            "$SELF" uninstall || true
            exit 0
            ;;
          *)
            echo "已取消卸载。"
            pause_enter
            ;;
        esac
        ;;
      0)
        exit 0
        ;;
      *)
        echo "无效选择。"
        pause_enter
        ;;
    esac
  done
}

help_cmd() {
  cat <<EOF2
用法：

  asd              打开菜单
  asd s            查看状态
  sudo asd p       暂停本次自动关机
  sudo asd r       恢复本次倒计时
  sudo asd time 2h 修改时间
  sudo asd off     永久关闭
  sudo asd on      开启
  sudo asd uninstall 卸载

时间示例：

  30min
  1h
  2h
  90min
EOF2
}

cmd="${1:-menu}"

if [ "$#" -gt 0 ]; then
  shift
fi

case "$cmd" in
  menu)
    menu_cmd
    ;;
  s|status)
    status_cmd
    ;;
  p|pause|stop)
    pause_cmd
    ;;
  r|resume|start)
    resume_cmd
    ;;
  t|time|set)
    time_cmd "$@"
    ;;
  off|disable)
    off_cmd
    ;;
  on|enable)
    on_cmd
    ;;
  u|uninstall|remove)
    uninstall_cmd
    ;;
  apply)
    apply_cmd
    ;;
  h|help|-h|--help)
    help_cmd
    ;;
  *)
    help_cmd
    exit 1
    ;;
esac
EOF

chmod +x "$ASD"

"$ASD" apply

echo
echo "安装完成。"
echo
echo "以后直接输入："
echo
echo "  asd"
echo
echo "即可打开菜单。"