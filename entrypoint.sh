#!/usr/bin/env bash

# 变量设置
ARGO_PORT=${PORT:-8001}
UUID=${UUID:-"fd2fbdc1-1ef5-4831-adb3-ffddc0303a30"}

# 1. 节点环境 (强制存放在 /tmp 解决权限问题)
wget -qO /tmp/xray.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
unzip -o /tmp/xray.zip -d /tmp/
cat <<EOF > /tmp/config.json
{"inbounds":[{"port":$ARGO_PORT,"protocol":"vless","settings":{"clients":[{"id":"$UUID"}],"decryption":"none"},"streamSettings":{"network":"ws","wsSettings":{"path":"/"}}}],"outbounds":[{"protocol":"freedom"}]}
EOF
# 启动节点
/tmp/xray -c /tmp/config.json >/dev/null 2>&1 &

# 2. 探针 (针对容器/非root环境优化)
if [ -n "$KOMARI_URL" ] && [ -n "$KOMARI_KEY" ]; then
    echo "正在尝试安装并运行探针..."
    # 强制跳过系统服务安装，仅运行 agent 进程
    curl -sL https://raw.githubusercontent.com/komari-monitor/komari-agent/main/install.sh | bash -s -- -e "$KOMARI_URL" -t "$KOMARI_KEY" >/dev/null 2>&1 &
fi

# 3. 运行 Argo 隧道 (主进程)
wget -qO /tmp/cloudflared https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
chmod +x /tmp/cloudflared

echo "Argo 隧道启动中..."
exec /tmp/cloudflared tunnel --no-autoupdate run --token "$ARGO_TOKEN"
