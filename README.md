# 我的 Argo 自用项目

### VPS 一键部署 (支持非 root)
将下方变量替换为你自己的，直接粘贴到 SSH 窗口：

```bash
export ARGO_DOMAIN="你的域名" \
export ARGO_TOKEN="你的Token" \
export UUID="你的UUID" \
export PORT="8080" \
export KOMARI_URL="[https://komari.afnos86.xx.kg](https://komari.afnos86.xx.kg)" \
export KOMARI_KEY="你的密钥" \
&& bash <(curl -sL [https://raw.githubusercontent.com/你的用户名/项目名/main/entrypoint.sh](https://raw.githubusercontent.com/你的用户名/项目名/main/entrypoint.sh))
