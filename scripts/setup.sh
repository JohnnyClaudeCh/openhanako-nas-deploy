# HanaAgent NAS 一键部署脚本
# 用法: bash setup.sh
# 需要先填写下面的配置变量

# ==============================================================
# ★ 编辑下面的配置值 ★
# ==============================================================

# --- NAS 基础信息 ---
NODE_VERSION="22"              # Node.js 主版本号
HANAKO_DIR="/vol1/1000/Hanako" # HanaAgent 安装路径
HANA_USER="$USER"              # 运行服务的用户名

# --- 模型配置 ---
# DeepSeek（可选，留空跳过）
DEEPSEEK_API_KEY=""

# Ollama（可选，留空跳过）
OLLAMA_URL=""
OLLAMA_MODEL_ID=""
OLLAMA_MODEL_NAME=""

# --- HanaAgent 仓库 ---
REPO_URL=""                     # 你的 HanaAgent Git 仓库地址（双击引号内粘贴）
                                # 或留空后手动上传代码

# ==============================================================
# 以下脚本内容不需要修改
# ==============================================================

set -e

echo "=== HanaAgent NAS 部署脚本 ==="

# 检查 Node.js
if ! command -v node &>/dev/null; then
  echo "[1/6] 安装 Node.js $NODE_VERSION ..."
  curl -fsSL "https://deb.nodesource.com/setup_${NODE_VERSION}.x" | sudo -E bash -
  sudo apt-get install -y nodejs
else
  echo "[1/6] Node.js $(node --version) (已安装)"
fi

# 克隆或部署 HanaAgent
if [ ! -d "$HANAKO_DIR" ]; then
  echo "[2/6] 克隆 HanaAgent ..."
  if [ -n "$REPO_URL" ]; then
    git clone "$REPO_URL" "$HANAKO_DIR"
  else
    echo "  ⚠️ 未设置 REPO_URL，请手动将 HanaAgent 代码复制到 $HANAKO_DIR"
    echo "  然后重新运行此脚本"
    exit 1
  fi
else
  echo "[2/6] HanaAgent 已存在: $HANAKO_DIR"
fi

# 安装依赖
echo "[3/6] 安装依赖 ..."
cd "$HANAKO_DIR"
npm install
npm run build
echo "  ✅ 构建完成"

# 创建配置目录
CONFIG_DIR="/home/$HANA_USER/.hanako-dev"
echo "[4/6] 配置目录: $CONFIG_DIR"
mkdir -p "$CONFIG_DIR/agents/$HANA_USER"

# 创建网络配置（如果不存在）
if [ ! -f "$CONFIG_DIR/server-network.json" ]; then
  cat > "$CONFIG_DIR/server-network.json" << 'NETCONF'
{
  "schemaVersion": 1,
  "mode": "lan",
  "listenHost": "0.0.0.0",
  "listenPort": 14500,
  "customRemote": { "enabled": false, "baseUrl": null, "wsUrl": null },
  "createdAt": "2026-01-01T00:00:00.000Z",
  "updatedAt": "2026-01-01T00:00:00.000Z"
}
NETCONF
  echo "  ✅ 网络配置已创建"
fi

# 创建模型配置
MODEL_FILE="$CONFIG_DIR/models.json"
if [ ! -f "$MODEL_FILE" ]; then
  echo "[5/6] 创建模型配置 ..."
  # DeepSeek
  if [ -n "$DEEPSEEK_API_KEY" ]; then
    printf '  {"providers":{"deepseek":{"baseUrl":"https://api.deepseek.com","api":"openai-completions","apiKey":"hana-runtime-api-key:deepseek","models":[{"id":"deepseek-chat","name":"DeepSeek Chat","input":["text"],"contextWindow":128000,"reasoning":true}]}}' > "$MODEL_FILE"
    # 在后面追加 Ollama（如果配置）
    if [ -n "$OLLAMA_URL" ] && [ -n "$OLLAMA_MODEL_ID" ]; then
      printf ',"ollama-local":{"baseUrl":"%s","api":"ollama","apiKey":"hana-runtime-api-key:ollama-local","models":[{"id":"%s","name":"%s","input":["text"],"contextWindow":128000,"reasoning":false}]}}' "$OLLAMA_URL" "$OLLAMA_MODEL_ID" "$OLLAMA_MODEL_NAME" >> "$MODEL_FILE"
    fi
    echo "  ✅ 模型配置已创建（DeepSeek + Ollama）"
  elif [ -n "$OLLAMA_URL" ] && [ -n "$OLLAMA_MODEL_ID" ]; then
    printf '{"providers":{"ollama-local":{"baseUrl":"%s","api":"ollama","apiKey":"hana-runtime-api-key:ollama-local","models":[{"id":"%s","name":"%s","input":["text"],"contextWindow":128000,"reasoning":false}]}}}' "$OLLAMA_URL" "$OLLAMA_MODEL_ID" "$OLLAMA_MODEL_NAME" > "$MODEL_FILE"
    echo "  ✅ 模型配置已创建（仅 Ollama）"
  else
    echo "  ⚠️  未配置任何模型，请后手动创建 $MODEL_FILE"
  fi
fi

# 首次启动测试
echo "[6/6] 启动测试（5秒后自动停止）..."
cd "$HANAKO_DIR"
timeout 5 npm run server 2>/dev/null || true
echo ""
echo "  如果看到上方有 [server] 输出，说明启动成功。"
echo "  按下面的命令正式启动服务。"

echo ""
echo "=== 完成! ==="
echo ""
echo "启动服务:     cd $HANAKO_DIR && npm run server"
echo "或使用 systemd: sudo systemctl start hanako"
echo ""
echo "Web UI:       http://<你的NAS_IP>:14500/desktop/"
echo "设置页:       http://<你的NAS_IP>:14500/desktop/settings.html"
echo ""
echo "请参考 README.md 完成后续配置（防火墙、外网访问、自启等）"
