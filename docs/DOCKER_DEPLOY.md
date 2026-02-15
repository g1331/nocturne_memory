# Docker 一键部署与 Remote MCP 排障指南

本文档覆盖从零部署到 Claude Remote MCP 连通的完整流程，并记录了线上高频故障与修复路径。

## 1. 部署目标与端口

- Web 前端：`18080`
- Backend API：容器内 `8000`（由 Web 容器反代）
- MCP SSE：`18081`
- 数据库：SQLite，持久化到 Docker 命名卷 `dbdata`

## 2. 首次部署

```bash
git clone -b feature/docker-deploy --single-branch https://github.com/g1331/nocturne_memory.git
cd nocturne_memory
chmod +x scripts/deploy.sh
./scripts/deploy.sh
```

如果你使用 Windows PowerShell：

```powershell
git clone -b feature/docker-deploy --single-branch https://github.com/g1331/nocturne_memory.git
cd nocturne_memory
pwsh ./scripts/deploy.ps1
```

## 3. 服务器更新重建

```bash
cd ~/nocturne_memory
git fetch origin
git checkout feature/docker-deploy
git pull --ff-only origin feature/docker-deploy
docker compose up -d --build
docker compose ps
```

## 4. Remote MCP 必要环境变量

`mcp-sse` 默认启用了 Host 与 Origin 校验。公网域名接入前必须设置：

```bash
cd ~/nocturne_memory
sed -i '/^MCP_ALLOWED_HOSTS=/d;/^MCP_ALLOWED_ORIGINS=/d' .env
cat >> .env <<'EOF'
MCP_ALLOWED_HOSTS=mcp.example.com,mcp.example.com:*
MCP_ALLOWED_ORIGINS=https://mcp.example.com
EOF

docker compose up -d --build --force-recreate mcp-sse
docker compose exec mcp-sse env | grep '^MCP_ALLOWED'
```

请把示例域名 `mcp.example.com` 替换成你自己的真实域名。

## 5. 反向代理配置要点

你需要把同一个域名下的 3 条路径分别代理到不同目标：

- `/` -> `http://127.0.0.1:18080`
- `/sse` -> `http://127.0.0.1:18081/sse`
- `/sse/messages` -> `http://127.0.0.1:18081/messages`（关键）

注意：某些面板会自动拼接路径，导致 `POST /sse/messages` 落到错误后端路径并返回 `404`。如果你看到该问题，优先使用“独立规则”把 `/sse/messages` 单独指向 `/messages`。

## 6. Remote MCP 客户端配置命令

Claude：

```powershell
claude mcp remove nocturne-memory
claude mcp add --scope user --transport sse nocturne-memory https://mcp.example.com/sse
claude mcp list
```

Codex：

```powershell
codex mcp remove nocturne-memory
codex mcp add nocturne-memory --url https://mcp.example.com/sse
codex mcp list
```

## 7. 快速验证命令

服务器本机验证：

```bash
curl -i http://127.0.0.1:18080/
curl -i -N http://127.0.0.1:18081/sse
curl -i -N http://127.0.0.1:18081/sse -H "Host: mcp.example.com"
docker compose logs --tail=120 mcp-sse
```

客户端公网验证：

```powershell
curl.exe -vk -N https://mcp.example.com/sse
```

## 8. 故障与修复对照表

| 现象 | 根因 | 处理方式 |
|------|------|----------|
| `claude mcp list` 失败，SSE 地址写成 `/see` | 路径拼写错误 | 改为 `/sse` |
| `curl` 报 `SEC_E_ILLEGAL_MESSAGE` | TLS 握手失败（证书或 Cloudflare 边缘配置） | 检查 Cloudflare 证书状态、SSL 模式与域名覆盖 |
| `GET /sse` 返回 `421 Misdirected Request` | Host 不在 FastMCP 允许列表 | 正确设置 `.env` 的 `MCP_ALLOWED_HOSTS` 并重建 `mcp-sse` |
| `POST /sse/messages?...` 返回 `404` | 反代没有把 `/sse/messages` 正确转到后端 `/messages` | 单独配置 `/sse/messages` 反代规则 |

## 9. 生产建议

- 优先使用一级子域名，避免证书覆盖复杂度上升。
- 保持 `MCP_ALLOWED_HOSTS` 与 `MCP_ALLOWED_ORIGINS` 最小化，不要放宽到任意来源。
- 每次改反代规则后都执行一次 `claude mcp list` 与 `docker compose logs --tail=120 mcp-sse` 联合验证。
