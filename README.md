# Hanako-NAS-Deploy

在 Linux NAS（或服务器）上从零搭建 HanaAgent Server 的一站式方案。
包括：Node.js 环境安装、HanaAgent 构建部署、模型提供商配置（DeepSeek / Ollama）、用户认证、防火墙放行、外网访问、systemd 自启。

> **HanaAgent**: [liliMozi/openhanako](https://github.com/liliMozi/openhanako) — 开源桌面 AI 助手
>
> **配套仓库**: 如果需要在桌面客户端侧补丁（连接 NAS、CSP 放行），看 `Hanako-NAS-Connect`。

---

## 目录

- [拓扑架构](#拓扑架构)
- [部署前准备](#部署前准备)
- [部署步骤](#部署步骤)
  - [① NAS 基础环境安装](#①-nas-基础环境安装)
  - [② 配置 SSH（可选但推荐）](#②-配置-ssh可选但推荐)
  - [③ 部署 HanaAgent Server](#③-部署-hanaagent-server)
  - [④ 配置模型提供商](#④-配置模型提供商)
  - [⑤ 创建用户和凭据](#⑤-创建用户和凭据)
  - [⑥ 防火墙与外网访问](#⑥-防火墙与外网访问)
  - [⑦ 设置 systemd 自启](#⑦-设置-systemd-自启)
  - [⑧ 验证全部功能](#⑧-验证全部功能)
- [配置模板说明](#配置模板说明)
- [日常运维](#日常运维)
- [常见问题](#常见问题)
- [附录：文件说明](#附录文件说明)

---

## 拓扑架构

```
                        ┌───────────────────────────┐
                        │     NAS (Linux)            │
                        │   HanaAgent Server         │
                        │   端口 14500               │
                        │   Node.js 运行时           │
                        └──────┬────────────────────┘
                               │
              ┌────────────────┼──────────────────┐
              │                │                   │
              ▼                ▼                   ▼
     ┌──────────────┐  ┌───────────┐  ┌─────────────────┐
     │ Windows 桌面  │  │ 任意浏览器 │  │ 游戏本 (可选)   │
     │ 桌面客户端    │  │ Web UI    │  │ Ollama 本地模型 │
     └──────────────┘  └───────────┘  │ 端口 11434      │
                                       └─────────────────┘
```

### 模型架构

```
┌──────────────────────────────────────────────────┐
│                   HanaAgent Server                │
│                                                    │
│  模型路由:                                          │
│    chat       → 云端 API（如 DeepSeek / OpenAI）       │
│    utility    → 云端 API（同上）       │
│    utility_large → 云端 API（同上）    │
│    或                                             │
│    chat       → Ollama (本地 GPU 机器)             │
└──────────────────────────────────────────────────┘
```

---

## 部署前准备

### 你需要准备的

| 项目 | 说明 | 是否必须 | 示例 |
|------|------|---------|------|
| Linux 服务器/NAS | 运行 HanaAgent Server | 必须 | Debian 12 / Ubuntu / fnOS |
| Node.js >= 18 | HanaAgent 运行环境 | 必须 | v18 / v20 / v22 |
| git | 克隆 HanaAgent 代码 | 推荐 | |
| SSH 客户端 | 远程登录管理 | 推荐 | Windows 自带 OpenSSH |
| 云端 API Key | OpenAI 兼容 API（可选） | 可选 | sk-xxxxxxxxxxxxxxxxxxxx |
| Ollama 服务器 | 本地模型（可选） | 可选 | 另一台有 GPU 的机器 |

### 你需要填写的信息

部署过程中需要以下信息，提前准备好：

```
NAS_IP=YOUR_NAS_IP                 # 如 192.168.1.100
NAS_SSH_PORT=22                    # NAS 的 SSH 端口
NAS_USER=YOUR_NAS_USERNAME         # NAS 用户名
HANAKO_DIR=/vol1/1000/Hanako       # HanaAgent 安装路径
CLOUD_API_KEY=sk-xxxxxxxxxxxx   # 如 DeepSeek / OpenAI / 其他兼容 API
OLLAMA_URL=http://192.168.1.200:11434/v1  # 如用本地 Ollama
```

---

## 部署步骤

### ① NAS 基础环境安装

登录 NAS：

```bash
ssh -p YOUR_SSH_PORT YOUR_USERNAME@YOUR_NAS_IP
```

#### 安装 Node.js

```bash
# Debian/Ubuntu
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt-get install -y nodejs

# 验证
node --version
npm --version
```

#### 安装 git（如未安装）

```bash
sudo apt-get install -y git
```

---

### ② 配置 SSH（可选但推荐）

在 Windows 电脑上生成 SSH 密钥（如果已经有密钥可以跳过）：

```powershell
ssh-keygen -t ed25519 -f "%USERPROFILE%\.ssh\nas_key"
```

复制公钥到 NAS：

```powershell
type "%USERPROFILE%\.ssh\nas_key.pub" | ssh -p YOUR_SSH_PORT YOUR_USERNAME@YOUR_NAS_IP "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
```

验证免密登录：

```powershell
ssh -p YOUR_SSH_PORT -i "%USERPROFILE%\.ssh\nas_key" YOUR_USERNAME@YOUR_NAS_IP "echo OK"
```

---

### ③ 部署 HanaAgent Server

```bash
# 克隆 HanaAgent 代码（替换为你的仓库地址）
git clone <YOUR_HANAAGENT_REPO_URL> /vol1/1000/Hanako
cd /vol1/1000/Hanako

# 安装依赖
npm install

# 构建前端
npm run build
```

首次启动测试：

```bash
npm run server
```

在新终端窗口测试：

```bash
curl http://localhost:14500/api/health
# 应返回 403（说明服务运行中，只是未认证）
cur http://localhost:14500/desktop/
# 应返回 HTML（Web UI）
```

按 Ctrl+C 停止测试服务。

---

### ④ 配置模型提供商

HanaAgent 需要配置至少一个模型才能使用。有两种选择：

#### 方案 A：云端 API（推荐，开箱即用）

任意 OpenAI 兼容 API 都可以。下面以 DeepSeek 为例，你也可以换成 OpenAI、
Azure OpenAI、Google Gemini（通过 API 网关）等，只需修改 `baseUrl` 即可。

创建/编辑 `~/.hanako-dev/models.json`，填入 API Key：

```json
{
  "providers": {
    "deepseek": {
      "baseUrl": "https://api.deepseek.com",
      "api": "openai-completions",
      "apiKey": "hana-runtime-api-key:deepseek",
      "models": [
        {
          "id": "deepseek-chat",
          "name": "DeepSeek Chat",
          "input": ["text"],
          "contextWindow": 128000,
          "reasoning": true
        }
      ]
    }
  }
}
```

在 Web 界面（Settings -> API Keys）设置对应的真实 API Key，或用 API 设置（以 DeepSeek 为例）：

```bash
curl -X POST http://localhost:14500/api/secrets/set \
  -H "Content-Type: application/json" \
  -d '{"key":"deepseek","value":"sk-你的真实APIKey"}'
```

#### 方案 B：Ollama 本地模型（需要另一台有 GPU 的机器）

在 GPU 机器上安装 Ollama：

```bash
curl -fsSL https://ollama.com/install.sh | sh

# 允许局域网访问
sudo systemctl edit ollama
# 加入: Environment="OLLAMA_HOST=0.0.0.0:11434"

# 下载模型
ollama pull <你的模型ID>   # 改成你要用的模型
```

在 HanaAgent 配置中添加 Ollama 提供商（编辑 `~/.hanako-dev/models.json`）：

```json
{
  "providers": {
    "deepseek": { ... },
    "ollama-local": {
      "baseUrl": "http://YOUR_GPU_MACHINE_IP:11434/v1",
      "api": "ollama",
      "apiKey": "hana-runtime-api-key:ollama-local",
      "models": [
        {
          "id": "<你的模型ID>",
          "name": "<你的模型显示名称>",
          "input": ["text"],
          "contextWindow": 128000,
          "reasoning": false
        }
      ]
    }
  }
}
```

#### 配置 Agent 默认模型

编辑 `~/.hanako-dev/agents/hanako/config.yaml`：

```yaml
models:
  chat:
    id: deepseek-chat
    provider: deepseek
  utility:
    id: deepseek-chat
    provider: deepseek
  utility_large:
    id: deepseek-chat
    provider: deepseek
```

---

### ⑤ 创建用户和凭据

首次启动 HanaAgent Server 后，打开浏览器访问 Web UI 会自动引导创建管理员账号。

也可以通过 API 创建：

```bash
# 注册用户
curl -X POST http://localhost:14500/api/web-auth/register \
  -H "Content-Type: application/json" \
  -d '{"username":"你的用户名","password":"你的密码"}'
```

成功后浏览器打开 `http://YOUR_NAS_IP:14500/desktop/settings.html` 可查看/复制设备凭据。

---

### ⑥ 防火墙与外网访问

#### NAS 防火墙放行 14500 端口

```bash
# ufw（Debian/Ubuntu）
sudo ufw allow 14500/tcp comment 'HanaAgent Server'

# firewalld
sudo firewall-cmd --permanent --add-port=14500/tcp
sudo firewall-cmd --reload

# iptables
sudo iptables -A INPUT -p tcp --dport 14500 -j ACCEPT
```

#### 路由器端口转发

在路由器管理界面设置端口转发：

| 项目 | 值 |
|------|-----|
| 外部端口 | 14500 |
| 内部 IP | 你的 NAS 地址 |
| 内部端口 | 14500 |
| 协议 | TCP |

设置后即可从外网通过 `http://你的域名:14500/desktop/` 访问。

#### DNS / DDNS（如需固定域名）

如果有公网 IP，可以使用 DDNS 绑定域名。可选方案：

- **DDNS-GO**：免费开源，支持阿里云/腾讯云/DNSPod 等
- **Cloudflare Tunnel**：无需公网 IP，自动处理 HTTPS
- **路由器自带 DDNS**：很多路由器支持内置 DDNS

---

### ⑦ 设置 systemd 自启

创建服务文件：

```bash
sudo tee /etc/systemd/system/hanako.service << 'EOF'
[Unit]
Description=HanaAgent Server
After=network.target

[Service]
Type=simple
User=YOUR_NAS_USERNAME
WorkingDirectory=/vol1/1000/Hanako
ExecStart=/usr/bin/npm run server
Restart=always
RestartSec=10
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF
```

启用并启动：

```bash
sudo systemctl daemon-reload
sudo systemctl enable hanako
sudo systemctl start hanako
```

验证：

```bash
sudo systemctl status hanako
# 应显示 active (running)
```

---

### ⑧ 验证全部功能

| 验证项 | 操作 | 预期结果 |
|--------|------|---------|
| 服务运行 | `sudo systemctl status hanako` | active (running) |
| Web UI | 浏览器打开 `http://NAS_IP:14500/desktop/` | HanaAgent 界面 |
| 设置页 | 浏览器打开 `http://NAS_IP:14500/desktop/settings.html` | 设置页面 |
| API 连通 | `curl http://NAS_IP:14500/api/health` | 403（需要凭据） |
| 模型可用 | 在 Web UI 中发送一条消息 | 有 AI 回复 |
| 外网访问 | 从外网浏览器打开 `http://域名:14500/desktop/` | HanaAgent 界面 |
| 自启恢复 | `sudo systemctl restart hanako` | 自动重启正常 |

---

## 配置模板说明

本仓库的 `config/` 目录包含可编辑的配置模板，所有需填写的字段都标注了 `<YOUR_xxx>`。

| 模板文件 | 部署路径 | 说明 |
|----------|---------|------|
| `config/server-network.json` | `~/.hanako-dev/server-network.json` | 网络模式、端口（开箱即用） |
| `config/models.json.template` | `~/.hanako-dev/models.json` | 模型提供商配置 |
| `config/config.yaml.template` | `~/.hanako-dev/agents/hanako/config.yaml` | Agent 默认模型、记忆参数 |

---

## 日常运维

### 查看日志

```bash
sudo journalctl -u hanako -n 50 -f   # systemd 日志
tail -f /tmp/hanako.log              # 应用日志
```

### 重启服务

```bash
sudo systemctl restart hanako
```

### 更新 HanaAgent

```bash
cd /vol1/1000/Hanako
git pull
npm install
npm run build
sudo systemctl restart hanako
```

> 更新后可能覆盖 `mobile-static.ts` 中的白名单补丁。
> 如果设置页 404，从 `Hanako-NAS-Connect` 仓库拿 `nas/patch_static.js` 重新执行一次。

---

## 常见问题

### Q: 服务启动后 `curl /api/health` 返回 403 是正常的吗？

正常。403 表示服务正在运行但需要身份认证。

### Q: 设置页 404？

HanaAgent 默认白名单未包含 `settings.html`。需要运行 `patch_static.js` 补丁。
详见 `Hanako-NAS-Connect` 中的 `nas/patch_static.js`。

### Q: 桌面客户端连不上 NAS 报 `Failed to fetch`？

Electron 渲染进程的 CSP 安全策略限制。需要修改 `app.asar` 中的 `connection-csp.js`。
详见 `Hanako-NAS-Connect` 中的 `windows/patch_asar_final.py`。

### Q: 外网访问需要 HTTPS 吗？

建议加 HTTPS，但不是必须。如果不加，凭据以明文传输。
推荐方案（无需 80 端口）：
1. **acme.sh + 阿里云 DNS**：DNS-01 验证签发 Let's Encrypt 证书
2. **Cloudflare Tunnel**：自动处理 HTTPS
3. **Nginx 反代 + 免费 SSL 证书**

### Q: Ollama 远程连接报错？

确保 GPU 机器上的 Ollama 监听 `0.0.0.0:11434`，且防火墙已放行：

```bash
ss -tlnp | grep 11434
# 应显示 0.0.0.0:11434
```

### Q: 密码忘了怎么办？

停止服务，删除 `~/.hanako-dev/local-user-auth.json`，重启后重新注册。

```bash
sudo systemctl stop hanako
rm ~/.hanako-dev/local-user-auth.json
sudo systemctl start hanako
```

### Q: 如何完全卸载？

```bash
sudo systemctl stop hanako
sudo systemctl disable hanako
sudo rm /etc/systemd/system/hanako.service
sudo systemctl daemon-reload
rm -rf /vol1/1000/Hanako
rm -rf ~/.hanako-dev
```

---

## 附录：文件说明

### `config/server-network.json`

控制 HanaAgent Server 的网络模式。

| 字段 | 说明 | 示例值 |
|------|------|--------|
| `mode` | `lan`（局域网）或 `remote`（远程） | `"lan"` |
| `listenHost` | 监听地址 | `"0.0.0.0"`（所有网卡） |
| `listenPort` | 服务端口 | `14500` |

### `config/models.json.template`

配置所有可用模型提供商。将 `.template` 后缀去掉后放到 `~/.hanako-dev/models.json`。

### `config/config.yaml.template`

Agent 运行配置。将 `.template` 后缀去掉后放到 `~/.hanako-dev/agents/hanako/config.yaml`。

### `scripts/setup.sh`

NAS 端一键部署脚本。在 NAS 上编辑脚本顶部的配置变量后运行：

```bash
bash scripts/setup.sh
```

### `scripts/verify-install.sh`

安装验证脚本：

```bash
bash scripts/verify-install.sh
```

---

## 安全提醒

- 不要将 SSH 密钥、密码、API Key 提交到 Git
- 首次部署后务必在 Web 界面修改默认密码
- 外网访问建议加 HTTPS，避免明文传输凭据
