#!/bin/bash

# Spec Kit 离线包准备脚本（外网环境）
# 此脚本用于在有互联网连接的环境中准备 Spec Kit 的离线安装包

set -e

# 脚本配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPECK_KIT_DIR="$(dirname "$SCRIPT_DIR")"
DOCS_DIR="$(dirname "$SPECK_KIT_DIR")"
PACKAGES_DIR="$SPECK_KIT_DIR/packages"
TEMPLATES_DIR="$SPECK_KIT_DIR/templates"
SOURCE_DIR="/tmp/speck-kit-source"
LOG_FILE="/tmp/speck-kit-prepare.log"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

# 检查系统要求
check_requirements() {
    log "检查系统要求..."

    # 检查 Python 版本
    if command -v python3 &> /dev/null; then
        PYTHON_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
        info "Python 版本: $PYTHON_VERSION"

        if python3 -c "import sys; exit(0 if sys.version_info >= (3, 11) else 1)"; then
            success "Python 版本满足要求 (>=3.11)"
        else
            error "Python 版本不满足要求，需要 3.11 或更高版本"
            error "当前版本: $PYTHON_VERSION"
            exit 1
        fi
    else
        error "未找到 Python3，请先安装 Python 3.11+"
        exit 1
    fi

    # 检查网络连接
    if curl -s --connect-timeout 5 https://github.com > /dev/null; then
        success "网络连接正常"
    else
        error "无法连接到 GitHub，请检查网络连接"
        exit 1
    fi

    # 检查磁盘空间
    AVAILABLE_SPACE=$(df "$SPECK_KIT_DIR" | awk 'NR==2 {print $4}')
    REQUIRED_SPACE=204800  # 200MB in KB

    if [ "$AVAILABLE_SPACE" -gt "$REQUIRED_SPACE" ]; then
        success "磁盘空间充足"
    else
        error "磁盘空间不足，至少需要 200MB"
        exit 1
    fi
}

# 创建目录结构
create_directories() {
    log "创建目录结构..."

    mkdir -p "$PACKAGES_DIR"
    mkdir -p "$TEMPLATES_DIR"

    success "目录结构创建完成"
}

# 安装 uv 包管理器
install_uv() {
    log "安装 uv 包管理器..."

    if command -v uv &> /dev/null; then
        info "uv 已安装，版本: $(uv --version)"
        return
    fi

    # 下载并安装 uv
    UV_INSTALL_URL="https://astral.sh/uv/install.sh"
    if curl -LsSf "$UV_INSTALL_URL" | sh; then
        success "uv 安装成功"
        export PATH="$HOME/.cargo/bin:$PATH"
    else
        error "uv 安装失败"
        exit 1
    fi
}

# 下载 Spec Kit 源码
download_spec_kit() {
    log "下载 Spec Kit 源码..."

    if [ -d "$SOURCE_DIR" ]; then
        rm -rf "$SOURCE_DIR"
    fi

    if git clone https://github.com/github/spec-kit.git "$SOURCE_DIR"; then
        success "Spec Kit 源码下载完成"
    else
        error "Spec Kit 源码下载失败"
        exit 1
    fi

    # 获取版本信息
    cd "$SOURCE_DIR"
    SPEC_VERSION=$(python3 -c "import sys; sys.path.append('src'); from specify_cli import __version__; print(__version__)" 2>/dev/null || echo "unknown")
    GIT_COMMIT=$(git rev-parse --short HEAD)
    GIT_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "latest")

    info "Spec Kit 版本: $SPEC_VERSION"
    info "Git 标签: $GIT_TAG"
    info "Git 提交: $GIT_COMMIT"

    # 保存版本信息
    cat > "$SPECK_KIT_DIR/version-info.json" << EOF
{
    "spec_version": "$SPEC_VERSION",
    "git_tag": "$GIT_TAG",
    "git_commit": "$GIT_COMMIT",
    "prepare_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "python_version": "$PYTHON_VERSION"
}
EOF

    cd - > /dev/null
}

# 下载 Python 依赖包
download_dependencies() {
    log "下载 Python 依赖包..."

    cd "$SOURCE_DIR"

    # 生成依赖锁文件
    if uv pip lock; then
        success "依赖锁文件生成成功"
    else
        warning "依赖锁文件生成失败，尝试手动解析依赖"
    fi

    # 下载所有依赖包
    if uv pip download --requirements uv.lock -d "$PACKAGES_DIR" 2>/dev/null || \
       uv pip download -e . -d "$PACKAGES_DIR"; then
        success "依赖包下载完成"
    else
        error "依赖包下载失败"
        exit 1
    fi

    # 下载 uv 本身（用于离线安装）
    log "下载 uv 包管理器..."
    if uv pip download uv --python 3.11 -d "$PACKAGES_DIR"; then
        success "uv 包下载完成"
    else
        error "uv 包下载失败"
        exit 1
    fi

    # 统计下载的包数量
    PACKAGE_COUNT=$(find "$PACKAGES_DIR" -name "*.whl" | wc -l)
    info "共下载了 $PACKAGE_COUNT 个包"

    cd - > /dev/null
}

# 复制 Spec Kit 源码
copy_source_code() {
    log "复制 Spec Kit 源码..."

    SOURCE_OUTPUT_DIR="$PACKAGES_DIR/speck-kit-source"

    if [ -d "$SOURCE_OUTPUT_DIR" ]; then
        rm -rf "$SOURCE_OUTPUT_DIR"
    fi

    cp -r "$SOURCE_DIR" "$SOURCE_OUTPUT_DIR"

    # 创建可分发的源码包
    cd "$PACKAGES_DIR"
    tar -czf "speck-kit-source.tar.gz" -C . "speck-kit-source"
    rm -rf "speck-kit-source"
    cd - > /dev/null

    success "Spec Kit 源码复制完成"
}

# 检查并补充模板文件
download_templates() {
    log "检查模板文件..."

    # 检查现有模板文件
    EXISTING_TEMPLATES=$(find "$TEMPLATES_DIR" -name "*.zip" 2>/dev/null | wc -l)

    if [ "$EXISTING_TEMPLATES" -gt 0 ]; then
        log "发现现有模板文件: $EXISTING_TEMPLATES 个"

        # 显示现有模板
        if [ "$VERBOSE" = true ]; then
            info "现有模板文件："
            find "$TEMPLATES_DIR" -name "*.zip" -exec basename {} \; | sort | sed 's/^/  - /'
        fi

        # 验证现有模板文件的完整性
        log "验证现有模板文件..."
        VALID_COUNT=0
        for FILEPATH in "$TEMPLATES_DIR"/*.zip; do
            if [ -f "$FILEPATH" ]; then
                FILESIZE=$(stat -f%z "$FILEPATH" 2>/dev/null || stat -c%s "$FILEPATH" 2>/dev/null || echo "0")
                if [ "$FILESIZE" -gt 50000 ]; then  # 模板文件应该至少50KB
                    VALID_COUNT=$((VALID_COUNT + 1))
                    FILENAME=$(basename "$FILEPATH")
                    info "✓ $FILENAME ($(($FILESIZE / 1024))KB)"
                else
                    FILENAME=$(basename "$FILEPATH")
                    warning "✗ $FILENAME 文件大小异常 ($(($FILESIZE / 1024))KB)，可能损坏"
                fi
            fi
        done

        success "现有模板文件验证完成: $VALID_COUNT/$EXISTING_TEMPLATES"

        # 检查是否需要补充缺失的模板
        check_missing_templates
    else
        log "未找到现有模板文件，尝试自动下载..."
        auto_download_templates
    fi
}

# 检查缺失的模板文件
check_missing_templates() {
    log "检查缺失的模板文件..."

    # 期望的模板文件列表
    local expected_templates=(
        "amp-ps" "amp-sh"
        "auggie-ps" "auggie-sh"
        "claude-ps" "claude-sh"
        "codebuddy-ps" "codebuddy-sh"
        "codex-ps" "codex-sh"
        "copilot-ps" "copilot-sh"
        "cursor-agent-ps" "cursor-agent-sh"
        "gemini-ps" "gemini-sh"
        "kilocode-ps" "kilocode-sh"
        "opencode-ps" "opencode-sh"
        "q-ps" "q-sh"
        "qwen-ps" "qwen-sh"
        "roo-ps" "roo-sh"
        "windsurf-ps" "windsurf-sh"
    )

    local missing_count=0
    local missing_files=()

    # 获取当前版本（从现有模板文件中提取）
    local current_version=$(find "$TEMPLATES_DIR" -name "*.zip" | head -1 | sed 's/.*-v\([0-9.]*\)\.zip/\1/' | head -1)

    for template in "${expected_templates[@]}"; do
        local expected_file="speck-kit-template-${template}-v${current_version}.zip"
        if [ ! -f "$TEMPLATES_DIR/$expected_file" ]; then
            missing_files+=("$expected_file")
            missing_count=$((missing_count + 1))
        fi
    done

    if [ "$missing_count" -gt 0 ]; then
        warning "发现 $missing_count 个缺失的模板文件"
        info "缺失的文件："
        for file in "${missing_files[@]}"; do
            info "  - $file"
        done

        # 尝试自动下载缺失的模板
        if command -v curl &> /dev/null || command -v wget &> /dev/null; then
            log "尝试自动下载缺失的模板文件..."
            download_missing_templates "${missing_files[@]}" "$current_version"
        else
            warning "未找到下载工具，请手动下载缺失的模板文件"
            generate_missing_template_instructions "${missing_files[@]}" "$current_version"
        fi
    else
        success "所有必需的模板文件都已存在"
    fi
}

# 自动下载缺失的模板文件
download_missing_templates() {
    local missing_files=("$@")
    # 最后一个参数是版本号
    local current_version="${missing_files[-1]}"
    unset missing_files[-1]

    local downloaded_count=0

    for file in "${missing_files[@]}"; do
        local download_url="https://github.com/github/spec-kit/releases/download/v${current_version}/${file}"
        local filepath="$TEMPLATES_DIR/$file"

        log "下载: $file"

        if command -v curl &> /dev/null; then
            if curl -L --connect-timeout 30 -o "$filepath" "$download_url"; then
                downloaded_count=$((downloaded_count + 1))
                success "✓ $file"
            else
                error "✗ $file 下载失败"
            fi
        elif command -v wget &> /dev/null; then
            if wget --timeout=30 -O "$filepath" "$download_url"; then
                downloaded_count=$((downloaded_count + 1))
                success "✓ $file"
            else
                error "✗ $file 下载失败"
            fi
        fi
    done

    if [ "$downloaded_count" -gt 0 ]; then
        success "成功下载 $downloaded_count 个缺失的模板文件"
    else
        warning "未能下载任何缺失的模板文件"
    fi
}

# 完全自动下载模板文件
auto_download_templates() {
    log "自动下载模板文件..."

    # 获取最新 release 信息
    log "获取最新 release 信息..."
    RELEASE_API_URL="https://api.github.com/repos/github/spec-kit/releases/latest"

    if command -v curl &> /dev/null; then
        RELEASE_DATA=$(curl -s "$RELEASE_API_URL")
    elif command -v wget &> /dev/null; then
        RELEASE_DATA=$(wget -qO- "$RELEASE_API_URL")
    else
        error "未找到 curl 或 wget，无法下载模板文件"
        generate_template_instructions
        return 1
    fi

    if [ $? -ne 0 ] || [ -z "$RELEASE_DATA" ]; then
        error "无法获取 release 信息"
        generate_template_instructions
        return 1
    fi

    # 解析 release 信息
    TAG_NAME=$(echo "$RELEASE_DATA" | grep '"tag_name"' | cut -d '"' -f 4)
    log "找到最新版本: $TAG_NAME"

    # 提取所有模板文件的下载链接
    TEMPLATE_URLS=$(echo "$RELEASE_DATA" | grep -o '"browser_download_url": "[^"]*speck-kit-template[^"]*\.zip"' | cut -d '"' -f 4)

    if [ -z "$TEMPLATE_URLS" ]; then
        warning "未找到模板文件，可能 API 返回格式有变化"
        generate_template_instructions
        return 1
    fi

    # 下载每个模板文件
    DOWNLOADED_COUNT=0
    TOTAL_COUNT=$(echo "$TEMPLATE_URLS" | wc -l)

    log "准备下载 $TOTAL_COUNT 个模板文件..."

    for URL in $TEMPLATE_URLS; do
        FILENAME=$(basename "$URL")
        FILEPATH="$TEMPLATES_DIR/$FILENAME"

        log "下载: $FILENAME"

        if command -v curl &> /dev/null; then
            if curl -L -o "$FILEPATH" "$URL"; then
                DOWNLOADED_COUNT=$((DOWNLOADED_COUNT + 1))
                success "✓ $FILENAME"
            else
                error "✗ $FILENAME 下载失败"
            fi
        elif command -v wget &> /dev/null; then
            if wget -O "$FILEPATH" "$URL"; then
                DOWNLOADED_COUNT=$((DOWNLOADED_COUNT + 1))
                success "✓ $FILENAME"
            else
                error "✗ $FILENAME 下载失败"
            fi
        fi
    done

    if [ "$DOWNLOADED_COUNT" -gt 0 ]; then
        success "模板文件下载完成: $DOWNLOADED_COUNT/$TOTAL_COUNT"

        # 验证下载的文件
        log "验证下载的模板文件..."
        VALID_COUNT=0
        for FILEPATH in "$TEMPLATES_DIR"/*.zip; do
            if [ -f "$FILEPATH" ]; then
                FILESIZE=$(stat -f%z "$FILEPATH" 2>/dev/null || stat -c%s "$FILEPATH" 2>/dev/null || echo "0")
                if [ "$FILESIZE" -gt 0 ]; then
                    VALID_COUNT=$((VALID_COUNT + 1))
                    FILENAME=$(basename "$FILEPATH")
                    info "✓ $FILENAME ($(($FILESIZE / 1024))KB)"
                else
                    FILENAME=$(basename "$FILEPATH")
                    warning "✗ $FILENAME 文件大小为0，可能损坏"
                fi
            fi
        done

        if [ "$VALID_COUNT" -eq "$DOWNLOADED_COUNT" ]; then
            success "所有模板文件验证通过"
        else
            warning "部分模板文件可能损坏"
        fi
    else
        error "没有成功下载任何模板文件"
        generate_template_instructions
        return 1
    fi
}

# 生成缺失模板的下载说明
generate_missing_template_instructions() {
    local missing_files=("$@")
    local current_version="${missing_files[-1]}"
    unset missing_files[-1]

    cat > "$TEMPLATES_DIR/MISSING_TEMPLATES.md" << EOF
# 缺失模板文件下载说明

当前版本: v$current_version

## 缺失的模板文件

EOF

    for file in "${missing_files[@]}"; do
        echo "- $file" >> "$TEMPLATES_DIR/MISSING_TEMPLATES.md"
    done

    cat >> "$TEMPLATES_DIR/MISSING_TEMPLATES.md" << EOF

## 下载地址

请访问以下链接下载缺失的模板文件：
https://github.com/github/spec-kit/releases/tag/v$current_version

## 下载方法

1. 点击上述链接进入 Release 页面
2. 在 "Assets" 部分找到对应的模板文件
3. 下载并放置到此目录：$TEMPLATES_DIR

完成后重新运行安装脚本。
EOF

    warning "缺失模板文件下载说明已生成: $TEMPLATES_DIR/MISSING_TEMPLATES.md"
}

# 生成模板文件下载说明（备用）
generate_template_instructions() {
    log "生成备用模板文件下载说明..."

    cat > "$TEMPLATES_DIR/DOWNLOAD_INSTRUCTIONS.md" << EOF
# Spec Kit 模板文件下载说明

## 重要说明

自动下载失败，请手动下载模板文件。

## 下载步骤

1. **访问 GitHub Releases 页面**
   - URL: https://github.com/github/spec-kit/releases

2. **选择最新版本**
   - 点击最新的 release 标签：$TAG_NAME

3. **下载模板文件**
   - 在 "Assets" 部分查找所有 \`speck-kit-template-*-*.zip\` 文件
   - 根据您的需要下载对应的模板文件

## 版本信息

当前 Spec Kit 版本：$SPEC_VERSION
Git 标签：$GIT_TAG
准备日期：$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF

    warning "请手动下载模板文件"
}

# 创建安装脚本
create_install_script() {
    log "创建离线安装脚本..."

    cat > "$SCRIPT_DIR/install-offline.sh" << 'EOF'
#!/bin/bash

# Spec Kit 离线安装脚本（研发网环境）
# 此脚本用于在离线环境中安装 Spec Kit

set -e

# 脚本配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCS_DIR="$(dirname "$SCRIPT_DIR")"
PACKAGES_DIR="$DOCS_DIR/packages"
TEMPLATES_DIR="$DOCS_DIR/templates"
LOG_FILE="/tmp/speck-kit-install.log"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 解析命令行参数
FORCE_INSTALL=false
UPDATE_MODE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --force)
            FORCE_INSTALL=true
            shift
            ;;
        --update)
            UPDATE_MODE=true
            shift
            ;;
        -h|--help)
            echo "用法: $0 [--force] [--update] [--help]"
            echo "  --force   强制重新安装"
            echo "  --update  更新模式"
            echo "  --help    显示帮助信息"
            exit 0
            ;;
        *)
            echo "未知参数: $1"
            exit 1
            ;;
    esac
done

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

# 检查环境
check_environment() {
    log "检查安装环境..."

    # 检查 Python 版本
    if command -v python3 &> /dev/null; then
        PYTHON_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
        info "Python 版本: $PYTHON_VERSION"

        if python3 -c "import sys; exit(0 if sys.version_info >= (3, 11) else 1)"; then
            success "Python 版本满足要求"
        else
            error "Python 版本不满足要求，需要 3.11 或更高版本"
            exit 1
        fi
    else
        error "未找到 Python3"
        exit 1
    fi

    # 检查必要的文件
    if [ ! -d "$PACKAGES_DIR" ]; then
        error "找不到离线包目录: $PACKAGES_DIR"
        exit 1
    fi

    if [ ! -d "$TEMPLATES_DIR" ]; then
        error "找不到模板目录: $TEMPLATES_DIR"
        exit 1
    fi

    # 检查包文件
    PACKAGE_COUNT=$(find "$PACKAGES_DIR" -name "*.whl" | wc -l)
    if [ "$PACKAGE_COUNT" -eq 0 ]; then
        error "离线包目录中没有找到任何 .whl 文件"
        exit 1
    fi

    info "找到 $PACKAGE_COUNT 个包文件"

    # 检查模板文件
    TEMPLATE_COUNT=$(find "$TEMPLATES_DIR" -name "*.zip" | wc -l)
    if [ "$TEMPLATE_COUNT" -eq 0 ]; then
        warning "模板目录中没有找到任何 .zip 文件"
        warning "请确保已经下载了模板文件"
    else
        info "找到 $TEMPLATE_COUNT 个模板文件"
    fi
}

# 安装 uv
install_uv() {
    log "安装 uv 包管理器..."

    if command -v uv &> /dev/null && [ "$FORCE_INSTALL" = false ]; then
        info "uv 已安装，版本: $(uv --version)"
        return
    fi

    # 从离线包安装 uv
    UV_PACKAGE=$(find "$PACKAGES_DIR" -name "uv-*.whl" | head -1)

    if [ -n "$UV_PACKAGE" ]; then
        info "从离线包安装 uv: $UV_PACKAGE"
        python3 -m pip install --user "$UV_PACKAGE"

        # 添加到 PATH
        export PATH="$HOME/.local/bin:$PATH"

        if command -v uv &> /dev/null; then
            success "uv 安装成功，版本: $(uv --version)"
        else
            error "uv 安装失败"
            exit 1
        fi
    else
        error "找不到 uv 离线包"
        exit 1
    fi
}

# 安装 Spec Kit
install_spec_kit() {
    log "安装 Spec Kit..."

    # 检查是否已安装
    if command -v specify &> /dev/null && [ "$FORCE_INSTALL" = false ] && [ "$UPDATE_MODE" = false ]; then
        info "Spec Kit 已安装"
        return
    fi

    # 从离线包安装
    if [ "$UPDATE_MODE" = true ]; then
        info "更新模式：重新安装 Spec Kit"
        uv tool uninstall specify-cli 2>/dev/null || true
    fi

    # 查找 Spec Kit 包
    SPEC_PACKAGE=$(find "$PACKAGES_DIR" -name "specify_cli-*.whl" | head -1)

    if [ -n "$SPEC_PACKAGE" ]; then
        info "从离线包安装 Spec Kit: $SPEC_PACKAGE"
        uv tool install "$SPEC_PACKAGE" --force
    else
        # 尝试从源码安装
        SOURCE_PACKAGE="$PACKAGES_DIR/speck-kit-source.tar.gz"
        if [ -f "$SOURCE_PACKAGE" ]; then
            info "从源码包安装 Spec Kit"
            cd /tmp
            tar -xzf "$SOURCE_PACKAGE"
            cd speck-kit-source
            uv tool install -e . --force
            cd /tmp
            rm -rf speck-kit-source
        else
            error "找不到 Spec Kit 安装包"
            exit 1
        fi
    fi

    if command -v specify &> /dev/null; then
        success "Spec Kit 安装成功"
        specify --help
    else
        error "Spec Kit 安装失败"
        exit 1
    fi
}

# 配置环境
configure_environment() {
    log "配置环境..."

    # 设置模板目录环境变量
    PROFILE_FILE="$HOME/.bashrc"
    if [ -f "$HOME/.zshrc" ]; then
        PROFILE_FILE="$HOME/.zshrc"
    fi

    # 添加 PATH 和环境变量
    {
        echo ""
        echo "# Spec Kit Environment"
        echo "export PATH=\$HOME/.local/bin:\$HOME/.cargo/bin:\$PATH"
        echo "export SPECIFY_TEMPLATE_DIR=\"$TEMPLATES_DIR\""
    } >> "$PROFILE_FILE"

    # 设置当前会话的环境变量
    export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
    export SPECIFY_TEMPLATE_DIR="$TEMPLATES_DIR"

    success "环境配置完成"
}

# 主安装流程
main() {
    log "开始 Spec Kit 离线安装..."

    check_environment
    install_uv
    install_spec_kit
    configure_environment

    success "Spec Kit 离线安装完成！"
    echo ""
    info "请运行以下命令重新加载环境变量："
    info "source $PROFILE_FILE"
    echo ""
    info "然后运行验证脚本："
    info "cd $SCRIPT_DIR && ./verify-install.sh"
}

# 执行主函数
main "$@"
EOF

    chmod +x "$SCRIPT_DIR/install-offline.sh"
    success "离线安装脚本创建完成"
}

# 创建验证脚本
create_verify_script() {
    log "创建安装验证脚本..."

    cat > "$SCRIPT_DIR/verify-install.sh" << 'EOF'
#!/bin/bash

# Spec Kit 安装验证脚本

set -e

# 脚本配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCS_DIR="$(dirname "$SCRIPT_DIR")"
TEMPLATES_DIR="$DOCS_DIR/templates"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# 验证命令可用性
verify_commands() {
    log "验证命令可用性..."

    # 检查 Python
    if command -v python3 &> /dev/null; then
        success "Python3 可用: $(python3 --version)"
    else
        error "Python3 不可用"
        return 1
    fi

    # 检查 uv
    if command -v uv &> /dev/null; then
        success "uv 可用: $(uv --version)"
    else
        error "uv 不可用"
        return 1
    fi

    # 检查 specify
    if command -v specify &> /dev/null; then
        success "specify 命令可用"
    else
        error "specify 不可用"
        return 1
    fi
}

# 验证模板文件
verify_templates() {
    log "验证模板文件..."

    if [ -d "$TEMPLATES_DIR" ]; then
        TEMPLATE_COUNT=$(find "$TEMPLATES_DIR" -name "*.zip" | wc -l)
        if [ "$TEMPLATE_COUNT" -gt 0 ]; then
            success "找到 $TEMPLATE_COUNT 个模板文件"
            ls -la "$TEMPLATES_DIR"/*.zip 2>/dev/null || true
        else
            warning "模板目录为空"
        fi
    else
        warning "模板目录不存在: $TEMPLATES_DIR"
    fi
}

# 验证 Spec Kit 功能
verify_spec_kit_functionality() {
    log "验证 Spec Kit 功能..."

    # 运行检查命令
    if specify check > /dev/null 2>&1; then
        success "specify check 命令执行成功"
    else
        warning "specify check 命令执行失败，可能需要安装 AI 助手工具"
    fi

    # 测试帮助命令
    if specify --help > /dev/null 2>&1; then
        success "specify --help 命令执行成功"
    else
        error "specify --help 命令执行失败"
        return 1
    fi
}

# 创建测试项目
test_project_creation() {
    log "测试项目创建功能..."

    TEST_DIR="/tmp/speck-kit-test-$(date +%s)"

    # 创建测试目录
    mkdir -p "$TEST_DIR"
    cd "$TEST_DIR"

    # 尝试初始化项目（使用 --ignore-agent-tools 跳过 AI 工具检查）
    if specify init test-project --ignore-agent-tools > /dev/null 2>&1; then
        success "项目初始化测试成功"

        # 检查项目结构
        if [ -d "test-project" ] && [ -d "test-project/.specify" ]; then
            success "项目结构正确"
        else
            warning "项目结构可能有问题"
        fi
    else
        warning "项目初始化测试失败（可能是因为模板文件缺失）"
    fi

    # 清理测试目录
    cd - > /dev/null
    rm -rf "$TEST_DIR"
}

# 主验证流程
main() {
    log "开始验证 Spec Kit 安装..."

    echo "=============================================="
    echo "Spec Kit 安装验证报告"
    echo "=============================================="
    echo ""

    local all_passed=true

    verify_commands || all_passed=false
    echo ""

    verify_templates
    echo ""

    verify_spec_kit_functionality || all_passed=false
    echo ""

    test_project_creation
    echo ""

    if [ "$all_passed" = true ]; then
        success "所有核心验证项目通过！"
        echo ""
        info "Spec Kit 已成功安装并可以使用。"
        info "现在您可以运行以下命令创建新项目："
        info "specify init my-project --ai <assistant-name>"
    else
        error "部分验证项目失败，请检查安装。"
        exit 1
    fi
}

# 执行主函数
main "$@"
EOF

    chmod +x "$SCRIPT_DIR/verify-install.sh"
    success "安装验证脚本创建完成"
}

# 生成准备报告
generate_report() {
    log "生成准备报告..."

    PACKAGE_COUNT=$(find "$PACKAGES_DIR" -name "*.whl" | wc -l)
    TEMPLATE_COUNT=$(find "$TEMPLATES_DIR" -name "*.zip" | wc -l)
    TOTAL_SIZE=$(du -sh "$PACKAGES_DIR" 2>/dev/null | cut -f1)

    cat > "$SPECK_KIT_DIR/PREPARE_REPORT.md" << EOF
# Spec Kit 离线包准备报告

## 准备信息

- 准备时间: $(date -u +%Y-%m-%dT%H:%M:%SZ)
- Spec Kit 版本: $SPEC_VERSION
- Git 标签: $GIT_TAG
- Python 版本: $PYTHON_VERSION

## 离线包统计

- 包文件数量: $PACKAGE_COUNT
- 模板文件数量: $TEMPLATE_COUNT
- 总大小: $TOTAL_SIZE

## 文件清单

### 包文件
\`\`\`
$(ls -la "$PACKAGES_DIR/")
\`\`\`

### 模板文件
\`\`\`
$(ls -la "$TEMPLATES_DIR/")
\`\`\`

## 脚本文件

- \`scripts/install-offline.sh\` - 离线安装脚本
- \`scripts/verify-install.sh\` - 安装验证脚本

## 下一步操作

1. **检查模板文件**: 确保已下载所需的模板文件到 \`templates/\` 目录
2. **传输到研发网**: 将整个 \`docs/\` 目录传输到目标环境
3. **运行安装**: 在研发网运行 \`scripts/install-offline.sh\`
4. **验证安装**: 运行 \`scripts/verify-install.sh\` 验证安装

## 注意事项

- 模板文件需要手动下载（请参考 \`templates/DOWNLOAD_INSTRUCTIONS.md\`）
- 确保目标环境有 Python 3.11+
- 安装脚本会自动配置环境变量

---

报告生成时间: $(date)
EOF

    success "准备报告已生成"
}

# 主函数
main() {
    echo "=============================================="
    echo "Spec Kit 离线包准备脚本"
    echo "=============================================="
    echo ""

    log "开始准备 Spec Kit 离线包..."

    check_requirements
    create_directories
    install_uv
    download_spec_kit
    download_dependencies
    copy_source_code

    # 尝试自动下载模板文件
    if download_templates; then
        success "模板文件自动下载完成"
    else
        warning "模板文件自动下载失败，请手动下载"
    fi

    create_install_script
    create_verify_script
    generate_report

    echo ""
    success "Spec Kit 离线包准备完成！"
    echo ""
    info "准备结果："
    info "- 包文件：$PACKAGE_COUNT 个"
    info "- 模板文件：$(find "$TEMPLATES_DIR" -name "*.zip" 2>/dev/null | wc -l) 个"
    info "- 脚本文件：3 个（安装、验证、准备）"
    info "- 文档文件：4 个（说明、指南、报告等）"
    echo ""

    # 检查是否有模板文件
    TEMPLATE_COUNT=$(find "$TEMPLATES_DIR" -name "*.zip" 2>/dev/null | wc -l)
    if [ "$TEMPLATE_COUNT" -gt 0 ]; then
        success "模板文件已准备完成，可以直接传输到研发网使用"
        info "找到的模板文件："
        find "$TEMPLATES_DIR" -name "*.zip" -exec basename {} \; | sort | sed 's/^/  - /'
    else
        warning "重要提醒："
        warning "1. 没有找到模板文件，请手动下载（参考 $TEMPLATES_DIR/DOWNLOAD_INSTRUCTIONS.md）"
        warning "2. 确保所有必需的模板文件都已下载到 $TEMPLATES_DIR 目录"
        warning "3. 完成模板文件下载后，将整个 $SPECK_KIT_DIR 目录传输到研发网"
    fi
    echo ""
    info "详细报告请查看：$SPECK_KIT_DIR/PREPARE_REPORT.md"
}

# 执行主函数
main "$@"