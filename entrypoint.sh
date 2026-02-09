#!/usr/bin/env bash

# --- 1. 环境准备 ---
ARGO_PORT=${PORT:-8001}
UUID=${UUID:-"fd2fbdc1-1ef5-4831-adb3-ffddc0303a30"}

# --- 2. 启动 Xray (后台) ---
echo "正在启动 Xray 节点..."
wget -qO /tmp/xray.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
unzip -o /tmp/xray.zip -d /tmp/
cat <<EOF > /tmp/config.json
{"inbounds":[{"port":$ARGO_PORT,"protocol":"vless","settings":{"clients":[{"id":"$UUID"}],"decryption":"none"},"streamSettings":{"network":"ws","wsSettings":{"path":"/"}}}],"outbounds":[{"protocol":"freedom"}]}
EOF
/tmp/xray -c /tmp/config.json >/dev/null 2>&1 &

# --- 3. 启动探针 (后台) ---
if [ -n "$KOMARI_URL" ] && [ -n "$KOMARI_KEY" ]; then
    echo "正在启动探针..."
    wget -qO /tmp/komari-agent https://github.com/komari-monitor/komari-agent/releases/latest/download/komari-agent-linux-amd64
    chmod +x /tmp/komari-agent
    /tmp/komari-agent -e "$KOMARI_URL" -t "$KOMARI_KEY" >/dev/null 2>&1 &
fi

# --- 4. 启动 Argo 隧道 (前台接管) ---
echo "正在启动 Argo 隧道..."
wget -qO /tmp/cloudflared https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
chmod +x /tmp/cloudflared

# 【高亮】这里使用 exec，会让 cloudflared 成为容器的一号进程
# 只要隧道没断，容器绝对不会重启
exec /tmp/cloudflared tunnel --no-autoupdate run --token "$ARGO_TOKEN"
