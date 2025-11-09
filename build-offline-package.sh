#!/bin/bash

# Speck Kit 离线安装包构建脚本
# 生成包含所有依赖的独立安装包

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 配置
VERSION="v1.0"
PACKAGE_NAME="speck-kit-offline-installer"
BUILD_DIR="$(mktemp -d)"
SPECK_KIT_VERSION="v0.0.79"

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# 清理函数
cleanup() {
    rm -rf "$BUILD_DIR"
}

# 设置陷阱
trap cleanup EXIT

log "开始构建 Speck Kit 离线安装包..."

# 检查依赖
command -v python3 >/dev/null 2>&1 || error "需要 Python 3"
command -v curl >/dev/null 2>&1 || error "需要 curl"
command -v tar >/dev/null 2>&1 || error "需要 tar"

# 检查网络连接
log "检查网络连接..."
if ! curl -s --connect-timeout 5 https://github.com >/dev/null; then
    error "无法连接到 GitHub，请检查网络连接"
fi

# 创建构建目录
log "创建构建目录..."
mkdir -p "$BUILD_DIR/$PACKAGE_NAME"
cd "$BUILD_DIR/$PACKAGE_NAME"

# 下载 Spec Kit 源码
log "下载 Spec Kit 源码..."
if [ -d "speck-kit-source" ]; then
    rm -rf speck-kit-source
fi
git clone --depth 1 https://github.com/github/spec-kit.git speck-kit-source

# 下载 Python 依赖
log "下载 Python 依赖包..."
cd speck-kit-source
python3 -m venv temp_env
if [ -f "temp_env/bin/activate" ]; then
    . temp_env/bin/activate
    pip install uv
    uv pip lock
    mkdir -p ../packages
    uv pip download --requirements uv.lock -d ../packages
    deactivate
else
    # 如果无法创建虚拟环境，使用 pip 直接下载
    log "使用 pip 直接下载依赖..."
    mkdir -p ../packages
    pip download speck-cli -d ../packages
    pip download typer click rich -d ../packages
fi
rm -rf temp_env
cd ..

# 下载 uv 包管理器
log "下载 uv 包管理器..."
UV_VERSION=$(curl -s https://api.github.com/repos/astral-sh/uv/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
curl -L "https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/uv-x86_64-unknown-linux-musl.tar.gz" | tar -xz
mv uv-x86_64-unknown-linux-musl/uv uv-bin
rm -rf uv-x86_64-unknown-linux-musl

# 下载 AI 助手模板文件
log "下载 AI 助手模板文件..."
mkdir -p templates

# 获取最新的模板文件列表
log "获取模板文件列表..."
TEMPLATE_FILES=$(curl -s "https://api.github.com/repos/github/spec-kit/releases/tags/v0.0.79" | \
    grep -o '"spec-kit-template-[^"]*\.zip"' | \
    sed 's/"//g')

if [ -z "$TEMPLATE_FILES" ]; then
    warn "无法获取模板文件列表，使用默认列表"
    TEMPLATE_FILES="spec-kit-template-claude-sh-v0.0.79.zip spec-kit-template-claude-ps-v0.0.79.zip spec-kit-template-copilot-sh-v0.0.79.zip spec-kit-template-copilot-ps-v0.0.79.zip spec-kit-template-gemini-sh-v0.0.79.zip spec-kit-template-gemini-ps-v0.0.79.zip"
fi

# 下载模板文件
TEMPLATE_COUNT=0
for template in $TEMPLATE_FILES; do
    log "下载模板: $template"
    if curl -L -o "templates/$template" "https://github.com/github/spec-kit/releases/download/v0.0.79/$template"; then
        TEMPLATE_COUNT=$((TEMPLATE_COUNT + 1))
    else
        warn "下载失败: $template"
    fi
done

log "成功下载 $TEMPLATE_COUNT 个模板文件"

# 创建安装脚本
log "创建安装脚本..."
cat > install.sh << 'EOF'
#!/bin/bash

# Speck Kit 离线安装脚本
set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

log "开始安装 Speck Kit..."

# 检查系统要求
if ! command -v python3 >/dev/null 2>&1; then
    error "需要 Python 3.11 或更高版本"
fi

PYTHON_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
if [ "$(printf '%s\n' "3.11" "$PYTHON_VERSION" | sort -V | head -n1)" != "3.11" ]; then
    error "Python 版本过低: $PYTHON_VERSION，需要 3.11 或更高版本"
fi

log "Python 版本检查通过: $PYTHON_VERSION"

# 安装 uv 包管理器
log "安装 uv 包管理器..."
chmod +x uv-bin
./uv-bin version

# 安装 Spec Kit
log "安装 Spec Kit..."
export PATH="$(pwd):$PATH"
./uv-bin tool install ./speck-kit-source --no-index --find-links packages

# 设置环境变量
log "配置环境变量..."
SHELL_CONFIG="$HOME/.bashrc"
if [ -n "$ZSH_VERSION" ]; then
    SHELL_CONFIG="$HOME/.zshrc"
fi

if ! grep -q "SPECIFY_TEMPLATE_DIR" "$SHELL_CONFIG"; then
    echo "export SPECIFY_TEMPLATE_DIR=$(pwd)/templates" >> "$SHELL_CONFIG"
fi

if ! grep -q "\.local/bin" "$SHELL_CONFIG"; then
    echo "export PATH=\$HOME/.local/bin:\$PATH" >> "$SHELL_CONFIG"
fi

# 验证安装
log "验证安装..."
export SPECIFY_TEMPLATE_DIR="$(pwd)/templates"
export PATH="$HOME/.local/bin:$PATH:$PATH"

if ! command -v specify >/dev/null 2>&1; then
    error "安装失败：specify 命令不可用"
fi

log "Speck Kit 安装完成！"
log ""
log "请运行以下命令重新加载环境变量："
log "source $SHELL_CONFIG"
log ""
log "然后可以开始使用："
log "specify init my-project --ai claude"
log ""
log "支持的 AI 助手："
log "claude, copilot, gemini, qwen, cursor-agent, codex, windsurf, kilocode, auggie, codebuddy, roo, q, amp"
EOF

chmod +x install.sh

# 创建 README
cat > README.md << EOF
# Speck Kit 离线安装包

## 快速安装

\`\`\`bash
# 1. 解压安装包
tar -xzf speck-kit-offline-installer.tar.gz

# 2. 运行安装脚本
./install.sh

# 3. 重新加载环境变量
source ~/.bashrc

# 4. 开始使用
specify init my-project --ai claude
\`\`\`

## 支持的 AI 助手

- claude (Claude Code)
- copilot (GitHub Copilot)
- gemini (Gemini CLI)
- qwen (Qwen Code)
- cursor-agent (Cursor)
- codex (Codex CLI)
- windsurf (Windsurf)
- kilocode (Kilo Code)
- auggie (Auggie CLI)
- codebuddy (CodeBuddy)
- roo (Roo Code)
- q (Amazon Q Developer CLI)
- amp (Amp)

## 版本信息

- Spec Kit 版本: v0.0.20
- 模板版本: v0.0.79
- 构建时间: $(date)

---

如有问题，请检查：
1. Python 版本 >= 3.11
2. 磁盘空间充足
3. 脚本有执行权限
EOF

# 创建版本信息文件
cat > version.json << EOF
{
    "package_version": "$VERSION",
    "speck_kit_version": "v0.0.20",
    "template_version": "$SPECK_KIT_VERSION",
    "build_time": "$(date -Iseconds)",
    "template_count": $TEMPLATE_COUNT,
    "python_packages": $(find packages -name "*.whl" | wc -l)
}
EOF

# 返回上级目录并打包
cd "$BUILD_DIR"
log "打包安装包..."
tar -czf "${PACKAGE_NAME}.tar.gz" "$PACKAGE_NAME"

# 移动到原目录
mv "${PACKAGE_NAME}.tar.gz" "$(pwd)/../../"

log "离线安装包构建完成！"
log "文件位置: $(pwd)/../../${PACKAGE_NAME}.tar.gz"
log "文件大小: $(du -h "../../${PACKAGE_NAME}.tar.gz" | cut -f1)"

# 显示统计信息
echo ""
echo "=== 构建统计 ==="
echo "模板文件数量: $TEMPLATE_COUNT"
echo "Python 包数量: $(find "$BUILD_DIR/$PACKAGE_NAME/packages" -name "*.whl" | wc -l)"
echo "总文件大小: $(du -sh "$BUILD_DIR/$PACKAGE_NAME" | cut -f1)"
echo "================"

log "构建完成！可以将 ${PACKAGE_NAME}.tar.gz 传输到目标环境进行安装。"