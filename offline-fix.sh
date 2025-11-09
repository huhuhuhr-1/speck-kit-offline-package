#!/bin/bash
# 离线环境快速修复脚本
# 用于解决依赖包缺失问题

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

log "离线环境快速修复脚本"
log "====================="

# 检查是否在正确的目录
if [ ! -f "build-offline-package.sh" ]; then
    error "请在 speck-kit-offline-package 目录中运行此脚本"
fi

log "步骤 1: 创建基本依赖包..."
mkdir -p packages

# 使用 pip 下载基本依赖包
log "下载 speck-cli..."
pip download speck-cli -d packages/ 2>/dev/null || warn "无法下载 speck-cli，跳过"

log "下载 typer..."
pip download typer -d packages/ 2>/dev/null || warn "无法下载 typer，跳过"

log "下载 click..."
pip download click -d packages/ 2>/dev/null || warn "无法下载 click，跳过"

log "下载 rich..."
pip download rich -d packages/ 2>/dev/null || warn "无法下载 rich，跳过"

# 检查下载结果
PACKAGE_COUNT=$(find packages -name "*.whl" 2>/dev/null | wc -l)
log "步骤 2: 检查下载结果"
log "成功下载 $PACKAGE_COUNT 个依赖包"

if [ "$PACKAGE_COUNT" -eq 0 ]; then
    warn "没有下载到任何依赖包"
    warn "这可能是因为："
    warn "1. pip 命令不可用"
    warn "2. 网络连接问题"
    warn "3. 权限问题"
    warn ""
    warn "尝试手动安装依赖："
    warn "pip3 install --user speck-cli typer click rich"
    exit 1
fi

log "步骤 3: 更新缓存目录..."
CACHE_DIR="$HOME/.speck-kit-cache"
mkdir -p "$CACHE_DIR/packages"
cp packages/*.whl "$CACHE_DIR/packages/" 2>/dev/null || true
log "依赖包已保存到缓存目录"

log "步骤 4: 创建简化的构建脚本..."
cat > quick-build.sh << 'EOF'
#!/bin/bash

# 简化的离线构建脚本
set -e

echo "[INFO] 快速离线构建开始..."

# 检查必要文件
if [ ! -d "templates" ] || [ -z "$(ls templates/*.zip 2>/dev/null)" ]; then
    echo "[ERROR] 模板文件缺失，请先在联网环境运行构建脚本"
    exit 1
fi

if [ ! -d "packages" ] || [ -z "$(ls packages/*.whl 2>/dev/null)" ]; then
    echo "[ERROR] 依赖包缺失，请先运行 offline-fix.sh"
    exit 1
fi

# 创建临时构建目录
BUILD_DIR="speck-kit-offline-installer"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# 复制模板文件
echo "[INFO] 复制模板文件..."
cp -r templates "$BUILD_DIR/"

# 复制依赖包
echo "[INFO] 复制依赖包..."
cp -r packages "$BUILD_DIR/"

# 创建简化的安装脚本
cat > "$BUILD_DIR/install.sh" << 'INSTALL_EOF'
#!/bin/bash
set -e

echo "[INFO] 开始安装 Spec Kit..."

# 检查 Python
if ! command -v python3 >/dev/null 2>&1; then
    echo "[ERROR] 需要 Python 3.11+"
    exit 1
fi

# 安装 Spec Kit
echo "[INFO] 安装 Spec Kit..."
python3 -m pip install --user --find-links packages --no-index speck-cli || {
    echo "[ERROR] 安装失败，尝试手动安装："
    echo "python3 -m pip install --user speck-cli"
    exit 1
}

# 设置环境变量
SHELL_CONFIG="$HOME/.bashrc"
if [ -n "$ZSH_VERSION" ]; then
    SHELL_CONFIG="$HOME/.zshrc"
fi

echo "export SPECIFY_TEMPLATE_DIR=\$(pwd)/templates" >> "$SHELL_CONFIG"
echo "export PATH=\$HOME/.local/bin:\$PATH" >> "$SHELL_CONFIG"

echo "[INFO] 安装完成！"
echo "[INFO] 请运行: source $SHELL_CONFIG"
echo "[INFO] 然后使用: specify init my-project --ai claude"
INSTALL_EOF

chmod +x "$BUILD_DIR/install.sh"

# 创建 README
cat > "$BUILD_DIR/README.md" << 'README_EOF'
# Speck Kit 离线安装包

## 快速安装

```bash
# 1. 解压
tar -xzf speck-kit-offline-installer.tar.gz
cd speck-kit-offline-installer

# 2. 安装
./install.sh

# 3. 配置环境
source ~/.bashrc

# 4. 使用
specify init my-project --ai claude
```

## 注意事项

- 确保使用 Python 3.11+
- 如果安装失败，请手动运行：`python3 -m pip install --user speck-cli`
- 支持的 AI 助手：claude, copilot, gemini, qwen, cursor-agent 等
README_EOF

# 打包
echo "[INFO] 打包安装包..."
tar -czf "speck-kit-offline-installer.tar.gz" "$BUILD_DIR"

# 清理
rm -rf "$BUILD_DIR"

echo "[INFO] 快速构建完成！"
echo "[INFO] 生成的文件: speck-kit-offline-installer.tar.gz"
echo "[INFO] 可以将此文件传输到离线环境使用"
EOF

chmod +x quick-build.sh

log "修复完成！"
log ""
log "现在可以使用以下方法："
log "1. 快速构建: ./quick-build.sh"
log "2. 完整构建: bash build-offline-package.sh (如果缓存完整)"
log ""
log "推荐的离线工作流程："
log "- 联网环境: bash build-offline-package.sh (生成完整缓存)"
log "- 离线环境: ./quick-build.sh (使用缓存的依赖)"