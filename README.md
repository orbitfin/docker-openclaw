# docker-openclaw

在 [`ghcr.io/openclaw/openclaw:latest`](https://github.com/openclaw/openclaw) 基础上预装常用工具，并推送到本仓库的 GHCR。

预装工具：

- AWS CLI v2
- `unzip`
- `jq`
- `curl` / `ca-certificates`

## 镜像地址

```
ghcr.io/orbitfin/docker-openclaw:latest
```

## 构建策略

GitHub Actions（见 `.github/workflows/build.yml`）：

- **定时**：北京时间每天约 08:07、17:07 自动拉取最新上游基础镜像并重新构建推送。
- **手动**：Actions 页面 `Run workflow`。
- **变更触发**：`main` 分支上 `Dockerfile` 或工作流变更时。
- 多架构：`linux/amd64`、`linux/arm64`。
- 每次构建强制 `pull` + `no-cache`，确保使用最新的上游镜像与软件包。
