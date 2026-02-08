#!/usr/bin/env bash

# 环境变量设置
ARGO_PORT=${PORT:-8080}
UUID=${UUID:-"fd2fbdc1-1ef5-4831-adb3-ffddc0303a30"}

# 1. 运行节点后端 (Xray)
wget -qO /tmp/xray.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
unzip -o /tmp/xray.zip -d /tmp/
cat <<EOF > /tmp/config.json
{"inbounds":[{"port":$ARGO_PORT,"protocol":"vless","settings":{"clients":[{"id":"$UUID"}],"decryption":"none"},"streamSettings":{"network":"ws"}}],"outbounds":[{"protocol":"freedom"}]}
EOF
# 后台运行 Xray
/tmp/xray -c /tmp/config.json >/dev/null 2>&1 &

# 2. 安装 Komari 探针 (变量：KOMARI_URL, KOMARI_KEY)
if [ -n "$KOMARI_URL" ] && [ -n "$KOMARI_KEY" ]; then
    echo "正在安装探针..."
    curl -sL https://raw.githubusercontent.com/komari-monitor/komari-agent/refs/heads/main/install.sh | bash -s -- -e "$KOMARI_URL" -t "$KOMARI_KEY" >/dev/null 2>&1 &
fi

# 3. 运行 Argo 隧道
# 下载 cloudflared
wget -qO /tmp/cloudflared https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
chmod +x /tmp/cloudflared

echo "Argo 隧道启动中..."
# 【关键】exec 命令会让 cloudflared 成为 1 号进程。它如果不死，容器就不会停。
# 如果它挂了，Railway/Sealos 会检测到进程退出并自动拉起整个容器。
exec /tmp/cloudflared tunnel --no-autoupdate run --token "$ARGO_TOKEN"
