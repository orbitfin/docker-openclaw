# docker-openclaw

在 [`ghcr.io/openclaw/openclaw`](https://github.com/openclaw/openclaw) 的 `extended-stable-slim` / `extended-stable-browser` 两个变种基础上预装常用工具，并推送到本仓库的 GHCR。

预装工具：

- 云 / K8s：AWS CLI v2、`kubectl`（最新 stable）、`helm`、`terraform`、GitHub CLI `gh`
- Python：`uv` / `uvx`、`conda` / `mamba`（Miniforge，装在 `/opt/conda`，默认频道 conda-forge，不自动激活 base）
- 数据库客户端：`psql`（PGDG 最新版）、`redis-cli`
- 数据处理：`jq`、`yq`（mikefarah 版）、`ripgrep`、`envsubst`
- 文件 / 归档：`unzip`、`zip`、`xz`、`rsync`、`tree`、`file`
- 网络排障：`curl`、`wget`、`dig`、`ping`、`nc`
- 其他：`procps`（`ps`/`top`）、`vim-tiny`、`less`

> 基础镜像本身已带 `git`、`ssh`、`openssl`、`python3`、`node`/`npm`/`pnpm`。
> kubectl / helm / yq 每次构建取上游最新版；kubectl 与 helm 下载后会校验 sha256。

## 镜像地址

| 标签 | 上游基础镜像 | 说明 |
|---|---|---|
| `latest` / `extended-stable-slim` | `openclaw/openclaw:extended-stable-slim` | 默认，`latest` 即 slim |
| `extended-stable-browser` | `openclaw/openclaw:extended-stable-browser` | 带浏览器，体积更大 |

```
ghcr.io/orbitfin/docker-openclaw:latest
ghcr.io/orbitfin/docker-openclaw:extended-stable-slim
ghcr.io/orbitfin/docker-openclaw:extended-stable-browser
```

另有可回溯的标签：`<变种>-YYYYMMDD-HHmm`（定时构建）、`<变种>-sha-<commit>`。

本地构建指定变种：`docker build --build-arg BASE_TAG=extended-stable-browser .`

## 构建策略

GitHub Actions（见 `.github/workflows/build.yml`）：

- **定时**：北京时间每天约 08:07、17:07 自动拉取最新上游基础镜像并重新构建推送。
- **手动**：Actions 页面 `Run workflow`。
- **变更触发**：`main` 分支上 `Dockerfile` 或工作流变更时。
- 多架构：`linux/amd64`、`linux/arm64`。
- 每次构建强制 `pull` + `no-cache`，确保使用最新的上游镜像与软件包。
