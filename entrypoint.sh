#!/usr/bin/env bash

# 定义变量（如果环境变量没给，则使用默认值）
ARGO_PORT=${PORT:-8080}
UUID=${UUID:-"fd2fbdc1-1ef5-4831-adb3-ffddc0303a30"}

# 1. 启动简单的 VLESS 节点协议 (让 Argo 有东西可以转发)
# 这里我们使用一个轻量级的二进制或简单的转发逻辑
cat <<EOF > /tmp/config.json
{
    "inbounds": [{"port": $ARGO_PORT,"protocol": "vless","settings": {"clients": [{"id": "$UUID"}],"decryption": "none"}}],
    "outbounds": [{"protocol": "freedom"}]
}
EOF
# 下载并运行 xray 作为后端协议
wget -qO /tmp/xray https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
unzip -o /tmp/xray -d /tmp/
/tmp/xray -c /tmp/config.json >/dev/null 2>&1 &

# 2. 安装并启动 Komari 探针
if [ -n "$KOMARI_URL" ] && [ -n "$KOMARI_KEY" ]; then
    echo "正在启动 Komari 探针..."
    # 移除 sudo 依赖以支持非 root 环境
    curl -sL https://raw.githubusercontent.com/komari-monitor/komari-agent/refs/heads/main/install.sh | bash -s -- -e "$KOMARI_URL" -t "$KOMARI_KEY" >/dev/null 2>&1 &
fi

# 3. 启动 Argo 隧道
echo "正在启动 Argo 隧道..."
wget -qO /tmp/cloudflared https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
chmod +x /tmp/cloudflared

# 使用 Token 运行固定隧道
/tmp/cloudflared tunnel --no-autoupdate run --token "$ARGO_TOKEN"
