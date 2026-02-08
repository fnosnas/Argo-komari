#!/usr/bin/env bash

# 变量设置
ARGO_PORT=${PORT:-8080}
UUID=${UUID:-"fd2fbdc1-1ef5-4831-adb3-ffddc0303a30"}

# 1. 运行节点环境 (Xray)
wget -qO /tmp/xray.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
unzip -o /tmp/xray.zip -d /tmp/
cat <<EOF > /tmp/config.json
{"inbounds":[{"port":$ARGO_PORT,"protocol":"vless","settings":{"clients":[{"id":"$UUID"}],"decryption":"none"},"streamSettings":{"network":"ws"}}],"outbounds":[{"protocol":"freedom"}]}
EOF
/tmp/xray -c /tmp/config.json >/dev/null 2>&1 &

# 2. 安装 Komari 探针 (适配非 Root)
if [ -n "$KOMARI_URL" ] && [ -n "$KOMARI_KEY" ]; then
    curl -sL https://raw.githubusercontent.com/komari-monitor/komari-agent/refs/heads/main/install.sh | bash -s -- -e "$KOMARI_URL" -t "$KOMARI_KEY" >/dev/null 2>&1 &
fi

# 3. 运行 Argo 隧道并保持前台运行 (防止容器退出)
wget -qO /tmp/cloudflared https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
chmod +x /tmp/cloudflared

echo "启动 Argo 隧道..."
# 用 exec 确保 cloudflared 作为主进程，如果它挂了，容器会自动重启
exec /tmp/cloudflared tunnel --no-autoupdate run --token "$ARGO_TOKEN"
