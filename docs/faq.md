# 常见问题

## 安装与配置

### Q: 需要什么配置的 NAS？

最低：双核 CPU + 2GB 内存 + 10GB 磁盘。HanaAgent Server 本身不跑模型，主要消耗是 Node.js 运行时。

### Q: 为什么不直接在 NAS 上跑 Ollama？

NAS 通常是 ARM 或低功耗 x86，没有 GPU，跑本地模型速度很慢。推荐用另一台带 GPU 的机器跑 Ollama，NAS 通过 LAN 调用。

### Q: 支持哪些模型提供商？

- DeepSeek API（云端，推荐）
- Ollama（局域网 GPU 机器）
- 任何兼容 OpenAI API 格式的服务

### Q: 外网访问安全吗？

默认只有设备凭证认证（token-based）。建议加 HTTPS，方案参考：
- acme.sh + 阿里云 DNS API（DNS-01 验证）
- Cloudflare Tunnel（免费）
- Caddy + 反向代理

## 维护

### Q: 更新 HanaAgent 后设置页 404 了？

`mobile-static.ts` 的白名单补丁被覆盖了。从 `openhanako-nas-connect` 重新运行 `patch_static.js`。

### Q: 更新桌面客户端后连不上 NAS？

`connection-csp.js` 的补丁被 app.asar 覆盖了。重新运行 `patch_asar_final.py`。

### Q: 怎么看日志？

- systemd 日志：`sudo journalctl -u hanako -n 100 -f`
- 应用日志（如果重定向）：`/tmp/hanako.log`
- HanaAgent 自己的日志配置目录：`~/.hanako-dev/logs/`

### Q: Cloudflare Tunnel 怎么配？

```bash
cloudflared tunnel create hanaagent
cloudflared tunnel route dns hanaagent your-domain.com
cloudflared tunnel run hanaagent
```

## 卸载

### Q: 完全卸载 HanaAgent

```bash
sudo systemctl stop hanako
sudo systemctl disable hanako
sudo rm /etc/systemd/system/hanako.service
rm -rf /vol1/1000/Hanako
rm -rf /home/$USER/.hanako-dev
```
