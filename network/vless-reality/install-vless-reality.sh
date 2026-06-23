#!/usr/bin/env bash
# Lightweight installer for VLESS+TCP+REALITY, VLESS+XHTTP+REALITY, and Hysteria2.

set -Eeuo pipefail

VERSION="2.0.0"
CONFIG_DIR="/usr/local/etc/vless-lite"
STATE_FILE="$CONFIG_DIR/state.env"
XRAY_CONFIG="$CONFIG_DIR/xray.json"
SINGBOX_CONFIG="$CONFIG_DIR/sing-box.json"
CERT_DIR="$CONFIG_DIR/certs"
XRAY_BIN="/usr/local/bin/xray"
SINGBOX_BIN="/usr/local/bin/sing-box"
XRAY_SERVICE="vless-lite-xray"
SINGBOX_SERVICE="vless-lite-singbox"
XRAY_USER="xray"
SINGBOX_USER="singbox"
SHARE_DIR="/usr/local/share/xray"

ACTION="install"
PROTOCOL="vless-reality"
PORT=""
SNI=""
DEST=""
HOST=""
REMARK=""
UUID=""
PASSWORD=""
PRIVATE_KEY=""
PUBLIC_KEY=""
SHORT_ID=""
XHTTP_PATH=""
FINGERPRINT="chrome"
NO_FIREWALL=0
SKIP_INSTALL=0
YES=0
TMP_DIR=""
PUBLIC_IPV4=""
PUBLIC_IPV6=""

COMMON_SNI=(www.microsoft.com www.apple.com www.bing.com www.cloudflare.com www.amazon.com www.yahoo.com www.oracle.com www.ibm.com)

usage() {
  cat <<'EOF'
install-vless-reality.sh - 三协议轻量一键安装脚本

协议：
  vless-reality        VLESS + TCP + REALITY，Xray，默认
  vless-xhttp-reality  VLESS + XHTTP + REALITY，Xray
  hy2                  Hysteria2，sing-box

安装：
  sudo bash install-vless-reality.sh
  sudo bash install-vless-reality.sh --protocol vless-xhttp-reality --port 443 --sni www.example.com
  sudo bash install-vless-reality.sh --protocol hy2 --port 443 --sni www.example.com

选项：
  --protocol NAME      vless-reality | vless-xhttp-reality | hy2
  --port PORT          监听端口，默认随机 10000-60000
  --sni DOMAIN         REALITY SNI / Hysteria2 证书 CN，默认随机常见域名
  --dest HOST:PORT     REALITY dest，默认为 SNI:443
  --host HOST          输出链接地址，默认自动检测公网 IPv4/IPv6
  --uuid UUID          VLESS UUID，默认自动生成
  --password VALUE     Hysteria2 密码，默认自动生成
  --path PATH          XHTTP 路径，默认随机
  --remark NAME        链接备注，默认按协议生成
  --short-id HEX       REALITY shortId，默认自动生成
  --private-key KEY    REALITY 私钥，默认自动生成
  --public-key KEY     REALITY 公钥，通常无需传入
  --fingerprint NAME   REALITY fingerprint，默认 chrome
  --no-firewall        不自动放行 ufw/firewalld 端口
  --skip-install       不下载核心，只重写配置并重启服务
  --yes, -y            卸载时跳过确认

管理：
  --show-link          重新输出上次保存的链接
  --status             查看服务状态
  --logs               查看服务日志
  --restart            重启服务
  --update-core        更新当前协议所需核心并重启
  --uninstall          卸载服务并删除本脚本配置
  --help, -h           显示帮助
EOF
}

log(){ printf '[INFO] %s\n' "$*"; }
warn(){ printf '[WARN] %s\n' "$*" >&2; }
fail(){ printf '[ERROR] %s\n' "$*" >&2; exit 1; }
command_exists(){ command -v "$1" >/dev/null 2>&1; }
cleanup(){ [ -n "${TMP_DIR:-}" ] && [ -d "$TMP_DIR" ] && rm -rf "$TMP_DIR"; return 0; }
trap cleanup EXIT

need_root(){ [ "${EUID:-$(id -u)}" -eq 0 ] || fail "请使用 root 权限运行：sudo bash $0"; }
need_linux(){ [ "$(uname -s 2>/dev/null)" = Linux ] || fail "此脚本仅支持 Linux。"; }
need_arg(){ [ -n "${2:-}" ] || fail "$1 需要参数值。"; }
is_int(){ [[ "${1:-}" =~ ^[0-9]+$ ]]; }
is_hex(){ [[ "${1:-}" =~ ^[0-9A-Fa-f]+$ ]]; }

normalize_protocol(){
  case "$PROTOCOL" in
    vless-reality|vless|reality) PROTOCOL="vless-reality" ;;
    vless-xhttp-reality|vless-xhttp|xhttp) PROTOCOL="vless-xhttp-reality" ;;
    hy2|hysteria2) PROTOCOL="hy2" ;;
    *) fail "不支持的协议：$PROTOCOL" ;;
  esac
}

parse_args(){
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --protocol) need_arg "$1" "${2:-}"; PROTOCOL="$2"; shift 2 ;;
      --port) need_arg "$1" "${2:-}"; PORT="$2"; shift 2 ;;
      --sni|--server-name) need_arg "$1" "${2:-}"; SNI="$2"; shift 2 ;;
      --dest) need_arg "$1" "${2:-}"; DEST="$2"; shift 2 ;;
      --host) need_arg "$1" "${2:-}"; HOST="$2"; shift 2 ;;
      --uuid) need_arg "$1" "${2:-}"; UUID="$2"; shift 2 ;;
      --password) need_arg "$1" "${2:-}"; PASSWORD="$2"; shift 2 ;;
      --path) need_arg "$1" "${2:-}"; XHTTP_PATH="$2"; shift 2 ;;
      --remark) need_arg "$1" "${2:-}"; REMARK="$2"; shift 2 ;;
      --short-id|--sid) need_arg "$1" "${2:-}"; SHORT_ID="$2"; shift 2 ;;
      --private-key) need_arg "$1" "${2:-}"; PRIVATE_KEY="$2"; shift 2 ;;
      --public-key) need_arg "$1" "${2:-}"; PUBLIC_KEY="$2"; shift 2 ;;
      --fingerprint|--fp) need_arg "$1" "${2:-}"; FINGERPRINT="$2"; shift 2 ;;
      --no-firewall) NO_FIREWALL=1; shift ;;
      --skip-install) SKIP_INSTALL=1; shift ;;
      --yes|-y) YES=1; shift ;;
      --show-link) ACTION="show-link"; shift ;;
      --status) ACTION="status"; shift ;;
      --logs) ACTION="logs"; shift ;;
      --restart) ACTION="restart"; shift ;;
      --update-core) ACTION="update-core"; shift ;;
      --uninstall) ACTION="uninstall"; shift ;;
      --help|-h) usage; exit 0 ;;
      --version) printf '%s\n' "$VERSION"; exit 0 ;;
      *) fail "未知参数：$1" ;;
    esac
  done
  normalize_protocol
}

json_escape(){ printf '%s' "${1:-}" | sed 's/\\/\\\\/g; s/"/\\"/g; s/	/\\t/g'; }
shell_escape(){ printf "'%s'" "$(printf '%s' "${1:-}" | sed "s/'/'\\\\''/g")"; }
urlencode(){ local s="${1:-}" i c; for((i=0;i<${#s};i++));do c="${s:i:1}"; case "$c" in [a-zA-Z0-9.~_-]) printf '%s' "$c";; *) printf '%%%02X' "'$c";; esac; done; }
rand_hex(){ openssl rand -hex "$1"; }
rand_sni(){ local idx; idx="$(od -An -tu4 -N4 /dev/urandom 2>/dev/null | tr -d ' ' || true)"; [ -n "$idx" ] || idx="$RANDOM"; printf '%s' "${COMMON_SNI[$((idx % ${#COMMON_SNI[@]}))]}"; }
rand_path(){ printf '/xhttp-%s' "$(rand_hex 4)"; }

validate_port(){ is_int "$1" && [ "$1" -ge 1 ] && [ "$1" -le 65535 ] || fail "端口范围必须是 1-65535：$1"; }
port_in_use(){ if command_exists ss; then ss -lntu 2>/dev/null | awk '{print $5}' | grep -Eq "(^|:)${1}$"; else return 1; fi; }
pick_port(){ local p i; for i in $(seq 1 60); do p="$(shuf -i 10000-60000 -n 1 2>/dev/null || awk 'BEGIN{srand();print int(10000+rand()*50001)}')"; port_in_use "$p" || { printf '%s' "$p"; return; }; done; fail "无法自动选择可用端口，请用 --port 指定。"; }

install_deps(){
  local deps="curl openssl jq ca-certificates iproute2" extra=""
  [ "$PROTOCOL" = hy2 ] && extra="tar" || extra="unzip"
  for c in curl openssl jq $extra; do command_exists "$c" || missing=1; done
  [ "${missing:-0}" = 0 ] && return 0
  log "安装依赖"
  if command_exists apt-get; then apt-get update; DEBIAN_FRONTEND=noninteractive apt-get install -y $deps unzip tar
  elif command_exists dnf; then dnf install -y curl openssl jq ca-certificates iproute unzip tar
  elif command_exists yum; then yum install -y epel-release || true; yum install -y curl openssl jq ca-certificates iproute unzip tar
  elif command_exists apk; then apk add --no-cache curl openssl jq ca-certificates iproute2 unzip tar gcompat libc6-compat
  elif command_exists zypper; then zypper --non-interactive install curl openssl jq ca-certificates iproute2 unzip tar
  else fail "未找到受支持包管理器，请先安装 curl openssl jq unzip/tar。"; fi
}

xray_arch(){ case "$(uname -m)" in x86_64|amd64) echo 64;; aarch64|arm64) echo arm64-v8a;; armv7*) echo arm32-v7a;; armv6*) echo arm32-v6;; i386|i686) echo 32;; *) fail "不支持架构：$(uname -m)";; esac; }
singbox_arch(){ case "$(uname -m)" in x86_64|amd64) echo amd64;; aarch64|arm64) echo arm64;; armv7*) echo armv7;; *) fail "不支持架构：$(uname -m)";; esac; }

download_xray(){
  local arch asset url zip dgst expected actual out
  arch="$(xray_arch)"; asset="Xray-linux-${arch}.zip"; url="https://github.com/XTLS/Xray-core/releases/latest/download/${asset}"
  TMP_DIR="$(mktemp -d)"; zip="$TMP_DIR/$asset"; dgst="$zip.dgst"; out="$TMP_DIR/out"
  log "下载 Xray：$asset"; curl -fL --connect-timeout 15 --retry 3 -o "$zip" "$url"; curl -fL --connect-timeout 15 --retry 3 -o "$dgst" "$url.dgst"
  expected="$(grep -Ei 'SHA2-256|SHA256' "$dgst" | grep -Eio '[a-f0-9]{64}' | head -n1 | tr A-F a-f)"; [ -n "$expected" ] || fail "无法读取 Xray SHA256。"
  actual="$(openssl dgst -sha256 "$zip" | awk '{print tolower($NF)}')"; [ "$expected" = "$actual" ] || fail "Xray SHA256 校验失败。"
  mkdir -p "$out" /usr/local/bin "$SHARE_DIR"; unzip -qo "$zip" -d "$out"; install -m 755 "$out/xray" "$XRAY_BIN"
  [ -f "$out/geoip.dat" ] && install -m 644 "$out/geoip.dat" "$SHARE_DIR/geoip.dat"; [ -f "$out/geosite.dat" ] && install -m 644 "$out/geosite.dat" "$SHARE_DIR/geosite.dat"
}

download_singbox(){
  local arch api url pkg bin
  arch="$(singbox_arch)"; TMP_DIR="$(mktemp -d)"; api="$TMP_DIR/release.json"; pkg="$TMP_DIR/sing-box.tar.gz"
  log "下载 sing-box"
  curl -fsSL --connect-timeout 15 --retry 3 "https://api.github.com/repos/SagerNet/sing-box/releases/latest" -o "$api"
  url="$(jq -r --arg a "$arch" '.assets[].browser_download_url | select(test("linux-"+$a+"\\.tar\\.gz$"))' "$api" | head -n1)"
  [ -n "$url" ] && [ "$url" != null ] || fail "未找到 sing-box linux-${arch} 发布包。"
  curl -fL --connect-timeout 15 --retry 3 -o "$pkg" "$url"
  mkdir -p "$TMP_DIR/out" /usr/local/bin; tar -xzf "$pkg" -C "$TMP_DIR/out"; bin="$(find "$TMP_DIR/out" -type f -name sing-box | head -n1)"; [ -n "$bin" ] || fail "未找到 sing-box 二进制。"; install -m 755 "$bin" "$SINGBOX_BIN"
}

ensure_user(){ local u="$1"; id "$u" >/dev/null 2>&1 && return; if command_exists useradd; then useradd --system --no-create-home --shell /usr/sbin/nologin "$u" 2>/dev/null || useradd --system --no-create-home --shell /sbin/nologin "$u"; else adduser -S -H -s /sbin/nologin "$u"; fi; }

gen_uuid(){ if [ -x "$XRAY_BIN" ]; then "$XRAY_BIN" uuid 2>/dev/null && return; fi; [ -r /proc/sys/kernel/random/uuid ] && { cat /proc/sys/kernel/random/uuid; return; }; command_exists uuidgen && { uuidgen | tr A-F a-f; return; }; local r; r="$(rand_hex 16)"; printf '%s-%s-%s-%s-%s\n' "${r:0:8}" "${r:8:4}" "${r:12:4}" "${r:16:4}" "${r:20:12}"; }

gen_reality_keys(){
  [ -x "$XRAY_BIN" ] || fail "未找到 Xray：$XRAY_BIN"
  [ -z "$PRIVATE_KEY" ] && [ -n "$PUBLIC_KEY" ] && fail "只提供 public key 无法配置服务端。"
  local out
  if [ -n "$PRIVATE_KEY" ]; then out="$($XRAY_BIN x25519 -i "$PRIVATE_KEY" 2>/dev/null || true)"; else out="$($XRAY_BIN x25519 2>/dev/null || true)"; fi
  PRIVATE_KEY="${PRIVATE_KEY:-$(printf '%s\n' "$out" | awk -F': *' '/PrivateKey|Private key/ {print $2; exit}') }"
  PUBLIC_KEY="${PUBLIC_KEY:-$(printf '%s\n' "$out" | awk -F': *' '/Password \(PublicKey\)|PublicKey|Public key/ {print $2; exit}') }"
  PRIVATE_KEY="$(printf '%s' "$PRIVATE_KEY" | xargs)"; PUBLIC_KEY="$(printf '%s' "$PUBLIC_KEY" | xargs)"
  [ -n "$PRIVATE_KEY" ] && [ -n "$PUBLIC_KEY" ] || fail "生成 REALITY 密钥失败。"
}

gen_hy2_cert(){
  mkdir -p "$CERT_DIR/hy2"; local crt="$CERT_DIR/hy2/server.crt" key="$CERT_DIR/hy2/server.key"
  if [ -f "$crt" ] && [ -f "$key" ]; then local cn; cn="$(openssl x509 -in "$crt" -noout -subject 2>/dev/null | sed 's/.*CN *= *//;s/,.*//')"; [ "$cn" = "$SNI" ] && return; fi
  log "生成 Hysteria2 自签证书：$SNI"; openssl ecparam -genkey -name prime256v1 -out "$key" 2>/dev/null; openssl req -new -x509 -key "$key" -out "$crt" -subj "/CN=$SNI" -days 36500 2>/dev/null; chmod 600 "$key"
}

write_xray_config(){
  mkdir -p "$CONFIG_DIR"; local client network xtra tag
  if [ "$PROTOCOL" = vless-reality ]; then client="{\"id\":\"$(json_escape "$UUID")\",\"flow\":\"xtls-rprx-vision\",\"email\":\"default@vless\"}"; network='"network":"tcp"'; tag="vless-reality-in"; else client="{\"id\":\"$(json_escape "$UUID")\",\"email\":\"default@xhttp\"}"; xtra=",\"xhttpSettings\":{\"path\":\"$(json_escape "$XHTTP_PATH")\",\"mode\":\"auto\",\"host\":\"$(json_escape "$SNI")\"}"; network='"network":"xhttp"'"$xtra"; tag="vless-xhttp-reality-in"; fi
  cat >"$XRAY_CONFIG" <<EOF
{"log":{"loglevel":"warning"},"inbounds":[{"tag":"$tag","listen":"0.0.0.0","port":$PORT,"protocol":"vless","settings":{"clients":[$client],"decryption":"none"},"streamSettings":{$network,"security":"reality","realitySettings":{"show":false,"dest":"$(json_escape "$DEST")","xver":0,"serverNames":["$(json_escape "$SNI")"],"privateKey":"$(json_escape "$PRIVATE_KEY")","shortIds":["$(json_escape "$SHORT_ID")"]}},"sniffing":{"enabled":true,"destOverride":["http","tls"]}}],"outbounds":[{"protocol":"freedom","tag":"direct"},{"protocol":"blackhole","tag":"block"}]}
EOF
  chown -R "$XRAY_USER:$XRAY_USER" "$CONFIG_DIR" "$SHARE_DIR" 2>/dev/null || true; chmod 600 "$XRAY_CONFIG"
}

write_singbox_config(){
  mkdir -p "$CONFIG_DIR"; local crt="$CERT_DIR/hy2/server.crt" key="$CERT_DIR/hy2/server.key"
  cat >"$SINGBOX_CONFIG" <<EOF
{"log":{"level":"warn","timestamp":true},"inbounds":[{"type":"hysteria2","tag":"hy2-in","listen":"0.0.0.0","listen_port":$PORT,"users":[{"name":"default","password":"$(json_escape "$PASSWORD")"}],"ignore_client_bandwidth":true,"tls":{"enabled":true,"certificate_path":"$crt","key_path":"$key","alpn":["h3"]},"masquerade":"https://www.bing.com"}],"outbounds":[{"type":"direct","tag":"direct"}]}
EOF
  chown -R "$SINGBOX_USER:$SINGBOX_USER" "$CONFIG_DIR" 2>/dev/null || true; chmod 600 "$SINGBOX_CONFIG"
}

write_services(){
  cat >"/etc/systemd/system/$XRAY_SERVICE.service" <<EOF
[Unit]
Description=VLESS Lite Xray Service
After=network-online.target nss-lookup.target
Wants=network-online.target
[Service]
User=$XRAY_USER
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=$XRAY_BIN run -config $XRAY_CONFIG
Restart=on-failure
LimitNOFILE=1000000
[Install]
WantedBy=multi-user.target
EOF
  cat >"/etc/systemd/system/$SINGBOX_SERVICE.service" <<EOF
[Unit]
Description=VLESS Lite sing-box Service
After=network-online.target nss-lookup.target
Wants=network-online.target
[Service]
User=$SINGBOX_USER
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=$SINGBOX_BIN run -c $SINGBOX_CONFIG
Restart=on-failure
LimitNOFILE=1000000
[Install]
WantedBy=multi-user.target
EOF
}

svc_name(){ [ "$PROTOCOL" = hy2 ] && printf '%s' "$SINGBOX_SERVICE" || printf '%s' "$XRAY_SERVICE"; }
validate_config(){ if [ "$PROTOCOL" = hy2 ]; then "$SINGBOX_BIN" check -c "$SINGBOX_CONFIG" >/tmp/vless-lite-check.log 2>&1 || { cat /tmp/vless-lite-check.log >&2; fail "sing-box 配置测试失败。"; }; else "$XRAY_BIN" run -test -config "$XRAY_CONFIG" >/tmp/vless-lite-check.log 2>&1 || { cat /tmp/vless-lite-check.log >&2; fail "Xray 配置测试失败。"; }; fi; }
restart_service(){ command_exists systemctl || fail "需要 systemd。"; local s; s="$(svc_name)"; systemctl daemon-reload; systemctl enable --now "$s"; systemctl restart "$s"; systemctl is-active --quiet "$s" || { systemctl status "$s" --no-pager -l >&2 || true; fail "服务启动失败：$s"; }; }

open_firewall(){
  [ "$NO_FIREWALL" -eq 1 ] && return; local p=tcp; [ "$PROTOCOL" = hy2 ] && p=udp
  if command_exists ufw && ufw status 2>/dev/null | grep -qi active; then ufw allow "$PORT/$p" >/dev/null || warn "ufw 放行失败，请手动放行 $PORT/$p。"; fi
  if command_exists firewall-cmd && firewall-cmd --state >/dev/null 2>&1; then firewall-cmd --permanent --add-port="$PORT/$p" >/dev/null || warn "firewalld 放行失败。"; firewall-cmd --reload >/dev/null || true; fi
}

detect_hosts(){ [ -n "$HOST" ] && return; PUBLIC_IPV4="$(curl -4fsS --connect-timeout 5 https://api.ipify.org 2>/dev/null || true)"; PUBLIC_IPV6="$(curl -6fsS --connect-timeout 5 https://api64.ipify.org 2>/dev/null || true)"; }
fmt_host(){ [[ "$1" == *:* && "$1" != \[*\] ]] && printf '[%s]' "$1" || printf '%s' "$1"; }
def_remark(){ case "$PROTOCOL" in vless-reality) echo VLESS-Reality;; vless-xhttp-reality) echo VLESS-XHTTP-Reality;; hy2) echo Hysteria2;; esac; }
make_link(){ local h r s; h="$(fmt_host "$1")"; r="$(urlencode "$REMARK")"; s="$(urlencode "$SNI")"; case "$PROTOCOL" in vless-reality) printf 'vless://%s@%s:%s?encryption=none&flow=xtls-rprx-vision&security=reality&sni=%s&fp=%s&pbk=%s&sid=%s&type=tcp&headerType=none#%s\n' "$UUID" "$h" "$PORT" "$s" "$(urlencode "$FINGERPRINT")" "$(urlencode "$PUBLIC_KEY")" "$(urlencode "$SHORT_ID")" "$r";; vless-xhttp-reality) printf 'vless://%s@%s:%s?encryption=none&security=reality&sni=%s&fp=%s&pbk=%s&sid=%s&type=xhttp&path=%s&mode=auto#%s\n' "$UUID" "$h" "$PORT" "$s" "$(urlencode "$FINGERPRINT")" "$(urlencode "$PUBLIC_KEY")" "$(urlencode "$SHORT_ID")" "$(urlencode "$XHTTP_PATH")" "$r";; hy2) printf 'hysteria2://%s@%s:%s?sni=%s&insecure=1#%s\n' "$PASSWORD" "$h" "$PORT" "$s" "$r";; esac; }

save_state(){ mkdir -p "$CONFIG_DIR"; cat >"$STATE_FILE" <<EOF
PROTOCOL=$(shell_escape "$PROTOCOL")
PORT=$(shell_escape "$PORT")
SNI=$(shell_escape "$SNI")
DEST=$(shell_escape "$DEST")
HOST=$(shell_escape "$HOST")
PUBLIC_IPV4=$(shell_escape "$PUBLIC_IPV4")
PUBLIC_IPV6=$(shell_escape "$PUBLIC_IPV6")
REMARK=$(shell_escape "$REMARK")
UUID=$(shell_escape "$UUID")
PASSWORD=$(shell_escape "$PASSWORD")
PRIVATE_KEY=$(shell_escape "$PRIVATE_KEY")
PUBLIC_KEY=$(shell_escape "$PUBLIC_KEY")
SHORT_ID=$(shell_escape "$SHORT_ID")
XHTTP_PATH=$(shell_escape "$XHTTP_PATH")
FINGERPRINT=$(shell_escape "$FINGERPRINT")
EOF
chmod 600 "$STATE_FILE"; }
load_state(){ [ -f "$STATE_FILE" ] || fail "未找到状态文件：$STATE_FILE"; source "$STATE_FILE"; normalize_protocol; }

print_links(){
  local first="" link proto; proto=tcp; [ "$PROTOCOL" = hy2 ] && proto=udp
  printf '\n协议：%s\n端口：%s/%s\nSNI：%s\n' "$PROTOCOL" "$PORT" "$proto" "$SNI"
  [ "$PROTOCOL" != hy2 ] && printf 'PublicKey：%s\nShortID：%s\n' "$PUBLIC_KEY" "$SHORT_ID"
  printf '\n客户端链接：\n'
  if [ -n "$HOST" ]; then link="$(make_link "$HOST")"; echo "$link"; first="$link"; else [ -n "$PUBLIC_IPV4" ] && { link="$(make_link "$PUBLIC_IPV4")"; echo "IPv4: $link"; first="${first:-$link}"; }; [ -n "$PUBLIC_IPV6" ] && { link="$(make_link "$PUBLIC_IPV6")"; echo "IPv6: $link"; first="${first:-$link}"; }; [ -z "$first" ] && { link="$(make_link YOUR_SERVER_IP)"; echo "$link"; first="$link"; warn "请替换 YOUR_SERVER_IP。"; }; fi
  if command_exists qrencode; then printf '\n二维码：\n'; printf '%s' "$first" | qrencode -t UTF8 -m 2 || true; fi
}

prepare(){
  [ -n "$SNI" ] || SNI="$(rand_sni)"; [ -n "$DEST" ] || DEST="$SNI:443"; [ -n "$REMARK" ] || REMARK="$(def_remark)"; [ -n "$PORT" ] || PORT="$(pick_port)"; validate_port "$PORT"
  port_in_use "$PORT" && warn "端口 $PORT 已被监听；若为旧服务占用，重启后会复用。"
  if [ "$PROTOCOL" = hy2 ]; then [ -n "$PASSWORD" ] || PASSWORD="$(rand_hex 16)"; else [ -n "$UUID" ] || UUID="$(gen_uuid)"; [ -n "$SHORT_ID" ] || SHORT_ID="$(rand_hex 8)"; is_hex "$SHORT_ID" || fail "shortId 必须是十六进制。"; [ ${#SHORT_ID} -le 16 ] || fail "shortId 最长 16 个十六进制字符。"; [ "$PROTOCOL" = vless-xhttp-reality ] && { [ -n "$XHTTP_PATH" ] || XHTTP_PATH="$(rand_path)"; [[ "$XHTTP_PATH" == /* ]] || XHTTP_PATH="/$XHTTP_PATH"; }; fi
}

install_action(){
  need_linux; need_root; install_deps; prepare
  if [ "$PROTOCOL" != hy2 ] && ! curl -fsSI --connect-timeout 5 "https://$SNI" >/dev/null 2>&1; then warn "SNI https://$SNI 探测失败，建议换成可访问的真实 HTTPS 域名。"; fi
  if [ "$PROTOCOL" = hy2 ]; then ensure_user "$SINGBOX_USER"; [ "$SKIP_INSTALL" -eq 1 ] || download_singbox; gen_hy2_cert; write_singbox_config; else ensure_user "$XRAY_USER"; [ "$SKIP_INSTALL" -eq 1 ] || download_xray; gen_reality_keys; write_xray_config; fi
  write_services; validate_config; open_firewall; restart_service; detect_hosts; save_state; printf '\n安装完成。\n'; print_links
}

uninstall_action(){ need_root; [ -f "$STATE_FILE" ] && load_state || true; if [ "$YES" -ne 1 ]; then read -r -p "确认卸载服务并删除 $CONFIG_DIR ? [y/N] " a; [[ "$a" =~ ^[Yy]$ ]] || fail "已取消。"; fi; systemctl stop "$XRAY_SERVICE" "$SINGBOX_SERVICE" 2>/dev/null || true; systemctl disable "$XRAY_SERVICE" "$SINGBOX_SERVICE" 2>/dev/null || true; rm -f "/etc/systemd/system/$XRAY_SERVICE.service" "/etc/systemd/system/$SINGBOX_SERVICE.service"; systemctl daemon-reload 2>/dev/null || true; rm -rf "$CONFIG_DIR"; log "已卸载。核心二进制未删除：$XRAY_BIN $SINGBOX_BIN"; }
update_core_action(){ need_linux; need_root; load_state; install_deps; [ "$PROTOCOL" = hy2 ] && download_singbox || download_xray; restart_service; log "核心已更新。"; }

main(){ parse_args "$@"; case "$ACTION" in install) install_action;; show-link) load_state; print_links;; status) load_state; systemctl status "$(svc_name)" --no-pager -l;; logs) load_state; journalctl -u "$(svc_name)" -e --no-pager;; restart) need_root; load_state; restart_service; log "已重启。";; update-core) update_core_action;; uninstall) uninstall_action;; *) fail "未知动作：$ACTION";; esac; }
main "$@"
