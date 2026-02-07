#!/usr/bin/env bash
set -euo pipefail

: "${ARGO_TOKEN:?必须设置 ARGO_TOKEN}"
: "${ARGO_DOMAIN:?必须设置 ARGO_DOMAIN}"
: "${ARGO_PORT:=8080}"

if [ -z "${UUID:-}" ]; then
  UUID="$(cat /proc/sys/kernel/random/uuid)"
  export UUID
fi

mkdir -p /etc/akbox

# 生成 xray 配置（VLESS + WS，本地监听 127.0.0.1:ARGO_PORT）
cat > /etc/akbox/xray.json <<EOF
{
  "log": { "loglevel": "warning" },
  "inbounds": [
    {
      "listen": "127.0.0.1",
      "port": ${ARGO_PORT},
      "protocol": "vless",
      "settings": { "clients": [ { "id": "${UUID}" } ], "decryption": "none" },
      "streamSettings": { "network": "ws", "wsSettings": { "path": "/" } }
    }
  ],
  "outbounds": [ { "protocol": "freedom", "settings": {} } ]
}
EOF

# 输出节点信息到日志
echo "=== akbox node ==="
echo "vless://${UUID}@${ARGO_DOMAIN}:443?encryption=none&security=tls&type=ws&host=${ARGO_DOMAIN}&path=%2F#akbox"
echo "ARGO_PORT(local)=${ARGO_PORT}"
echo "KOMARI_URL=${KOMARI_URL:-<empty>}"

exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
``
