#!/usr/bin/env bash
set -euo pipefail

# ============ 基本信息 ============
APP_NAME="akbox"
APP_DIR_DEFAULT_ROOT="/opt/${APP_NAME}"
APP_DIR_DEFAULT_USER="${HOME}/.${APP_NAME}"
BIN_DIR_NAME="bin"
CONF_DIR_NAME="conf"
RUN_DIR_NAME="run"
LOG_DIR_NAME="log"

# ============ 读取环境变量（你要求的 4+2 个变量） ============
ARGO_DOMAIN="${ARGO_DOMAIN:-}"
ARGO_TOKEN="${ARGO_TOKEN:-}"
UUID="${UUID:-}"
ARGO_PORT="${ARGO_PORT:-}"

KOMARI_URL="${KOMARI_URL:-}"
KOMARI_TOKEN="${KOMARI_TOKEN:-}"

# 可选：指定 GitHub raw 你的仓库地址（默认用当前脚本所在仓库 raw）
REPO_RAW_BASE="${REPO_RAW_BASE:-}"

# ============ 工具函数 ============
log(){ echo -e "[${APP_NAME}] $*"; }
die(){ echo -e "[${APP_NAME}] ERROR: $*" >&2; exit 1; }

need_cmd(){
  command -v "$1" >/dev/null 2>&1 || die "缺少命令：$1。请先安装它（root 可自动装，非 root 请让服务商装）"
}

is_root(){
  [ "$(id -u)" -eq 0 ]
}

detect_arch(){
  local arch
  arch="$(uname -m)"
  case "$arch" in
    x86_64|amd64) echo "amd64" ;;
    aarch64|arm64) echo "arm64" ;;
    *) die "不支持的架构：$arch（目前仅支持 amd64/arm64）" ;;
  esac
}

install_pkg_root(){
  # 仅 root 模式：尽量自动装依赖
  local pkgs=("$@")
  if command -v apt-get >/dev/null 2>&1; then
    apt-get update -y >/dev/null
    apt-get install -y "${pkgs[@]}" >/dev/null
  elif command -v yum >/dev/null 2>&1; then
    yum install -y "${pkgs[@]}" >/dev/null
  elif command -v dnf >/dev/null 2>&1; then
    dnf install -y "${pkgs[@]}" >/dev/null
  elif command -v pacman >/dev/null 2>&1; then
    pacman -Sy --noconfirm "${pkgs[@]}" >/dev/null
  else
    die "无法识别包管理器，请手动安装：${pkgs[*]}"
  fi
}

ensure_deps(){
  # curl 必须
  if ! command -v curl >/dev/null 2>&1; then
    if is_root; then install_pkg_root curl ca-certificates; else die "缺少 curl（非 root 无法自动安装）"; fi
  fi

  # unzip：用于解压 xray zip
  if ! command -v unzip >/dev/null 2>&1; then
    if command -v busybox >/dev/null 2>&1 && busybox unzip >/dev/null 2>&1; then
      : # 用 busybox unzip
    else
      if is_root; then install_pkg_root unzip; else die "缺少 unzip（非 root 无法自动安装）。请让服务商装 unzip 或改用 Docker 方案。"; fi
    fi
  fi
}

gen_uuid(){
  if [ -z "${UUID}" ]; then
    if [ -r /proc/sys/kernel/random/uuid ]; then
      UUID="$(cat /proc/sys/kernel/random/uuid)"
    else
      need_cmd uuidgen
      UUID="$(uuidgen)"
    fi
  fi
}

check_vars(){
  [ -n "${ARGO_TOKEN}" ] || die "必须提供 ARGO_TOKEN（Cloudflare Tunnel token，eyJ...）"
  [ -n "${ARGO_DOMAIN}" ] || die "必须提供 ARGO_DOMAIN（你的固定隧道域名）"
  [ -n "${ARGO_PORT}" ] || die "必须提供 ARGO_PORT（xray 本地端口，如 8080）"
  gen_uuid
}

download_file(){
  local url="$1"
  local out="$2"
  curl -fsSL "$url" -o "$out"
}

download_xray(){
  # 说明：xray 官方发布为 zip 包，解压得到 xray 可执行文件[7](https://xtls.github.io/document/install.html)
  local arch="$1"
  local tmpzip="${APP_DIR}/tmp/xray.zip"
  mkdir -p "${APP_DIR}/tmp"
  local url=""
  if [ "$arch" = "amd64" ]; then
    url="https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip"
  else
    url="https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-arm64-v8a.zip"
  fi
  log "下载 Xray：$url"
  download_file "$url" "$tmpzip"

  mkdir -p "${APP_DIR}/${BIN_DIR_NAME}"
  if command -v unzip >/dev/null 2>&1; then
    unzip -o "$tmpzip" -d "${APP_DIR}/tmp" >/dev/null
  else
    busybox unzip -o "$tmpzip" -d "${APP_DIR}/tmp" >/dev/null
  fi
  mv -f "${APP_DIR}/tmp/xray" "${APP_DIR}/${BIN_DIR_NAME}/xray"
  chmod +x "${APP_DIR}/${BIN_DIR_NAME}/xray"
}

download_cloudflared(){
  local arch="$1"
  local url=""
  if [ "$arch" = "amd64" ]; then
    url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64"
  else
    url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64"
  fi
  log "下载 cloudflared：$url"
  mkdir -p "${APP_DIR}/${BIN_DIR_NAME}"
  download_file "$url" "${APP_DIR}/${BIN_DIR_NAME}/cloudflared"
  chmod +x "${APP_DIR}/${BIN_DIR_NAME}/cloudflared"
}

download_komari_agent(){
  # Komari 文档给出二进制命名：komari-agent-linux-amd64/arm64 等[2](https://komari-monitor.github.io/komari-document/faq/agent-no-root.html)
  local arch="$1"
  local url=""
  if [ "$arch" = "amd64" ]; then
    url="https://github.com/komari-monitor/komari-agent/releases/latest/download/komari-agent-linux-amd64"
  else
    url="https://github.com/komari-monitor/komari-agent/releases/latest/download/komari-agent-linux-arm64"
  fi
  log "下载 komari-agent：$url"
  mkdir -p "${APP_DIR}/${BIN_DIR_NAME}"
  download_file "$url" "${APP_DIR}/${BIN_DIR_NAME}/komari-agent"
  chmod +x "${APP_DIR}/${BIN_DIR_NAME}/komari-agent"
}

write_xray_config(){
  mkdir -p "${APP_DIR}/${CONF_DIR_NAME}"
  cat > "${APP_DIR}/${CONF_DIR_NAME}/xray.json" <<EOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "listen": "127.0.0.1",
      "port": ${ARGO_PORT},
      "protocol": "vless",
      "settings": {
        "clients": [
          { "id": "${UUID}" }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": { "path": "/" }
      }
    }
  ],
  "outbounds": [
    { "protocol": "freedom", "settings": {} }
  ]
}
EOF
}

write_env_file(){
  mkdir -p "${APP_DIR}/${CONF_DIR_NAME}"
  # 权限尽量收紧
  umask 077
  cat > "${APP_DIR}/${CONF_DIR_NAME}/env" <<EOF
ARGO_DOMAIN=${ARGO_DOMAIN}
ARGO_TOKEN=${ARGO_TOKEN}
UUID=${UUID}
ARGO_PORT=${ARGO_PORT}
KOMARI_URL=${KOMARI_URL}
KOMARI_TOKEN=${KOMARI_TOKEN}
EOF
  chmod 600 "${APP_DIR}/${CONF_DIR_NAME}/env" || true
}

write_run_scripts(){
  mkdir -p "${APP_DIR}/${RUN_DIR_NAME}" "${APP_DIR}/${LOG_DIR_NAME}"

  cat > "${APP_DIR}/${RUN_DIR_NAME}/start-xray.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
APP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "${APP_DIR}/conf/env" || true
exec "${APP_DIR}/bin/xray" -config "${APP_DIR}/conf/xray.json"
EOF

  cat > "${APP_DIR}/${RUN_DIR_NAME}/start-cloudflared.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
APP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "${APP_DIR}/conf/env" || true
# Cloudflare 官方说明：远程托管 tunnel 只需要 token 即可运行[5](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/configure-tunnels/remote-tunnel-permissions/)
exec "${APP_DIR}/bin/cloudflared" tunnel --no-autoupdate run --token "${ARGO_TOKEN}"
EOF

  cat > "${APP_DIR}/${RUN_DIR_NAME}/start-komari.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
APP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "${APP_DIR}/conf/env" || true

if [ -z "${KOMARI_URL:-}" ] || [ -z "${KOMARI_TOKEN:-}" ]; then
  echo "[akbox] KOMARI_URL/KOMARI_TOKEN 未设置，跳过 komari-agent"
  exec sleep 365d
fi

# 有些环境下 agent 自动更新检查可能卡住，文档/经验通常建议可禁用[6](https://blog.carkree.com/posts/298638345/)
exec "${APP_DIR}/bin/komari-agent" -e "${KOMARI_URL}" -t "${KOMARI_TOKEN}" --disable-auto-update
EOF

  chmod +x "${APP_DIR}/${RUN_DIR_NAME}/"*.sh
}

print_client_link(){
  mkdir -p "${APP_DIR}"
  local link="vless://${UUID}@${ARGO_DOMAIN}:443?encryption=none&security=tls&type=ws&host=${ARGO_DOMAIN}&path=%2F#${APP_NAME}"
  cat > "${APP_DIR}/client.txt" <<EOF
=== ${APP_NAME} 节点信息 ===
协议：VLESS + WS（走 Cloudflare Tunnel 固定域名）
地址：${ARGO_DOMAIN}
端口：443
UUID：${UUID}
WS Path：/

一键导入（大部分客户端支持）：
${link}
EOF
  log "已生成：${APP_DIR}/client.txt"
  log "节点链接：${link}"
}

setup_systemd_root(){
  command -v systemctl >/dev/null 2>&1 || { log "无 systemd，改用 cron 保活"; setup_cron_user; return; }

  log "创建 systemd 服务（root 模式）"
  cat > /etc/systemd/system/${APP_NAME}-xray.service <<EOF
[Unit]
Description=${APP_NAME} xray
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=${APP_DIR}
EnvironmentFile=${APP_DIR}/conf/env
ExecStart=${APP_DIR}/run/start-xray.sh
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

  cat > /etc/systemd/system/${APP_NAME}-cloudflared.service <<EOF
[Unit]
Description=${APP_NAME} cloudflared
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=${APP_DIR}
EnvironmentFile=${APP_DIR}/conf/env
ExecStart=${APP_DIR}/run/start-cloudflared.sh
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

  cat > /etc/systemd/system/${APP_NAME}-komari.service <<EOF
[Unit]
Description=${APP_NAME} komari-agent (optional)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=${APP_DIR}
EnvironmentFile=${APP_DIR}/conf/env
ExecStart=${APP_DIR}/run/start-komari.sh
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable --now "${APP_NAME}-xray.service" "${APP_NAME}-cloudflared.service" "${APP_NAME}-komari.service"
  log "systemd 已启用：${APP_NAME}-xray / ${APP_NAME}-cloudflared / ${APP_NAME}-komari"
}

setup_cron_user(){
  # 非 root：用 @reboot + watchdog 保活（Komari 非 root 文档也推荐 nohup/screen/tmux 这类方式[2](https://komari-monitor.github.io/komari-document/faq/agent-no-root.html)）
  log "配置 crontab 保活（非 root / 或无 systemd）"

  mkdir -p "${APP_DIR}/${RUN_DIR_NAME}" "${APP_DIR}/${LOG_DIR_NAME}"

  cat > "${APP_DIR}/${RUN_DIR_NAME}/boot.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
APP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "${APP_DIR}/conf/env" || true

mkdir -p "${APP_DIR}/log"

start_bg(){
  local name="$1"
  local cmd="$2"
  local pidfile="${APP_DIR}/run/${name}.pid"
  if [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile")" 2>/dev/null; then
    exit 0
  fi
  nohup bash -c "$cmd" >> "${APP_DIR}/log/${name}.log" 2>&1 &
  echo $! > "$pidfile"
}

start_bg "xray" "${APP_DIR}/run/start-xray.sh"
start_bg "cloudflared" "${APP_DIR}/run/start-cloudflared.sh"
start_bg "komari" "${APP_DIR}/run/start-komari.sh"
EOF

  cat > "${APP_DIR}/${RUN_DIR_NAME}/watchdog.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
APP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
bash "${APP_DIR}/run/boot.sh" >/dev/null 2>&1 || true
EOF

  chmod +x "${APP_DIR}/${RUN_DIR_NAME}/boot.sh" "${APP_DIR}/${RUN_DIR_NAME}/watchdog.sh"

  # 写入 crontab（去重）
  local cron_line_reboot="@reboot ${APP_DIR}/run/boot.sh"
  local cron_line_watch="*/1 * * * * ${APP_DIR}/run/watchdog.sh"
  (crontab -l 2>/dev/null || true) | grep -v "${APP_DIR}/run/boot.sh" | grep -v "${APP_DIR}/run/watchdog.sh" > "${APP_DIR}/tmp.cron" || true
  printf "%s\n%s\n" "$cron_line_reboot" "$cron_line_watch" >> "${APP_DIR}/tmp.cron"
  crontab "${APP_DIR}/tmp.cron"
  rm -f "${APP_DIR}/tmp.cron"

  # 立刻启动一次
  bash "${APP_DIR}/run/boot.sh"
  log "crontab 已配置：开机自启 + 每分钟 watchdog"
}

main(){
  check_vars
  ensure_deps

  local arch
  arch="$(detect_arch)"
  log "检测架构：${arch}"

  if is_root; then
    APP_DIR="${APP_DIR_DEFAULT_ROOT}"
  else
    APP_DIR="${APP_DIR_DEFAULT_USER}"
  fi
  export APP_DIR

  log "安装目录：${APP_DIR}"
  mkdir -p "${APP_DIR}"

  download_xray "${arch}"
  download_cloudflared "${arch}"
  download_komari_agent "${arch}"

  write_xray_config
  write_env_file
  write_run_scripts
  print_client_link

  if is_root; then
    setup_systemd_root
  else
    setup_cron_user
  fi

  log "完成 ✅"
  log "下一步：去 Cloudflare Zero Trust → Tunnels → 给你的隧道配置 Public Hostname：${ARGO_DOMAIN} → Service 指向 http://localhost:${ARGO_PORT}"
}

main "$@"
