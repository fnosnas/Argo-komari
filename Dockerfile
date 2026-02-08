FROM ubuntu:latest

# 安装必要组件
RUN apt-get update && apt-get install -y curl wget unzip ca-certificates

# 设置工作目录
WORKDIR /app

# 复制启动脚本
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# 暴露端口
EXPOSE 8080

# 启动命令
CMD ["/bin/bash", "/app/entrypoint.sh"]
