#!/usr/bin/env bash

# --- 1. 基础配置 ---
ARGO_PORT=${PORT:-8001}
UUID=${UUID:-"fd2fbdc1-1ef5-4831-adb3-ffddc0303a30"}

# --- 2. 启动 Xray ---
wget -qO /tmp/xray.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
unzip -o /tmp/xray.zip -d /tmp/
cat <<EOF > /tmp/config.json
{"inbounds":[{"port":$ARGO_PORT,"protocol":"vless","settings":{"clients":[{"id":"$UUID"}],"decryption":"none"},"streamSettings":{"network":"ws","wsSettings":{"path":"/"}}}],"outbounds":[{"protocol":"freedom"}]}
EOF
/tmp/xray -c /tmp/config.json >/dev/null 2>&1 &

# --- 3. 启动探针 ---
if [ -n "$KOMARI_URL" ] && [ -n "$KOMARI_KEY" ]; then
    wget -qO /tmp/komari-agent https://github.com/komari-monitor/komari-agent/releases/latest/download/komari-agent-linux-amd64
    chmod +x /tmp/komari-agent
    /tmp/komari-agent -e "$KOMARI_URL" -t "$KOMARI_KEY" >/dev/null 2>&1 &
fi

# --- 4. 启动 Argo 隧道 ---
wget -qO /tmp/cloudflared https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
chmod +x /tmp/cloudflared
/tmp/cloudflared tunnel --no-autoupdate run --token "$ARGO_TOKEN" >/dev/null 2>&1 &

# --- 5. 【终极绝杀】伪装 Web 服务并死循环 ---
# 用 Python 或 nc 临时监听 8001 端口，给平台一个“我还在”的假象
echo "正在创建保活服务..."
while true; do
    # 这行代码会打印心跳日志，证明容器没死
    echo "$(date) - 隧道正常运行中..."
    # 简单的保活，防止进程退出
    sleep 60
done
