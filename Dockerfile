FROM ghcr.io/openclaw/openclaw:latest

# 基础镜像以非 root 的 node 用户运行，安装软件需切回 root
USER root

# 构建时 shell 开启 pipefail，避免管道中间步骤失败被吞掉
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# 常用工具（基础镜像已自带 git / curl / ssh / openssl / python3 / tar / gzip）
# - unzip 同时供 AWS CLI 安装解压用；less / groff 供 aws help 分页显示
# - procps / dnsutils / iputils-ping / netcat-openbsd：进程与网络排障
# - gettext-base 提供 envsubst，用于模板渲染
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        wget \
        gnupg \
        unzip \
        zip \
        xz-utils \
        jq \
        less \
        groff \
        rsync \
        tree \
        file \
        procps \
        dnsutils \
        iputils-ping \
        netcat-openbsd \
        gettext-base \
        ripgrep \
        vim-tiny \
        redis-tools \
    && rm -rf /var/lib/apt/lists/*

# 通过官方 apt 源安装：
# - gh：GitHub CLI
# - postgresql-client：PGDG 源的最新版 psql（新版客户端可连旧版服务端）
# - terraform：HashiCorp 源
RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    codename="$(. /etc/os-release && echo "$VERSION_CODENAME")"; \
    install -d -m 0755 /etc/apt/keyrings; \
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o /etc/apt/keyrings/githubcli.gpg; \
    curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /etc/apt/keyrings/pgdg.gpg; \
    curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /etc/apt/keyrings/hashicorp.gpg; \
    chmod go+r /etc/apt/keyrings/*.gpg; \
    echo "deb [arch=${arch} signed-by=/etc/apt/keyrings/githubcli.gpg] https://cli.github.com/packages stable main" \
        > /etc/apt/sources.list.d/github-cli.list; \
    echo "deb [arch=${arch} signed-by=/etc/apt/keyrings/pgdg.gpg] https://apt.postgresql.org/pub/repos/apt ${codename}-pgdg main" \
        > /etc/apt/sources.list.d/pgdg.list; \
    echo "deb [arch=${arch} signed-by=/etc/apt/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com ${codename} main" \
        > /etc/apt/sources.list.d/hashicorp.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends gh postgresql-client terraform; \
    rm -rf /var/lib/apt/lists/*; \
    gh --version; \
    psql --version; \
    terraform version

# 安装 uv / uvx（直接从官方镜像拷贝二进制）
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/

# 安装 Miniforge（conda-forge 社区版 conda，默认频道为 conda-forge，规避 Anaconda 商用授权问题）
# - 仅把 conda / mamba 软链到 /usr/local/bin，不覆盖系统 python3（login shell 也能找到）
# - 目录归 node 用户所有，运行时可直接 conda create / install
RUN set -eux; \
    curl -fsSL "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-$(uname -m).sh" -o /tmp/miniforge.sh; \
    bash /tmp/miniforge.sh -b -p /opt/conda; \
    rm -f /tmp/miniforge.sh; \
    /opt/conda/bin/conda config --system --set auto_activate_base false; \
    /opt/conda/bin/conda clean -afy; \
    chown -R node:node /opt/conda; \
    ln -s /opt/conda/condabin/conda /opt/conda/condabin/mamba /usr/local/bin/; \
    conda --version

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

# 安装 kubectl 最新 stable 版（按构建平台自动选择 amd64 / arm64，并校验 sha256）
RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    ver="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"; \
    curl -fsSL "https://dl.k8s.io/release/${ver}/bin/linux/${arch}/kubectl" -o /usr/local/bin/kubectl; \
    echo "$(curl -fsSL "https://dl.k8s.io/release/${ver}/bin/linux/${arch}/kubectl.sha256")  /usr/local/bin/kubectl" | sha256sum -c -; \
    chmod +x /usr/local/bin/kubectl; \
    kubectl version --client

# 安装 Helm 最新版（校验 sha256）
RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    ver="$(curl -fsSL https://get.helm.sh/helm-latest-version)"; \
    tarball="helm-${ver}-linux-${arch}.tar.gz"; \
    cd /tmp; \
    curl -fsSLO "https://get.helm.sh/${tarball}"; \
    echo "$(curl -fsSL "https://get.helm.sh/${tarball}.sha256sum" | awk '{print $1}')  ${tarball}" | sha256sum -c -; \
    tar -xzf "${tarball}" --strip-components=1 -C /usr/local/bin "linux-${arch}/helm"; \
    rm -f "${tarball}"; \
    helm version

# 安装 yq（mikefarah 版，Debian 自带的 yq 是 python 包装版，语法不同）
RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    curl -fsSL "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_${arch}" -o /usr/local/bin/yq; \
    chmod +x /usr/local/bin/yq; \
    yq --version

# 恢复为原镜像的运行用户
USER node
