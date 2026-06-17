FROM ghcr.io/openclaw/openclaw:latest

# 基础镜像以非 root 的 node 用户运行，安装软件需切回 root
USER root

# 常用工具：unzip / jq / curl（unzip 同时供 AWS CLI 安装解压用）
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        unzip \
        jq \
        curl \
        ca-certificates \
        less \
        groff \
    && rm -rf /var/lib/apt/lists/*

# 安装 AWS CLI v2（按构建平台自动选择 x86_64 / aarch64）
RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    case "$arch" in \
        amd64) awscli_arch="x86_64" ;; \
        arm64) awscli_arch="aarch64" ;; \
        *) echo "unsupported arch: $arch" >&2; exit 1 ;; \
    esac; \
    curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-${awscli_arch}.zip" -o /tmp/awscliv2.zip; \
    unzip -q /tmp/awscliv2.zip -d /tmp; \
    /tmp/aws/install; \
    rm -rf /tmp/awscliv2.zip /tmp/aws; \
    aws --version

# 恢复为原镜像的运行用户
USER node
