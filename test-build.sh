#!/bin/bash

# 简单测试脚本
set -e

echo "=== Speck Kit 构建测试 ==="

# 检查环境
echo "1. 检查环境..."
echo "Python: $(python3 --version)"
echo "当前目录: $(pwd)"

# 检查文件
echo "2. 检查文件..."
echo "模板文件数量: $(find templates/ -name "*.zip" | wc -l)"
echo "本地脚本: $(ls *.sh | wc -l)"

# 快速构建
echo "3. 快速构建..."
rm -rf speck-kit-offline-installer.tar.gz speck-kit-offline-installer 2>/dev/null

# 创建目录
mkdir -p speck-kit-offline-installer

# 复制模板文件
echo "复制模板文件..."
cp -r templates/* speck-kit-offline-installer/ 2>/dev/null || true

# 复制依赖包
echo "复制依赖包..."
mkdir -p packages
# 从临时目录复制（如果存在）
if [ -d "/tmp/tmp.*" ]; then
    find /tmp/tmp.* -name "*.whl" -exec cp {} packages/ \; 2>/dev/null || true
fi

# 创建安装脚本
echo "创建安装脚本..."
cat > speck-kit-offline-installer/install.sh << 'EOF'
#!/bin/bash
set -e

echo "[INFO] 安装 Spe Kit..."

# 检查 Python
if ! command -v python3 >/dev/null 2>&1; then
    echo "[ERROR] 需要 Python 3.11+"
    exit 1
fi

# 安装 Spec Kit
echo "[INFO] 安装 Spec Kit..."
if [ -d "packages" ] && [ -n "$(ls packages/*.whl 2>/dev/null)" ]; then
    echo "[INFO] 使用本地依赖包"
    python3 -m pip install --user --find-links packages --no-index speck-cli typer click rich 2>/dev/null || true
else
    echo "[INFO] 从网络安装"
    python3 -m pip install --user speck-cli
fi

# 设置环境变量
echo "[INFO] 配置环境变量..."
SHELL_CONFIG="$HOME/.bashrc"
if [ -n "$ZSH_VERSION" ]; then
    SHELL_CONFIG="$HOME/.zshrc"
fi

echo "export SPECIFY_TEMPLATE_DIR=\$(pwd)/templates" >> "$SHELL_CONFIG"
echo "export PATH=\$HOME/.local/bin:\$PATH" >> "$SHELL_CONFIG"

echo "[INFO] 安装完成！"
echo "[INFO] 请运行: source $SHELL_CONFIG"
echo "[INFO] 然后使用: specify init my-project --ai claude"
EOF

chmod +x speck-kit-offline-installer/install.sh

# 打包
echo "4. 打包..."
tar -czf speck-kit-offline-installer.tar.gz speck-kit-offline-installer/

# 清理
rm -rf speck-kit-offline-installer

# 显示结果
echo "=== 构建结果 ==="
echo "文件: speck-kit-offline-installer.tar.gz"
echo "大小: $(du -h speck-kit-offline-installer.tar.gz | cut -f1)"
echo "模板文件: $(tar -tzf speck-kit-offline-installer.tar.gz | grep '\.zip' | wc -l)"
echo "依赖包: $(tar -tzf speck-kit-offline-installer.tar.gz | grep '\.whl' | wc -l)"

echo ""
echo "✅ 快速构建完成！"
echo "使用方法："
echo "1. tar -xzf speck-kit-offline-installer.tar.gz"
echo "2. cd speck-kit-offline-installer"
echo "3. ./install.sh"
echo "4. source ~/.bashrc"
echo "5. specify init my-project --ai claude"