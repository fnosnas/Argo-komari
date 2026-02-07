#!/usr/bin/env bash
set -euo pipefail

if [ -z "${KOMARI_URL:-}" ] || [ -z "${KOMARI_TOKEN:-}" ]; then
  echo "[akbox] KOMARI_URL/KOMARI_TOKEN 未设置，komari-agent 不启动"
  exec sleep 365d
fi

# 有些环境下 agent 自动更新检查可能卡住，经验上可禁用[6](https://blog.carkree.com/posts/298638345/)
exec /usr/local/bin/komari-agent -e "${KOMARI_URL}" -t "${KOMARI_TOKEN}" --disable-auto-update
