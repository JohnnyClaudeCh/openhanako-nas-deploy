# FAQ - 常见问题

## 服务相关

### Q: 启动后 `curl /api/health` 返回 403？

正常。403 表示服务在运行，只是未认证：

```json
{"error":"forbidden","reason":"missing_credential","connectionKind":"lan"}
```

### Q: 怎么获取设备凭据？

首次在 Web UI 登录时会自动生成设备凭据，保存在 `~/.hanako-dev/device-credentials.json` 和 `~/.hanako-dev/devices.json` 中。

### Q: 密码忘了怎么办？

停止服务，删除 `~/.hanako-dev/local-user-auth.json`，重启服务后重新注册。

```bash
sudo systemctl stop hanako
rm /home/$USER/.hanako-dev/local-user-auth.json
sudo systemctl start hanako
# 然后浏览器重新打开 Web UI 注册
```

## 模型相关

### Q: DeepSeek API Key 在哪里设置？

方案一（推荐）：在 Web UI 中 Settings → API Keys → 添加 `deepseek` 密钥。

方案二（API 方式）：
```bash
curl -X POST http://localhost:14500/api/secrets/set \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer 你的设备凭据" \
  -d '{"key":"deepseek","value":"sk-你的真实Key"}'
```

### Q: Ollama 不响应？

1. 确认 GPU 机器上 Ollama 正在运行：`systemctl status ollama`
2. 确认监听了 `0.0.0.0`：`ss -tlnp | grep 11434`
3. 确认防火墙没拦截：`sudo ufw status`
4. 在 NAS 上测试：`curl http://OLLAMA_IP:11434/api/tags`
5. 如果使用 Windows，检查 Windows 防火墙是否放行 11434 端口

### Q: 如何测试模型是否可用？

```bash
# 测试 DeepSeek
curl -X POST http://localhost:14500/api/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_DEVICE_CREDENTIAL" \
  -d '{"model":"deepseek-chat","messages":[{"role":"user","content":"hello"}]}'

# 测试 Ollama（直接从 NAS 发到 GPU 机器）
curl http://OLLAMA_IP:11434/api/generate -d '{"model":"MODEL_ID","prompt":"hello"}'
```

## 网络相关

### Q: 外网访问很慢？

1. 检查上传带宽：speedtest-cli
2. 考虑使用 Cloudflare Tunnel 代理
3. 如果模型是本地 Ollama，外网只需传输文本消息，带宽要求不高
4. 如果是 DeepSeek 云端 API，消息直接从客户端发到 DeepSeek，NAS 只做桥接

### Q: Cloudflare Tunnel 怎么配？

```bash
# 在 NAS 上
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o /usr/local/bin/cloudflared
chmod +x /usr/local/bin/cloudflared

# 登录
cloudflared tunnel login

# 创建隧道
cloudflared tunnel create hanaagent

# 配置 DNS
cloudflared tunnel route dns hanaagent your-domain.com

# 创建配置
cat > ~/.cloudflared/config.yml << EOF
tunnel: <TUNNEL_ID>
credentials-file: /home/$USER/.cloudflared/<TUNNEL_ID>.json
ingress:
  - hostname: your-domain.com
    service: http://localhost:14500
  - service: http_status:404
EOF

# 安装为系统服务
cloudflared service install
```

### Q: HTTPS 怎么搞？

推荐方案（不需要 80 端口）：

```bash
# acme.sh + 阿里云 DNS
curl https://get.acme.sh | sh
~/.acme.sh/acme.sh --issue --dns dns_ali -d your-domain.com
~/.acme.sh/acme.sh --install-cert -d your-domain.com \
  --key-file /etc/ssl/private/domain.key \
  --fullchain-file /etc/ssl/certs/domain.crt

# 然后用 Nginx 反代
```

## 维护相关

### Q: 更新 HanaAgent 后设置页 404 了？

更新会覆盖 `mobile-static.ts`，需要重新运行：

```bash
node /path/to/patch_static.js
sudo systemctl restart hanako
```

### Q: 如何完全卸载？

```bash
sudo systemctl stop hanako
sudo systemctl disable hanako
sudo rm /etc/systemd/system/hanako.service
sudo systemctl daemon-reload
rm -rf /vol1/1000/Hanako          # 删除代码
rm -rf /home/$USER/.hanako-dev     # 删除配置
```

### Q: 日志在哪里？

- systemd 日志：`sudo journalctl -u hanako -n 100 -f`
- 应用日志（如果重定向）：`/tmp/hanako.log`
- HanaAgent 自己的日志配置目录：`~/.hanako-dev/logs/`
