# akbox (Argo Fixed Tunnel + VLESS/WS + optional Komari Agent)

最小化版本：只做 **1 个固定 Cloudflare Tunnel**，内置：
- xray：VLESS + WebSocket（本地 127.0.0.1:ARGO_PORT）
- cloudflared：用 `ARGO_TOKEN` 连接 Cloudflare Tunnel
- komari-agent（可选）：若提供 KOMARI_URL/KOMARI_TOKEN 则启动

> Cloudflare 远程托管 Tunnel 只需要 token 即可运行（eyJ...）。  
> 参考 Cloudflare 文档：tunnel token / permissions。

## 环境变量（你只需要填这些）
必填：
- `ARGO_DOMAIN`：你的固定隧道域名
- `ARGO_TOKEN`：Cloudflare Tunnel token（eyJ...）
- `ARGO_PORT`：本地端口（如 8080）

可选：
- `UUID`：不填则自动生成
- `KOMARI_URL`：Komari 面板地址（如 https://komari.xxx.com）
- `KOMARI_TOKEN`：Komari Agent token

---

## VPS 一键安装（支持非 root）
```bash
ARGO_DOMAIN="xxx.yourdomain.com" \
ARGO_TOKEN="eyJ..." \
UUID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" \
ARGO_PORT="8080" \
KOMARI_URL="https://komari.xxx.com" \
KOMARI_TOKEN="yyyyy" \
bash <(curl -fsSL https://raw.githubusercontent.com/<你的GitHub用户名>/akbox/main/install.sh)
