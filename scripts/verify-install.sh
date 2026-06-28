#!/bin/bash
# HanaAgent 安装验证脚本
# 在 NAS 上运行: bash verify-install.sh

echo "=== HanaAgent 安装验证 ==="
echo ""

# Node.js 版本
echo -n "Node.js:    "
if command -v node &>/dev/null; then
  node --version
else
  echo "❌ 未安装"
fi

# NPM
echo -n "npm:        "
if command -v npm &>/dev/null; then
  npm --version
else
  echo "❌ 未安装"
fi

# HanaAgent 目录
echo -n "HanaAgent:  "
if [ -d "/vol1/1000/Hanako" ]; then
  echo "✅ $(ls /vol1/1000/Hanako/package.json 2>/dev/null && echo '存在' || echo '目录存在但无 package.json')"
else
  echo "❌ 目录 /vol1/1000/Hanako 不存在"
fi

# 服务端口
echo -n "端口 14500: "
if ss -tlnp | grep -q 14500; then
  PID=$(ss -tlnp | grep 14500 | grep -o 'pid=[0-9]*' | cut -d= -f2)
  echo "✅ 运行中 (PID: $PID)"
else
  echo "❌ 未监听"
fi

# systemd 服务
echo -n "systemd:    "
if systemctl is-active hanako &>/dev/null; then
  echo "✅ active"
elif systemctl is-enabled hanako &>/dev/null; then
  echo "⚠️ 已启用但未运行"
else
  echo "❌ 未安装"
fi

# 设置页
echo -n "settings:   "
if curl -sf -o /dev/null -w "%{http_code}" http://localhost:14500/desktop/settings.html | grep -q 200; then
  echo "✅"
else
  echo "❌ 可能被白名单拦截"
fi

# 模型配置
echo -n "模型配置:   "
if [ -f "/home/$USER/.hanako-dev/models.json" ]; then
  PROVIDERS=$(grep -o '"baseUrl"' /home/$USER/.hanako-dev/models.json | wc -l)
  echo "✅ 已配置 $PROVIDERS 个提供商"
else
  echo "❌ 未找到 models.json"
fi
