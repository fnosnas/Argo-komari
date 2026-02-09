#!/usr/bin/env bash

# --- 1. 变量准备 ---
ARGO_PORT=${PORT:-8001}
UUID=${UUID:-"fd2fbdc1-1ef5-4831-adb3-ffddc0303a30"}
CHECK_INTERVAL=30

# --- 2. 启动 Xray 节点 (后台运行) ---
echo "启动 Xray..."
wget -qO /tmp/xray.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
unzip -o /tmp/xray.zip -d /tmp/
cat <<EOF > /tmp/config.json
{
    "inbounds": [{
        "port": $ARGO_PORT,
        "protocol": "vless",
        "settings": {"clients": [{"id": "$UUID"}], "decryption": "none"},
        "streamSettings": {"network": "ws", "wsSettings": {"path": "/"}}
    }],
    "outbounds": [{"protocol": "freedom"}]
}
EOF
/tmp/xray -c /tmp/config.json >/dev/null 2>&1 &

# --- 3. 启动 Komari 探针 (后台运行) ---
if [ -n "$KOMARI_URL" ] && [ -n "$KOMARI_KEY" ]; then
    echo "启动 Komari 探针..."
    wget -qO /tmp/komari-agent https://github.com/komari-monitor/komari-agent/releases/latest/download/komari-agent-linux-amd64
    chmod +x /tmp/komari-agent
    /tmp/komari-agent -e "$KOMARI_URL" -t "$KOMARI_KEY" >/dev/null 2>&1 &
fi

# --- 4. 启动 Argo 隧道 (主进程，前台运行) ---
echo "启动 Argo 隧道..."
wget -qO /tmp/cloudflared https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
chmod +x /tmp/cloudflared

# 【关键修改】不再让 cloudflared 去后台，直接让它占领终端
# 这样 Sealos 就能监控到这个进程。只要它不关，Pod 就不死。
# 如果 cloudflared 意外崩溃，脚本会进入下面的死循环尝试拉起。

/tmp/cloudflared tunnel --no-autoupdate run --token "$ARGO_TOKEN" &

# --- 5. 守护进程逻辑 ---
echo "监控启动中..."
while true; do
    # 检查 Xray 是否还在
    pgrep -x "xray" >/dev/null || /tmp/xray -c /tmp/config.json >/dev/null 2>&1 &
    
    # 检查 Argo 是否还在
    if ! pgrep -x "cloudflared" >/dev/null; then
        echo "重启 Argo..."
        /tmp/cloudflared tunnel --no-autoupdate run --token "$ARGO_TOKEN" &
    fi

    # 检查探针是否还在
    if [ -n "$KOMARI_URL" ] && ! pgrep -f "komari-agent" >/dev/null; then
        /tmp/komari-agent -e "$KOMARI_URL" -t "$KOMARI_KEY" >/dev/null 2>&1 &
    fi

    sleep $CHECK_INTERVAL
done
