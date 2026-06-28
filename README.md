# openhanako-nas-deploy

在 Linux NAS（或服务器）上从零搭建 HanaAgent Server 的一站式方案。
包括：Node.js 环境安装、HanaAgent 构建部署、模型提供商配置（DeepSeek / Ollama）、用户认证、防火墙放行、外网访问、systemd 自启。

> **HanaAgent**: [liliMozi/openhanako](https://github.com/liliMozi/openhanako) — 开源桌面 AI 助手
>
> **配套仓库**: 如果需要在桌面客户端侧补丁（连接 NAS、CSP 放行），看 [`openhanako-nas-connect`](https://github.com/JohnnyClaudeCh/openhanako-nas-connect)。

---

## 前置要求

| 环境 | 说明 | 是否必须 | 备注 |
|------|------|---------|------|
| Linux 服务器/NAS | 运行 HanaAgent Server | 必须 | Debian 12 / Ubuntu / fnOS |
| Node.js >= 18 | HanaAgent 运行环境 | 必须 | v18 / v20 / v22 |
| git | 克隆 HanaAgent 代码 | 推荐 | |
| 域名（可选） | 外网访问 | 可选 | 阿里云 DDNS |

---

## 快速部署

```bash
# 1. 克隆仓库
git clone https://github.com/JohnnyClaudeCh/openhanako-nas-deploy.git
cd openhanako-nas-deploy

# 2. 编辑配置
cp config/models.json.template ~/.hanako-dev/models.json
cp config/config.yaml.template ~/.hanako-dev/agents/hanako/config.yaml

# 3. 运行一键部署脚本
bash scripts/setup.sh
```

---

## 手动部署步骤

### Step 1：环境准备

```bash
# Debian / Ubuntu
sudo apt update
sudo apt install -y curl git nodejs npm

# 验证
node --version   # >= 18
npm --version
```

### Step 2：部署 HanaAgent Server

```bash
# 克隆 HanaAgent 代码（替换为你的仓库地址）
git clone https://github.com/liliMozi/openhanako.git /vol1/1000/Hanako
cd /vol1/1000/Hanako

# 安装依赖并构建
npm install
npm run build:client

# 首次启动测试
npm run server
```

访问 `http://你的NAS地址:14500/desktop/`，应看到 HanaAgent 界面。按 Ctrl+C 停止临时服务。

### Step 3：配置模型

HanaAgent 需要配置至少一个模型才能使用。有两种选择：

#### 方式 A：DeepSeek API（推荐，零硬件成本）

创建/编辑 `~/.hanako-dev/models.json`，填入 API Key：

```json
{
    "providers": {
        "deepseek": {
            "baseUrl": "https://api.deepseek.com",
            "api": "openai",
            "apiKey": "sk-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
            "models": [
                {
                    "id": "deepseek-chat",
                    "name": "DeepSeek V3",
                    "input": ["text"],
                    "output": ["text"]
                }
            ]
        }
    }
}
```

#### 方式 B：本地 Ollama

如果你有另一台带 GPU 的机器跑 Ollama，在 HanaAgent 配置中添加 Ollama 提供者：

```json
{
    "providers": {
        "ollama": {
            "baseUrl": "http://你的GPU机器IP:11434/v1",
            "api": "ollama",
            "apiKey": "ollama",
            "models": [
                {
                    "id": "qwen2.5:7b",
                    "name": "Qwen2.5 7B",
                    "input": ["text"],
                    "output": ["text"]
                }
            ]
        }
    }
}
```

### Step 4：配置 Agent

编辑 `~/.hanako-dev/agents/hanako/config.yaml`：

```yaml
name: my-agent
version: "1.0"
system_prompt: "你是一个有用的 AI 助手"
models:
  chat: deepseek-chat
  utility: deepseek-chat
  utility_large: deepseek-chat
```

### Step 5：配置网络

编辑 `~/.hanako-dev/server-network.json`：

```json
{
  "mode": "lan",
  "listenHost": "0.0.0.0",
  "listenPort": 14500
}
```

### Step 6：启动服务

```bash
# 前台运行（测试用）
cd /vol1/1000/Hanako && npm run server

# 或使用 systemd 自启
sudo cp scripts/hanako.service /etc/systemd/system/
sudo systemctl enable hanako
sudo systemctl start hanako
sudo systemctl status hanako
```

### Step 7：防火墙与端口转发

```bash
# firewall-cmd（CentOS/RHEL）
sudo firewall-cmd --add-port=14500/tcp --permanent
sudo firewall-cmd --reload

# ufw（Debian/Ubuntu）
sudo ufw allow 14500/tcp comment 'HanaAgent Server'
```

如果需要外网访问，在路由器上添加端口转发：外部端口 14500 → 内部 IP:14500。

### Step 8：创建管理员账号

首次启动 HanaAgent Server 后，打开浏览器访问 Web UI 会自动引导创建管理员账号。

---

## 验证

| 检查项 | 方法 | 预期结果 |
|--------|------|---------|
| 服务运行 | `sudo systemctl status hanako` | active (running) |
| Web UI | 浏览器打开 `http://NAS_IP:14500/desktop/` | HanaAgent 界面 |
| 外网访问 | 从外网浏览器打开 `http://域名:14500/desktop/` | HanaAgent 界面 |
| 自启恢复 | `sudo systemctl restart hanako` | 自动重启正常 |

---

## 配置参考

| 本地路径 | NAS 路径 | 说明 |
|---------|---------|------|
| `config/server-network.json` | `~/.hanako-dev/server-network.json` | 网络模式、端口 |
| `config/models.json.template` | `~/.hanako-dev/models.json` | 模型提供商配置 |
| `config/config.yaml.template` | `~/.hanako-dev/agents/hanako/config.yaml` | Agent 运行配置 |

---

## 日志与调试

```bash
sudo journalctl -u hanako -n 50 -f   # systemd 日志
tail -f /tmp/hanako.log              # 应用日志
tail -f ~/.hanako-dev/logs/*.log     # HanaAgent 自身日志
sudo systemctl restart hanako        # 重启
```

---

## 更新 HanaAgent

```bash
cd /vol1/1000/Hanako
git pull
npm install
npm run build:client
sudo systemctl restart hanako
```

> 更新后可能覆盖 `mobile-static.ts` 中的白名单补丁。
> 如果设置页 404，从 `openhanako-nas-connect` 重新运行 `patch_static.js`。

---

## 常见问题

### Q: 设置页 404

HanaAgent 默认白名单未包含 `settings.html`。需要运行 `patch_static.js` 补丁。
详见 `openhanako-nas-connect` 的 CSP 补丁部分。

### Q: 桌面客户端连接远程 NAS 失败

Electron 渲染进程的 CSP 安全策略限制。需要修改 `app.asar` 中的 `connection-csp.js`。
详见 `openhanako-nas-connect` 的使用说明。

### Q: 忘记 Web UI 登录密码

停止服务，删除 `~/.hanako-dev/local-user-auth.json`，重启后重新注册。

### Q: 完全卸载

```bash
sudo systemctl stop hanako
sudo systemctl disable hanako
sudo rm /etc/systemd/system/hanako.service
rm -rf /vol1/1000/Hanako          # 删除代码
rm -rf ~/.hanako-dev              # 删除配置
```
