FROM debian:bookworm-slim

ARG TARGETARCH

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl unzip supervisor tini \
  && rm -rf /var/lib/apt/lists/*

# 目录
RUN mkdir -p /etc/akbox /var/log/akbox
WORKDIR /etc/akbox

# 下载 xray（zip）与 cloudflared 与 komari-agent（二进制）
# Xray 官方说明：Linux 预编译包在 GitHub Releases（zip）[7](https://xtls.github.io/document/install.html)
RUN set -eux; \
  if [ "${TARGETARCH}" = "amd64" ]; then \
    XRAY_ZIP="Xray-linux-64.zip"; \
    CLOUDFLARED_BIN="cloudflared-linux-amd64"; \
    KOMARI_BIN="komari-agent-linux-amd64"; \
  else \
    XRAY_ZIP="Xray-linux-arm64-v8a.zip"; \
    CLOUDFLARED_BIN="cloudflared-linux-arm64"; \
    KOMARI_BIN="komari-agent-linux-arm64"; \
  fi; \
  curl -fsSL "https://github.com/XTLS/Xray-core/releases/latest/download/${XRAY_ZIP}" -o /tmp/xray.zip; \
  unzip -o /tmp/xray.zip -d /tmp/xray >/dev/null; \
  install -m 0755 /tmp/xray/xray /usr/local/bin/xray; \
  curl -fsSL "https://github.com/cloudflare/cloudflared/releases/latest/download/${CLOUDFLARED_BIN}" -o /usr/local/bin/cloudflared; \
  chmod +x /usr/local/bin/cloudflared; \
  curl -fsSL "https://github.com/komari-monitor/komari-agent/releases/latest/download/${KOMARI_BIN}" -o /usr/local/bin/komari-agent; \
  chmod +x /usr/local/bin/komari-agent; \
  rm -rf /tmp/xray /tmp/xray.zip

# 拷贝启动文件
COPY docker/entrypoint.sh /entrypoint.sh
COPY docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY docker/run-komari.sh /usr/local/bin/run-komari.sh

RUN chmod +x /entrypoint.sh /usr/local/bin/run-komari.sh

# 创建非 root 用户（更通用）
RUN useradd -m -u 1000 app
USER app

ENV ARGO_DOMAIN=""
ENV ARGO_TOKEN=""
ENV UUID=""
ENV ARGO_PORT="8080"
ENV KOMARI_URL=""
ENV KOMARI_TOKEN=""

ENTRYPOINT ["/usr/bin/tini","--","/entrypoint.sh"]
