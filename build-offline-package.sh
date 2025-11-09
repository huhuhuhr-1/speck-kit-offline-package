#!/bin/bash
# 注意：此脚本需要 bash 环境，不支持纯 sh

# 检查是否在 bash 环境中运行
if [ -z "$BASH_VERSION" ]; then
    echo "错误：此脚本需要 bash 环境运行"
    echo "请使用：bash build-offline-package.sh"
    exit 1
fi

# Speck Kit 离线安装包构建脚本
# 生成包含所有依赖的独立安装包

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 先定义函数，避免调用顺序问题
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

# 配置
VERSION="v1.0"
PACKAGE_NAME="speck-kit-offline-installer"
BUILD_DIR="$(mktemp -d)"
SPECK_KIT_VERSION="v0.0.79"

# 缓存配置
CACHE_DIR="${SPECK_KIT_CACHE_DIR:-$HOME/.speck-kit-cache}"
FORCE_REBUILD=false
CLEAN_CACHE=false

# 解析命令行参数
while [ $# -gt 0 ]; do
    case $1 in
        --force)
            FORCE_REBUILD=true
            shift
            ;;
        --clean)
            CLEAN_CACHE=true
            shift
            ;;
        --cache-dir)
            CACHE_DIR="$2"
            shift 2
            ;;
        *)
            error "未知参数: $1"
            ;;
    esac
done

# 缓存管理函数
setup_cache() {
    if [ "$CLEAN_CACHE" = true ]; then
        log "清理缓存目录..."
        rm -rf "$CACHE_DIR"
    fi

    mkdir -p "$CACHE_DIR"/{source,packages,uv-binary,templates,metadata}
    log "缓存目录: $CACHE_DIR"

    # 显示缓存状态
    if [ -d "$CACHE_DIR/source" ] && [ -n "$(ls -A "$CACHE_DIR/source" 2>/dev/null)" ]; then
        log "发现源码缓存"
    fi
    if [ -d "$CACHE_DIR/packages" ] && [ -n "$(ls -A "$CACHE_DIR/packages" 2>/dev/null)" ]; then
        log "发现依赖包缓存"
    fi
    if [ -d "$CACHE_DIR/templates" ] && [ -n "$(ls -A "$CACHE_DIR/templates" 2>/dev/null)" ]; then
        log "发现模板文件缓存"
    fi
}

clean_cache() {
    if [ -d "$CACHE_DIR" ]; then
        local cache_size=$(du -sh "$CACHE_DIR" 2>/dev/null | cut -f1)
        log "清理缓存 (当前大小: $cache_size)..."
        rm -rf "$CACHE_DIR"
        log "缓存已清理"
    fi
}

# 生成文件哈希
generate_hash() {
    local file="$1"
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$file" | cut -d' ' -f1
    else
        # 备用方案：使用文件大小和修改时间
        stat -c "%s-%Y" "$file" 2>/dev/null || stat -f "%z-%m" "$file" 2>/dev/null
    fi
}

# 比较缓存有效性
is_cache_valid() {
    local cache_file="$1"
    local source_hash="$2"
    local hash_file="$3"

    if [ "$FORCE_REBUILD" = true ]; then
        return 1
    fi

    if [ ! -f "$cache_file" ] || [ ! -f "$hash_file" ]; then
        return 1
    fi

    local cached_hash=$(cat "$hash_file")
    [ "$cached_hash" = "$source_hash" ]
}

# 清理函数
cleanup() {
    rm -rf "$BUILD_DIR"
}

# 设置陷阱
trap cleanup EXIT

log "开始构建 Speck Kit 离线安装包..."

# 显示缓存状态
if [ "$FORCE_REBUILD" = true ]; then
    log "强制重建模式：忽略缓存"
elif [ "$CLEAN_CACHE" = true ]; then
    log "清理缓存模式：将删除所有缓存"
else
    log "增量构建模式：使用缓存加速"
fi

# 初始化缓存
setup_cache

# 检查依赖
command -v python3 >/dev/null 2>&1 || error "需要 Python 3"
command -v curl >/dev/null 2>&1 || error "需要 curl"
command -v tar >/dev/null 2>&1 || error "需要 tar"

# 检查是否为 Ubuntu 系统
if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [ "$ID" = "ubuntu" ] || [ "$ID_LIKE" = "ubuntu" ]; then
        log "检测到 Ubuntu 系统：$PRETTY_NAME"

        # 检查 Python 版本
        PYTHON_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
        if [ "$(printf '%s\n' "3.11" "$PYTHON_VERSION" | sort -V | head -n1)" != "3.11" ]; then
            warn "Ubuntu 系统建议使用 Python 3.11+，当前版本：$PYTHON_VERSION"
            warn "可以运行以下命令安装更新版本："
            warn "  sudo apt update"
            warn "  sudo apt install python3.11 python3.11-venv python3.11-dev"
            warn "  sudo apt install python3-pip"
        fi

        # 检查必要的系统包
        if ! command -v git >/dev/null 2>&1; then
            warn "建议安装 git：sudo apt install git"
        fi

        if ! command -v pip3 >/dev/null 2>&1; then
            warn "建议安装 pip3：sudo apt install python3-pip"
        fi
    fi
fi

# 检查网络连接
log "检查网络连接..."
NETWORK_AVAILABLE=false
if curl -s --connect-timeout 5 https://github.com >/dev/null; then
    NETWORK_AVAILABLE=true
    log "网络连接正常"
else
    warn "无法连接到 GitHub，将使用离线模式"
    warn "离线模式：只能使用本地缓存的文件"
fi

# 如果是离线模式且没有缓存，提示用户
if [ "$NETWORK_AVAILABLE" = false ] && [ ! -d "$CACHE_DIR/source" ]; then
    error "离线模式下需要先在联网环境运行脚本生成缓存"
fi

# 创建构建目录
log "创建构建目录..."
mkdir -p "$BUILD_DIR/$PACKAGE_NAME"
cd "$BUILD_DIR/$PACKAGE_NAME"

# 下载 Spec Kit 源码（使用缓存）
log "检查 Spec Kit 源码缓存..."
SOURCE_CACHE_DIR="$CACHE_DIR/source"
SOURCE_METADATA_FILE="$CACHE_DIR.metadata/source_commit"

# 获取最新 commit ID（仅在有网络时）
LATEST_COMMIT=""
if [ "$NETWORK_AVAILABLE" = true ]; then
    LATEST_COMMIT=$(curl -s "https://api.github.com/repos/github/spec-kit/commits/main" | grep '"sha"' | head -1 | sed 's/.*"([^"]+)".*/\1/')
fi

if [ -z "$LATEST_COMMIT" ]; then
    if [ "$NETWORK_AVAILABLE" = true ]; then
        warn "无法获取最新 commit 信息，使用传统方式下载"
        if [ -d "$SOURCE_CACHE_DIR" ]; then
            log "使用缓存的源码"
            cp -r "$SOURCE_CACHE_DIR" speck-kit-source
        else
            git clone --depth 1 https://github.com/github/spec-kit.git speck-kit-source
        fi
    else
        # 离线模式：必须使用缓存
        if [ -d "$SOURCE_CACHE_DIR" ]; then
            log "离线模式：使用缓存的源码"
            cp -r "$SOURCE_CACHE_DIR" speck-kit-source
        else
            error "离线模式下没有可用的源码缓存"
        fi
    fi
else
    if is_cache_valid "$SOURCE_CACHE_DIR" "$LATEST_COMMIT" "$SOURCE_METADATA_FILE"; then
        log "使用缓存的源码 (commit: ${LATEST_COMMIT:0:8})"
        cp -r "$SOURCE_CACHE_DIR" speck-kit-source
    else
        log "下载 Spec Kit 源码 (commit: ${LATEST_COMMIT:0:8})..."
        if [ -d "$SOURCE_CACHE_DIR" ]; then
            cd "$SOURCE_CACHE_DIR"
            git fetch origin main
            git reset --hard origin/main
            cd ..
        else
            git clone --depth 1 https://github.com/github/spec-kit.git "$SOURCE_CACHE_DIR"
        fi

        # 更新缓存
        cp -r "$SOURCE_CACHE_DIR" speck-kit-source
        echo "$LATEST_COMMIT" > "$SOURCE_METADATA_FILE"
        log "源码已更新到缓存"
    fi
fi

# 下载 Python 依赖
log "下载 Python 依赖包..."
cd speck-kit-source
python3 -m venv temp_env
if [ -f "temp_env/bin/activate" ]; then
    . temp_env/bin/activate
    pip install uv

    # 检查是否有缓存的依赖包
    if [ -n "$(ls ../packages/*.whl 2>/dev/null)" ]; then
        log "使用缓存的 Python 依赖包"
    elif [ -n "$(ls $CACHE_DIR/packages/*.whl 2>/dev/null)" ]; then
        log "使用缓存目录中的 Python 依赖包"
        mkdir -p ../packages
        cp $CACHE_DIR/packages/*.whl ../packages/ 2>/dev/null || true
    else
        log "未找到缓存的 Python 依赖包"
        if [ "$NETWORK_AVAILABLE" = true ]; then
            log "下载 Python 依赖包..."
            uv pip lock
            mkdir -p ../packages
            mkdir -p "$CACHE_DIR/packages"
            uv pip download --requirements uv.lock -d ../packages

            # 复制到缓存目录
            cp ../packages/*.whl "$CACHE_DIR/packages/" 2>/dev/null || true
            log "依赖包已保存到缓存"
        else
            # 离线模式：使用 pip 直接下载基本依赖
            log "离线模式：使用 pip 下载基本依赖..."
            mkdir -p ../packages
            pip download speck-cli -d ../packages 2>/dev/null || log "无法下载 speck-cli"
            pip download typer -d ../packages 2>/dev/null || log "无法下载 typer"
            pip download click -d ../packages 2>/dev/null || log "无法下载 click"
            pip download rich -d ../packages 2>/dev/null || log "无法下载 rich"
        fi
    fi

    if [ -n "$(ls ../packages/*.whl 2>/dev/null)" ]; then
        log "Python 依赖包准备完成"
    fi
    deactivate
else
    # 如果无法创建虚拟环境，使用 pip 直接下载
    log "使用 pip 直接下载依赖..."
    mkdir -p ../packages
    if [ "$NETWORK_AVAILABLE" = true ]; then
        pip download speck-cli -d ../packages
        pip download typer click rich -d ../packages
    else
        warn "离线模式下无法创建虚拟环境，跳过依赖下载"
    fi
fi
rm -rf temp_env
cd ..

# 下载 uv 包管理器（仅在有网络时）
if [ "$NETWORK_AVAILABLE" = true ]; then
    log "下载 uv 包管理器..."
    UV_VERSION=$(curl -s https://api.github.com/repos/astral-sh/uv/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

    # 检测系统架构
    ARCH=$(uname -m)
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')

    case $ARCH in
        x86_64)
            UV_ARCH="x86_64"
            ;;
        aarch64|arm64)
            UV_ARCH="aarch64"
            ;;
        armv7l)
            UV_ARCH="armv7"
            ;;
        *)
            log "不支持的架构: $ARCH，尝试使用 x86_64 版本"
            UV_ARCH="x86_64"
            ;;
    esac

    # 确定目标文件名
    if [ "$OS" = "linux" ]; then
        UV_FILE="uv-${UV_ARCH}-unknown-linux-musl.tar.gz"
    elif [ "$OS" = "darwin" ]; then
        UV_FILE="uv-${UV_ARCH}-apple-darwin.tar.gz"
    else
        log "不支持的操作系统: $OS，尝试使用 Linux 版本"
        UV_FILE="uv-${UV_ARCH}-unknown-linux-musl.tar.gz"
    fi

    log "下载 uv $UV_VERSION ($UV_FILE) ..."
    if curl -L "https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/${UV_FILE}" | tar -xz; then
        # 查找 uv 二进制文件
        UV_DIR=$(find . -name "uv-*" -type d | head -1)
        if [ -n "$UV_DIR" ] && [ -f "$UV_DIR/uv" ]; then
            mv "$UV_DIR/uv" uv-bin
            rm -rf "$UV_DIR"
            log "uv 下载成功"
        else
            warn "uv 二进制文件未找到，将在安装脚本中安装"
        fi
    else
        warn "uv 下载失败，将在安装脚本中安装"
    fi
else
    log "离线模式：跳过 uv 下载，将在安装脚本中处理"
fi

# 下载 AI 助手模板文件（使用缓存和并行下载）
log "检查 AI 助手模板缓存..."
TEMPLATES_CACHE_DIR="$CACHE_DIR/templates"
TEMPLATES_METADATA_FILE="$CACHE_DIR.metadata/templates_version"

mkdir -p templates

# 获取模板文件列表
log "获取模板文件列表..."
TEMPLATE_FILES=""
if [ "$NETWORK_AVAILABLE" = true ]; then
    TEMPLATE_FILES=$(curl -s "https://api.github.com/repos/github/spec-kit/releases/tags/v0.0.79" | \
        grep -o '"spec-kit-template-[^"]*\.zip"' | \
        sed 's/"//g')
fi

if [ -z "$TEMPLATE_FILES" ]; then
    if [ "$NETWORK_AVAILABLE" = true ]; then
        warn "无法获取模板文件列表，使用默认列表"
    else
        log "离线模式：使用缓存的模板文件列表"
    fi
    TEMPLATE_FILES="spec-kit-template-claude-sh-v0.0.79.zip spec-kit-template-claude-ps-v0.0.79.zip spec-kit-template-copilot-sh-v0.0.79.zip spec-kit-template-copilot-ps-v0.0.79.zip spec-kit-template-gemini-sh-v0.0.79.zip spec-kit-template-gemini-ps-v0.0.79.zip spec-kit-template-qwen-sh-v0.0.79.zip spec-kit-template-qwen-ps-v0.0.79.zip spec-kit-template-opencode-sh-v0.0.79.zip spec-kit-template-opencode-ps-v0.0.79.zip spec-kit-template-cursor-agent-sh-v0.0.79.zip spec-kit-template-codex-sh-v0.0.79.zip spec-kit-template-codex-ps-v0.0.79.zip spec-kit-template-windsurf-sh-v0.0.79.zip spec-kit-template-windsurf-ps-v0.0.79.zip spec-kit-template-kilocode-sh-v0.0.79.zip spec-kit-template-kilocode-ps-v0.0.79.zip spec-kit-template-auggie-sh-v0.0.79.zip spec-kit-template-auggie-ps-v0.0.79.zip spec-kit-template-codebuddy-sh-v0.0.79.zip spec-kit-template-codebuddy-ps-v0.0.79.zip spec-kit-template-roo-sh-v0.0.79.zip spec-kit-template-roo-ps-v0.0.79.zip spec-kit-template-q-sh-v0.0.79.zip spec-kit-template-q-ps-v0.0.79.zip spec-kit-template-amp-sh-v0.0.79.zip spec-kit-template-amp-ps-v0.0.79.zip"
fi

# 检查模板版本
if is_cache_valid "$TEMPLATES_CACHE_DIR" "$SPECK_KIT_VERSION" "$TEMPLATES_METADATA_FILE"; then
    log "使用缓存的模板文件"
    cp -r "$TEMPLATES_CACHE_DIR"/* templates/ 2>/dev/null || true
else
    log "下载模板文件..."

    # 创建下载函数
    download_template() {
        local template="$1"
        local cache_file="$TEMPLATES_CACHE_DIR/$template"
        local target_file="templates/$template"

        # 检查单个文件缓存
        if [ -f "$cache_file" ] && [ "$FORCE_REBUILD" != true ]; then
            local file_size=$(stat -c%s "$cache_file" 2>/dev/null || stat -f%z "$cache_file" 2>/dev/null)
            if [ "$file_size" -gt 50000 ]; then  # 文件应该大于50KB
                cp "$cache_file" "$target_file"
                echo "✓ $template (缓存)"
                return 0
            fi
        fi

        # 下载文件（仅在有网络时）
        if [ "$NETWORK_AVAILABLE" = true ]; then
            if curl -L -s -o "$cache_file.tmp" "https://github.com/github/spec-kit/releases/download/v0.0.79/$template"; then
                local file_size=$(stat -c%s "$cache_file.tmp" 2>/dev/null || stat -f%z "$cache_file.tmp" 2>/dev/null)
                if [ "$file_size" -gt 50000 ]; then
                    mv "$cache_file.tmp" "$cache_file"
                    cp "$cache_file" "$target_file"
                    echo "✓ $template (下载)"
                    return 0
                else
                    rm -f "$cache_file.tmp"
                    echo "✗ $template (文件过小)"
                    return 1
                fi
            else
                rm -f "$cache_file.tmp"
                echo "✗ $template (下载失败)"
                return 1
            fi
        else
            # 离线模式：只能使用缓存
            if [ -f "$cache_file" ]; then
                local file_size=$(stat -c%s "$cache_file" 2>/dev/null || stat -f%z "$cache_file" 2>/dev/null)
                if [ "$file_size" -gt 50000 ]; then
                    cp "$cache_file" "$target_file"
                    echo "✓ $template (离线缓存)"
                    return 0
                else
                    echo "✗ $template (缓存文件损坏)"
                    return 1
                fi
            else
                echo "✗ $template (无缓存)"
                return 1
            fi
        fi
    }

    # 导出函数以供 xargs 使用
    export -f download_template
    export TEMPLATES_CACHE_DIR SPECK_KIT_VERSION FORCE_REBUILD

    # 并行下载模板文件
    mkdir -p "$TEMPLATES_CACHE_DIR"
    log "开始并行下载 $(echo $TEMPLATE_FILES | wc -w) 个模板文件..."

    # 检查是否支持并行下载
    if command -v xargs >/dev/null 2>&1 && xargs --help 2>/dev/null | grep -q "max-procs\|-P"; then
        # 使用并行下载
        echo "$TEMPLATE_FILES" | tr ' ' '\n' | xargs -I {} -P 4 bash -c 'download_template "$@"' _ {}
    else
        # 串行下载作为备用方案
        for template in $TEMPLATE_FILES; do
            download_template "$template"
        done
    fi

    # 更新模板版本缓存
    echo "$SPECK_KIT_VERSION" > "$TEMPLATES_METADATA_FILE"
    log "模板文件已更新到缓存"
fi

# 统计下载结果
TEMPLATE_COUNT=$(find templates -name "*.zip" -type f | wc -l)
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

# 检查并安装 uv 包管理器
log "检查 uv 包管理器..."
export PATH="$(pwd):$PATH"

if [ -f "./uv-bin" ]; then
    log "使用内置 uv 二进制文件"
    chmod +x uv-bin
    UV_CMD="./uv-bin"
else
    log "安装 uv 包管理器..."
    # 尝试不同的安装方法
    if command -v pip3 >/dev/null 2>&1; then
        pip3 install uv --user
        UV_CMD="uv"
    elif command -v pip >/dev/null 2>&1; then
        pip install uv --user
        UV_CMD="uv"
    else
        error "找不到 pip 或 pip3，请先安装 Python pip"
    fi
fi

# 验证 uv 安装
if ! $UV_CMD version >/dev/null 2>&1; then
    error "uv 安装失败"
fi

# 安装 Spec Kit
log "安装 Spec Kit..."
if [ "$UV_CMD" = "./uv-bin" ]; then
    $UV_CMD tool install ./speck-kit-source --no-index --find-links packages
else
    $UV_CMD tool install ./speck-kit-source --no-index --find-links packages
fi

# 设置环境变量
log "配置环境变量..."
SHELL_CONFIG="$HOME/.bashrc"
if [ -n "$ZSH_VERSION" ]; then
    SHELL_CONFIG="$HOME/.zshrc"
fi

if ! grep -q "SPECIFY_TEMPLATE_DIR" "$SHELL_CONFIG"; then
    echo "export SPECIFY_TEMPLATE_DIR=\$(pwd)/templates" >> "$SHELL_CONFIG"
fi

if ! grep -q "\.local/bin" "$SHELL_CONFIG"; then
    echo "export PATH=\$HOME/.local/bin:\$PATH" >> "$SHELL_CONFIG"
fi

# 验证安装
log "验证安装..."
export SPECIFY_TEMPLATE_DIR="$(pwd)/templates"
export PATH="$HOME/.local/bin:$PATH:$(pwd)"

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