#!/usr/bin/env bash

# --- 变量设置 ---
ARGO_PORT=${PORT:-8001}
UUID=${UUID:-"fd2fbdc1-1ef5-4831-adb3-ffddc0303a30"}
# ARGO_TOKEN, KOMARI_URL, KOMARI_KEY 由外部环境变量传入

# --- 1. 下载并启动 Xray 节点 ---
echo "正在配置 Xray 节点..."
wget -qO /tmp/xray.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
unzip -o /tmp/xray.zip -d /tmp/
cat <<EOF > /tmp/config.json
{
    "inbounds": [{
        "port": $ARGO_PORT,
        "protocol": "vless",
        "settings": {
            "clients": [{"id": "$UUID"}],
            "decryption": "none"
        },
        "streamSettings": {
            "network": "ws",
            "wsSettings": {"path": "/"}
        }
    }],
    "outbounds": [{"protocol": "freedom"}]
}
EOF
/tmp/xray -c /tmp/config.json >/dev/null 2>&1 &

# --- 2. 下载并启动 Komari 探针 ---
if [ -n "$KOMARI_URL" ] && [ -n "$KOMARI_KEY" ]; then
    echo "正在拉起 Komari 探针..."
    # 直接下载 agent 二进制文件，绕过复杂的安装脚本以兼容非 root 环境
    wget -qO /tmp/komari-agent https://github.com/komari-monitor/komari-agent/releases/latest/download/komari-agent-linux-amd64
    chmod +x /tmp/komari-agent
    /tmp/komari-agent -e "$KOMARI_URL" -t "$KOMARI_KEY" >/dev/null 2>&1 &
fi

# --- 3. 下载并启动 Argo 隧道 ---
echo "正在配置 Argo 隧道..."
wget -qO /tmp/cloudflared https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
chmod +x /tmp/cloudflared

# 启动 Argo 并放入后台
/tmp/cloudflared tunnel --no-autoupdate run --token "$ARGO_TOKEN" >/dev/null 2>&1 &

# --- 4. 终极保活逻辑 ---
echo "所有服务已在后台启动，系统持续运行中..."
while true; do
    # 每 60 秒检查一次 Argo 进程，挂了就重启
    if ! pgrep -x "cloudflared" > /dev/null; then
        echo "检测到 Argo 掉线，正在重启..."
        /tmp/cloudflared tunnel --no-autoupdate run --token "$ARGO_TOKEN" >/dev/null 2>&1 &
    fi
    # 保持脚本不退出，防止容器停止
    sleep 60
done
