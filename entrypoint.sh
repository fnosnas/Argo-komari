#!/usr/bin/env bash

# 1. 变量设置 (默认值)
ARGO_PORT=${PORT:-8001}
UUID=${UUID:-"fd2fbdc1-1ef5-4831-adb3-ffddc0303a30"}

# 2. 启动 Xray 节点
wget -qO /tmp/xray.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
unzip -o /tmp/xray.zip -d /tmp/
cat <<EOF > /tmp/config.json
{"inbounds":[{"port":$ARGO_PORT,"protocol":"vless","settings":{"clients":[{"id":"$UUID"}],"decryption":"none"},"streamSettings":{"network":"ws","wsSettings":{"path":"/"}}}],"outbounds":[{"protocol":"freedom"}]}
EOF
/tmp/xray -c /tmp/config.json >/dev/null 2>&1 &

# 3. 启动探针 (增加调试输出)
if [ -n "$KOMARI_URL" ] && [ -n "$KOMARI_KEY" ]; then
    echo "正在尝试安装并运行探针..."
    # 强制下载并直接运行二进制，绕过安装脚本的权限检查
    curl -sL https://raw.githubusercontent.com/komari-monitor/komari-agent/main/install.sh | bash -s -- -e "$KOMARI_URL" -t "$KOMARI_KEY" >/dev/null 2>&1 &
fi

# 4. 启动 Argo 隧道
wget -qO /tmp/cloudflared https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
chmod +x /tmp/cloudflared

echo "Argo 隧道启动中..."
# 这里不再用 exec，而是后台运行，并在最后加一个死循环保活
/tmp/cloudflared tunnel --no-autoupdate run --token "$ARGO_TOKEN" >/dev/null 2>&1 &

# 5. 【关键】防止容器退出的死循环
echo "所有服务已在后台启动，系统持续运行中..."
while true; do
    sleep 60
    # 每分钟检查一次进程，如果 argo 挂了就尝试重启
    ps -ef | grep cloudflared | grep -v grep >/dev/null || /tmp/cloudflared tunnel --no-autoupdate run --token "$ARGO_TOKEN" >/dev/null 2>&1 &
done
