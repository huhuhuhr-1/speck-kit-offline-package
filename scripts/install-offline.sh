#!/bin/bash

# Spec Kit 离线安装脚本（研发网环境）
# 此脚本用于在离线环境中安装 Spec Kit

set -e

# 脚本配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPECK_KIT_DIR="$(dirname "$SCRIPT_DIR")"
DOCS_DIR="$(dirname "$SPECK_KIT_DIR")"
PACKAGES_DIR="$SPECK_KIT_DIR/packages"
TEMPLATES_DIR="$SPECK_KIT_DIR/templates"
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

# 显示安装横幅
show_banner() {
    echo "=============================================="
    echo "Spec Kit 离线安装脚本"
    echo "=============================================="
    echo ""
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
            error "当前版本: $PYTHON_VERSION"
            exit 1
        fi
    else
        error "未找到 Python3"
        exit 1
    fi

    # 检查必要的文件
    if [ ! -d "$PACKAGES_DIR" ]; then
        error "找不到离线包目录: $PACKAGES_DIR"
        error "请确保离线包已正确传输到此位置"
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
        error "请检查离线包是否完整"
        exit 1
    fi

    info "找到 $PACKAGE_COUNT 个包文件"

    # 检查模板文件
    TEMPLATE_COUNT=$(find "$TEMPLATES_DIR" -name "*.zip" 2>/dev/null | wc -l)
    if [ "$TEMPLATE_COUNT" -eq 0 ]; then
        warning "模板目录中没有找到任何 .zip 文件"
        warning "请确保已经下载了模板文件"
        warning "如果没有模板文件，Spec Kit 仍可安装但无法初始化项目"
    else
        info "找到 $TEMPLATE_COUNT 个模板文件"

        # 验证模板文件质量
        VALID_TEMPLATES=0
        TOTAL_SIZE=0
        for FILEPATH in "$TEMPLATES_DIR"/*.zip; do
            if [ -f "$FILEPATH" ]; then
                FILESIZE=$(stat -f%z "$FILEPATH" 2>/dev/null || stat -c%s "$FILEPATH" 2>/dev/null || echo "0")
                TOTAL_SIZE=$((TOTAL_SIZE + FILESIZE))
                if [ "$FILESIZE" -gt 50000 ]; then  # 模板文件应该至少50KB
                    VALID_TEMPLATES=$((VALID_TEMPLATES + 1))
                else
                    FILENAME=$(basename "$FILEPATH")
                    warning "模板文件可能损坏: $FILENAME ($(($FILESIZE / 1024))KB)"
                fi
            fi
        done

        if [ "$VALID_TEMPLATES" -gt 0 ]; then
            success "验证了 $VALID_TEMPLATES 个有效的模板文件 ($(($TOTAL_SIZE / 1024 / 1024))MB)"
        else
            warning "没有找到有效的模板文件"
        fi

        # 分析模板覆盖的 AI 助手
        log "分析 AI 助手覆盖情况..."
        local covered_assistants=()
        for FILEPATH in "$TEMPLATES_DIR"/*.zip; do
            if [ -f "$FILEPATH" ]; then
                local assistant=$(basename "$FILEPATH" | sed 's/.*speck-kit-template-\([^-]*\)-.*/\1/')
                if [[ ! " ${covered_assistants[@]} " =~ " ${assistant} " ]]; then
                    covered_assistants+=("$assistant")
                fi
            fi
        done

        info "支持的 AI 助手: ${#covered_assistants[@]} 个"
        if [ "$VERBOSE" = true ]; then
            local assistant_list=$(IFS=", "; echo "${covered_assistants[*]}")
            info "  $assistant_list"
        fi
    fi

    # 检查磁盘空间
    AVAILABLE_SPACE=$(df "$HOME" | awk 'NR==2 {print $4}')
    REQUIRED_SPACE=102400  # 100MB in KB

    if [ "$AVAILABLE_SPACE" -gt "$REQUIRED_SPACE" ]; then
        success "磁盘空间充足"
    else
        error "磁盘空间不足，至少需要 100MB"
        exit 1
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

        # 创建用户目录
        mkdir -p "$HOME/.local/bin"

        # 安装 uv
        python3 -m pip install --user --no-index --find-links "$PACKAGES_DIR" uv

        # 添加到 PATH
        export PATH="$HOME/.local/bin:$PATH"

        # 验证安装
        if command -v uv &> /dev/null; then
            success "uv 安装成功，版本: $(uv --version)"
        else
            error "uv 安装失败"
            exit 1
        fi
    else
        error "找不到 uv 离线包"
        error "请确保离线包中包含 uv-*.whl 文件"
        exit 1
    fi
}

# 安装 Spec Kit
install_spec_kit() {
    log "安装 Spec Kit..."

    # 检查是否已安装
    if command -v specify &> /dev/null && [ "$FORCE_INSTALL" = false ] && [ "$UPDATE_MODE" = false ]; then
        INSTALLED_VERSION="已安装"
        info "Spec Kit 已安装，版本: $INSTALLED_VERSION"

        if [ "$UPDATE_MODE" = false ]; then
            return
        fi
    fi

    # 更新模式：先卸载旧版本
    if [ "$UPDATE_MODE" = true ]; then
        info "更新模式：卸载旧版本"
        uv tool uninstall specify-cli 2>/dev/null || true
    fi

    # 查找 Spec Kit 包
    SPEC_PACKAGE=$(find "$PACKAGES_DIR" -name "specify_cli-*.whl" | head -1)

    if [ -n "$SPEC_PACKAGE" ]; then
        info "从离线包安装 Spec Kit: $SPEC_PACKAGE"

        # 使用 uv tool 安装
        if uv tool install --no-index --find-links "$PACKAGES_DIR" "$SPEC_PACKAGE" --force; then
            success "Spec Kit 安装成功"
        else
            error "Spec Kit 安装失败"
            exit 1
        fi
    else
        # 尝试从源码安装
        SOURCE_PACKAGE="$PACKAGES_DIR/speck-kit-source.tar.gz"
        if [ -f "$SOURCE_PACKAGE" ]; then
            info "从源码包安装 Spec Kit"

            # 解压源码包
            cd /tmp
            tar -xzf "$SOURCE_PACKAGE"
            cd speck-kit-source

            # 从源码安装
            if uv tool install -e . --no-index --find-links "$PACKAGES_DIR" --force; then
                success "Spec Kit 从源码安装成功"
            else
                error "Spec Kit 从源码安装失败"
                exit 1
            fi

            # 清理
            cd /tmp
            rm -rf speck-kit-source
        else
            error "找不到 Spec Kit 安装包"
            error "请确保离线包中包含 specify_cli-*.whl 或 speck-kit-source.tar.gz"
            exit 1
        fi
    fi

    # 验证安装
    if command -v specify &> /dev/null; then
        success "Spec Kit 安装成功"
        INSTALLED_VERSION="安装完成"
        info "安装版本: $INSTALLED_VERSION"
    else
        error "Spec Kit 安装失败"
        exit 1
    fi
}

# 配置环境
configure_environment() {
    log "配置环境..."

    # 确定配置文件
    PROFILE_FILE="$HOME/.bashrc"
    if [ -n "$ZSH_VERSION" ] || [ -f "$HOME/.zshrc" ]; then
        PROFILE_FILE="$HOME/.zshrc"
    fi

    # 检查是否已经配置过
    if grep -q "# Spec Kit Environment" "$PROFILE_FILE" 2>/dev/null; then
        if [ "$FORCE_INSTALL" = true ]; then
            info "删除旧的配置"
            sed -i '/# Spec Kit Environment/,/^$/d' "$PROFILE_FILE" 2>/dev/null || true
        else
            info "环境已配置过，跳过配置步骤"
            return
        fi
    fi

    # 添加环境变量配置
    {
        echo ""
        echo "# Spec Kit Environment"
        echo "export PATH=\"\$HOME/.local/bin:\$HOME/.cargo/bin:\$PATH\""
        echo "export SPECIFY_TEMPLATE_DIR=\"$TEMPLATES_DIR\""
        echo "export UV_CACHE_DIR=\"\$HOME/.uv-cache\""
    } >> "$PROFILE_FILE"

    # 设置当前会话的环境变量
    export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
    export SPECIFY_TEMPLATE_DIR="$TEMPLATES_DIR"
    export UV_CACHE_DIR="$HOME/.uv-cache"

    success "环境配置完成"
    info "配置文件: $PROFILE_FILE"
}

# 创建必要的目录
create_directories() {
    log "创建必要的目录..."

    # 创建 uv 缓存目录
    mkdir -p "$HOME/.uv-cache"

    # 创建本地工具目录
    mkdir -p "$HOME/.local/bin"

    success "目录创建完成"
}

# 测试安装
test_installation() {
    log "测试安装..."

    # 测试 specify 命令
    if command -v specify &> /dev/null; then
        success "specify 命令可用"

        # 测试版本信息
        VERSION_OUTPUT="specify 命令可用"
        info "版本信息: $VERSION_OUTPUT"

        # 测试帮助信息
        if specify --help > /dev/null 2>&1; then
            success "specify 帮助命令正常"
        else
            warning "specify 帮助命令异常"
        fi
    else
        error "specify 命令不可用"
        return 1
    fi
}

# 显示安装完成信息
show_completion_info() {
    echo ""
    success "Spec Kit 离线安装完成！"
    echo ""
    echo "=============================================="
    echo "安装摘要"
    echo "=============================================="
    echo "安装位置: $HOME/.local/bin"
    echo "模板目录: $TEMPLATES_DIR"
    echo "包文件数: $PACKAGE_COUNT"
    echo "模板文件数: $TEMPLATE_COUNT"
    echo ""
    echo "下一步操作："
    echo "1. 重新加载环境变量："
    echo "   source $HOME/.bashrc"
    echo "   # 或者重新打开终端"
    echo ""
    echo "2. 运行验证脚本："
    echo "   cd $SCRIPT_DIR"
    echo "   ./verify-install.sh"
    echo ""
    echo "3. 开始使用 Spec Kit："
    echo "   specify check"
    echo "   specify init my-project --ai claude"
    echo ""
    if [ "$TEMPLATE_COUNT" -eq 0 ]; then
        warning "注意：没有找到模板文件，请确保已下载模板文件到 $TEMPLATES_DIR"
        warning "没有模板文件将无法初始化新项目"
    fi
    echo "=============================================="
}

# 错误处理
handle_error() {
    echo ""
    error "安装过程中发生错误！"
    echo ""
    info "故障排除步骤："
    info "1. 检查日志文件: $LOG_FILE"
    info "2. 确保系统满足要求（Python 3.11+）"
    info "3. 检查离线包完整性"
    info "4. 确保有足够的磁盘空间和权限"
    echo ""
    info "如需强制重新安装，请运行："
    info "$0 --force"
    echo ""
}

# 主安装流程
main() {
    # 设置错误处理
    trap handle_error ERR

    show_banner
    log "开始 Spec Kit 离线安装..."

    check_environment
    create_directories
    install_uv
    install_spec_kit
    configure_environment
    test_installation

    show_completion_info
}

# 执行主函数
main "$@"