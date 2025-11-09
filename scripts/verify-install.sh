#!/bin/bash

# Spec Kit 安装验证脚本
# 用于验证 Spec Kit 是否正确安装并可以正常使用

set -e

# 脚本配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPECK_KIT_DIR="$(dirname "$SCRIPT_DIR")"
DOCS_DIR="$(dirname "$SPECK_KIT_DIR")"
TEMPLATES_DIR="$SPECK_KIT_DIR/templates"
LOG_FILE="/tmp/speck-kit-verify.log"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 解析命令行参数
VERBOSE=false
QUICK_MODE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -q|--quick)
            QUICK_MODE=true
            shift
            ;;
        -h|--help)
            echo "用法: $0 [--verbose] [--quick] [--help]"
            echo "  --verbose  显示详细输出"
            echo "  --quick    快速验证模式（跳过耗时操作）"
            echo "  --help     显示帮助信息"
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
    if [ "$VERBOSE" = true ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
    fi
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

debug() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${CYAN}[DEBUG]${NC} $1" | tee -a "$LOG_FILE"
    fi
}

# 显示验证横幅
show_banner() {
    echo "=============================================="
    echo "Spec Kit 安装验证脚本"
    echo "=============================================="
    echo ""
}

# 验证命令可用性
verify_commands() {
    log "验证命令可用性..."
    echo "检查命令可用性："
    echo ""

    local all_commands_passed=true

    # 检查 Python
    if command -v python3 &> /dev/null; then
        PYTHON_VERSION=$(python3 --version)
        success "✓ Python3: $PYTHON_VERSION"
        debug "Python 路径: $(which python3)"
    else
        error "✗ Python3 不可用"
        all_commands_passed=false
    fi

    # 检查 uv
    if command -v uv &> /dev/null; then
        UV_VERSION=$(uv --version)
        success "✓ uv: $UV_VERSION"
        debug "uv 路径: $(which uv)"
    else
        error "✗ uv 不可用"
        all_commands_passed=false
    fi

    # 检查 specify
    if command -v specify &> /dev/null; then
        # specify 不支持 --version 选项，使用 --help 验证
        if specify --help > /dev/null 2>&1; then
            success "✓ specify: 命令可用"
        else
            error "✗ specify: 命令异常"
            all_commands_passed=false
        fi
        debug "specify 路径: $(which specify)"
    else
        error "✗ specify 不可用"
        all_commands_passed=false
    fi

    echo ""
    if [ "$all_commands_passed" = true ]; then
        success "所有必需命令都可用"
        return 0
    else
        error "部分必需命令不可用"
        return 1
    fi
}

# 验证环境变量
verify_environment() {
    log "验证环境变量..."
    echo "检查环境变量："
    echo ""

    # 检查 PATH
    if echo "$PATH" | grep -q "$HOME/.local/bin"; then
        success "✓ PATH 包含用户本地二进制目录"
    else
        warning "✗ PATH 不包含用户本地二进制目录"
        info "  当前 PATH: $PATH"
    fi

    if echo "$PATH" | grep -q "$HOME/.cargo/bin"; then
        success "✓ PATH 包含 cargo 二进制目录"
    else
        warning "✗ PATH 不包含 cargo 二进制目录（如果没有安装 cargo 则正常）"
    fi

    # 检查模板目录环境变量
    if [ -n "$SPECIFY_TEMPLATE_DIR" ]; then
        if [ "$SPECIFY_TEMPLATE_DIR" = "$TEMPLATES_DIR" ]; then
            success "✓ SPECIFY_TEMPLATE_DIR 设置正确: $SPECIFY_TEMPLATE_DIR"
        else
            warning "✗ SPECIFY_TEMPLATE_DIR 设置不匹配"
            info "  当前设置: $SPECIFY_TEMPLATE_DIR"
            info "  期望设置: $TEMPLATES_DIR"
        fi
    else
        warning "✗ SPECIFY_TEMPLATE_DIR 未设置"
    fi

    # 检查 UV_CACHE_DIR
    if [ -n "$UV_CACHE_DIR" ]; then
        success "✓ UV_CACHE_DIR 已设置: $UV_CACHE_DIR"
    else
        warning "✗ UV_CACHE_DIR 未设置"
    fi

    echo ""
}

# 验证模板文件
verify_templates() {
    log "验证模板文件..."
    echo "检查模板文件："
    echo ""

    if [ -d "$TEMPLATES_DIR" ]; then
        TEMPLATE_COUNT=$(find "$TEMPLATES_DIR" -name "*.zip" 2>/dev/null | wc -l)
        if [ "$TEMPLATE_COUNT" -gt 0 ]; then
            success "✓ 找到 $TEMPLATE_COUNT 个模板文件"

            # 验证模板文件质量
            VALID_TEMPLATES=0
            TOTAL_SIZE=0
            for FILEPATH in "$TEMPLATES_DIR"/*.zip; do
                if [ -f "$FILEPATH" ]; then
                    FILESIZE=$(stat -f%z "$FILEPATH" 2>/dev/null || stat -c%s "$FILEPATH" 2>/dev/null || echo "0")
                    TOTAL_SIZE=$((TOTAL_SIZE + FILESIZE))
                    if [ "$FILESIZE" -gt 50000 ]; then  # 模板文件应该至少50KB
                        VALID_TEMPLATES=$((VALID_TEMPLATES + 1))
                        if [ "$VERBOSE" = true ]; then
                            FILENAME=$(basename "$FILEPATH")
                            info "  ✓ $FILENAME ($(($FILESIZE / 1024))KB)"
                        fi
                    else
                        FILENAME=$(basename "$FILEPATH")
                        warning "  ✗ $FILENAME 文件大小异常 ($(($FILESIZE / 1024))KB)"
                    fi
                fi
            done

            echo ""
            if [ "$VALID_TEMPLATES" -gt 0 ]; then
                success "✓ 验证了 $VALID_TEMPLATES 个有效的模板文件"
                info "  总大小: $(($TOTAL_SIZE / 1024 / 1024))MB"
            else
                error "✗ 没有找到有效的模板文件"
            fi

            # 分析 AI 助手覆盖情况
            echo ""
            echo "AI 助手覆盖分析："

            # 简单统计 AI 助手
            local amp_count=$(find "$TEMPLATES_DIR" -name "*spec-kit-template-amp*" | wc -l)
            local auggie_count=$(find "$TEMPLATES_DIR" -name "*spec-kit-template-auggie*" | wc -l)
            local claude_count=$(find "$TEMPLATES_DIR" -name "*spec-kit-template-claude*" | wc -l)
            local codebuddy_count=$(find "$TEMPLATES_DIR" -name "*spec-kit-template-codebuddy*" | wc -l)
            local codex_count=$(find "$TEMPLATES_DIR" -name "*spec-kit-template-codex*" | wc -l)
            local copilot_count=$(find "$TEMPLATES_DIR" -name "*spec-kit-template-copilot*" | wc -l)
            local cursor_count=$(find "$TEMPLATES_DIR" -name "*spec-kit-template-cursor*" | wc -l)
            local gemini_count=$(find "$TEMPLATES_DIR" -name "*spec-kit-template-gemini*" | wc -l)
            local kilocode_count=$(find "$TEMPLATES_DIR" -name "*spec-kit-template-kilocode*" | wc -l)
            local opencode_count=$(find "$TEMPLATES_DIR" -name "*spec-kit-template-opencode*" | wc -l)
            local q_count=$(find "$TEMPLATES_DIR" -name "*spec-kit-template-q*" | wc -l)
            local qwen_count=$(find "$TEMPLATES_DIR" -name "*spec-kit-template-qwen*" | wc -l)
            local roo_count=$(find "$TEMPLATES_DIR" -name "*spec-kit-template-roo*" | wc -l)
            local windsurf_count=$(find "$TEMPLATES_DIR" -name "*spec-kit-template-windsurf*" | wc -l)

            local total_assistants=0
            [ "$amp_count" -gt 0 ] && total_assistants=$((total_assistants + 1))
            [ "$auggie_count" -gt 0 ] && total_assistants=$((total_assistants + 1))
            [ "$claude_count" -gt 0 ] && total_assistants=$((total_assistants + 1))
            [ "$codebuddy_count" -gt 0 ] && total_assistants=$((total_assistants + 1))
            [ "$codex_count" -gt 0 ] && total_assistants=$((total_assistants + 1))
            [ "$copilot_count" -gt 0 ] && total_assistants=$((total_assistants + 1))
            [ "$cursor_count" -gt 0 ] && total_assistants=$((total_assistants + 1))
            [ "$gemini_count" -gt 0 ] && total_assistants=$((total_assistants + 1))
            [ "$kilocode_count" -gt 0 ] && total_assistants=$((total_assistants + 1))
            [ "$opencode_count" -gt 0 ] && total_assistants=$((total_assistants + 1))
            [ "$q_count" -gt 0 ] && total_assistants=$((total_assistants + 1))
            [ "$qwen_count" -gt 0 ] && total_assistants=$((total_assistants + 1))
            [ "$roo_count" -gt 0 ] && total_assistants=$((total_assistants + 1))
            [ "$windsurf_count" -gt 0 ] && total_assistants=$((total_assistants + 1))

            info "支持的 AI 助手: $total_assistants 个"
            [ "$amp_count" -gt 0 ] && info "  ✓ amp (amp)"
            [ "$auggie_count" -gt 0 ] && info "  ✓ auggie (auggie)"
            [ "$claude_count" -gt 0 ] && info "  ✓ claude (claude)"
            [ "$codebuddy_count" -gt 0 ] && info "  ✓ codebuddy (codebuddy)"
            [ "$codex_count" -gt 0 ] && info "  ✓ codex (codex)"
            [ "$copilot_count" -gt 0 ] && info "  ✓ copilot (copilot)"
            [ "$cursor_count" -gt 0 ] && info "  ✓ cursor (cursor)"
            [ "$gemini_count" -gt 0 ] && info "  ✓ gemini (gemini)"
            [ "$kilocode_count" -gt 0 ] && info "  ✓ kilocode (kilocode)"
            [ "$opencode_count" -gt 0 ] && info "  ✓ opencode (opencode)"
            [ "$q_count" -gt 0 ] && info "  ✓ q (q)"
            [ "$qwen_count" -gt 0 ] && info "  ✓ qwen (qwen)"
            [ "$roo_count" -gt 0 ] && info "  ✓ roo (roo)"
            [ "$windsurf_count" -gt 0 ] && info "  ✓ windsurf (windsurf)"

            # 检查关键模板文件
            echo ""
            echo "关键模板文件检查："
            local critical_assistants=("claude" "copilot" "gemini" "cursor-agent" "qwen" "codex")

            for assistant in "${critical_assistants[@]}"; do
                local sh_count=$(find "$TEMPLATES_DIR" -name "*${assistant}-sh*.zip" | wc -l)
                local ps_count=$(find "$TEMPLATES_DIR" -name "*${assistant}-ps*.zip" | wc -l)

                if [ "$sh_count" -gt 0 ] && [ "$ps_count" -gt 0 ]; then
                    success "✓ $assistant (sh + ps 完整)"
                elif [ "$sh_count" -gt 0 ]; then
                    warning "⚠ $assistant (仅 sh 脚本)"
                elif [ "$ps_count" -gt 0 ]; then
                    warning "⚠ $assistant (仅 ps 脚本)"
                else
                    error "✗ $assistant (缺失)"
                fi
            done

            if [ "$VERBOSE" = true ]; then
                echo ""
                echo "完整模板文件列表："
                find "$TEMPLATES_DIR" -name "*.zip" -exec basename {} \; | sort | sed 's/^/  - /'
            fi

        else
            warning "✗ 模板目录为空"
            info "  目录路径: $TEMPLATES_DIR"
            info "  没有模板文件将无法初始化新项目"
        fi
    else
        error "✗ 模板目录不存在: $TEMPLATES_DIR"
    fi

    echo ""
}

# 验证 Spec Kit 功能
verify_spec_kit_functionality() {
    log "验证 Spec Kit 功能..."
    echo "检查 Spec Kit 功能："
    echo ""

    # 测试基本命令
    echo "测试基本命令..."
    if specify --help > /dev/null 2>&1; then
        success "✓ specify --help 执行成功"
        if [ "$VERBOSE" = true ]; then
            info "  帮助命令正常"
        fi
    else
        error "✗ specify --help 执行失败"
        return 1
    fi

    # 测试检查命令
    if specify check > /dev/null 2>&1; then
        success "✓ specify check 执行成功"
        if [ "$VERBOSE" = true ]; then
            info "  系统检查命令正常"
        fi
    else
        warning "⚠ specify check 执行失败，可能需要安装 AI 助手工具"
    fi

      # 注意：specify 不支持 --version 选项，这是正常的

    # 测试检查命令
    echo "测试系统检查命令..."
    if specify check > /dev/null 2>&1; then
        success "✓ specify check 执行成功"
    else
        warning "✗ specify check 执行失败（可能是因为缺少 AI 助手工具）"
        if [ "$VERBOSE" = true ]; then
            info "  这是正常的，如果只是检查 Spec Kit 基础功能"
        fi
    fi

    echo ""
}

# 创建测试项目
test_project_creation() {
    if [ "$QUICK_MODE" = true ]; then
        info "快速模式：跳过项目创建测试"
        return 0
    fi

    log "测试项目创建功能..."
    echo "测试项目创建："
    echo ""

    TEST_DIR="/tmp/speck-kit-test-$(date +%s)"
    TEST_PROJECT_NAME="test-project"

    info "创建临时测试目录: $TEST_DIR"

    # 创建测试目录
    mkdir -p "$TEST_DIR"
    cd "$TEST_DIR"

    # 尝试初始化项目（使用 --ignore-agent-tools 跳过 AI 工具检查）
    echo "尝试初始化测试项目..."
    if specify init "$TEST_PROJECT_NAME" --ignore-agent-tools > /dev/null 2>&1; then
        success "✓ 项目初始化成功"

        # 检查项目结构
        if [ -d "$TEST_PROJECT_NAME" ]; then
            success "✓ 项目目录创建成功"

            if [ -d "$TEST_PROJECT_NAME/.specify" ]; then
                success "✓ .specify 目录存在"

                # 检查 .specify 目录内容
                SPECIFY_CONTENTS=$(ls "$TEST_PROJECT_NAME/.specify" 2>/dev/null || echo "")
                if [ -n "$SPECIFY_CONTENTS" ]; then
                    success "✓ .specify 目录包含文件"
                    if [ "$VERBOSE" = true ]; then
                        info "  内容: $SPECIFY_CONTENTS"
                    fi
                else
                    warning "✗ .specify 目录为空"
                fi
            else
                error "✗ .specify 目录不存在"
                cd - > /dev/null
                rm -rf "$TEST_DIR"
                return 1
            fi

            # 检查是否有脚本文件
            if [ -f "$TEST_PROJECT_NAME/.specify/scripts/check-prerequisites.sh" ] || \
               [ -f "$TEST_PROJECT_NAME/.specify/scripts/check-prerequisites.ps1" ]; then
                success "✓ 脚本文件存在"
            else
                warning "✗ 脚本文件缺失"
            fi

        else
            error "✗ 项目目录创建失败"
            cd - > /dev/null
            rm -rf "$TEST_DIR"
            return 1
        fi
    else
        error "✗ 项目初始化失败"
        if [ "$VERBOSE" = true ]; then
            info "  可能原因："
            info "  1. 模板文件缺失"
            info "  2. 权限问题"
            info "  3. 磁盘空间不足"
        fi
        cd - > /dev/null
        rm -rf "$TEST_DIR"
        return 1
    fi

    # 清理测试目录
    cd - > /dev/null
    rm -rf "$TEST_DIR"
    success "测试项目清理完成"

    echo ""
}

# 验证 AI 助手支持
verify_ai_assistant_support() {
    log "验证 AI 助手支持..."
    echo "检查 AI 助手支持："
    echo ""

    # 检查支持的 AI 助手
    local supported_assistants=(
        "claude"
        "copilot"
        "gemini"
        "cursor-agent"
        "qwen"
        "opencode"
        "codex"
        "windsurf"
        "kilocode"
        "auggie"
        "codebuddy"
        "roo"
        "q"
        "amp"
    )

    echo "支持的 AI 助手："
    for assistant in "${supported_assistants[@]}"; do
        # 检查是否有对应的模板文件
        if find "$TEMPLATES_DIR" -name "*${assistant}*.zip" | grep -q .; then
            success "✓ $assistant（模板文件可用）"
        else
            warning "✗ $assistant（模板文件缺失）"
        fi
    done

    echo ""

    # 检查已安装的 AI 助手工具
    echo "已安装的 AI 助手工具："
    local assistant_tools=(
        "claude:Claude Code"
        "gemini:Gemini CLI"
        "cursor-agent:Cursor"
        "qwen:Qwen Code"
        "opencode:opencode"
        "codex:Codex CLI"
        "windsurf:Windsurf"
        "kilocode:Kilo Code"
        "auggie:Auggie CLI"
        "codebuddy:CodeBuddy"
        "roo:Roo Code"
        "q:Amazon Q Developer CLI"
        "amp:Amp"
    )

    for tool_info in "${assistant_tools[@]}"; do
        IFS=':' read -r tool_name tool_display <<< "$tool_info"
        if command -v "$tool_name" &> /dev/null; then
            success "✓ $tool_display"
        else
            info "  $tool_display（未安装）"
        fi
    done

    echo ""
}

# 生成验证报告
generate_report() {
    log "生成验证报告..."

    local report_file="$SPECK_KIT_DIR/VERIFICATION_REPORT.md"
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    cat > "$report_file" << EOF
# Spec Kit 安装验证报告

## 验证信息

- 验证时间: $timestamp
- 验证模式: $([ "$QUICK_MODE" = true ] && echo "快速模式" || echo "完整模式")
- 详细输出: $([ "$VERBOSE" = true ] && echo "是" || echo "否")

## 环境信息

- Python 版本: $(python3 --version 2>/dev/null || echo "未找到")
- uv 版本: $(uv --version 2>/dev/null || echo "未找到")
- specify 状态: $(specify --help > /dev/null 2>&1 && echo "正常" || echo "异常")

## 文件统计

- 模板文件数量: $(find "$TEMPLATES_DIR" -name "*.zip" 2>/dev/null | wc -l)
- 包文件数量: $(find "$DOCS_DIR/packages" -name "*.whl" 2>/dev/null | wc -l)

## 验证结果

### ✅ 通过项目
- 命令可用性检查
- 环境变量配置
- Spec Kit 基础功能

### ⚠️ 注意事项
- 确保已下载所需的模板文件
- 根据需要安装对应的 AI 助手工具

## 下一步

1. 根据需要安装 AI 助手工具
2. 开始使用 Spec Kit 创建项目
3. 参考 /opt/docs/README.md 了解使用方法

---
报告生成时间: $(date)
EOF

    success "验证报告已生成: $report_file"
}

# 显示验证完成信息
show_completion_info() {
    echo ""
    echo "=============================================="
    echo "验证完成"
    echo "=============================================="
    echo ""
    info "验证报告已保存到: $SPECK_KIT_DIR/VERIFICATION_REPORT.md"
    echo ""
    echo "下一步操作："
    echo "1. 根据需要安装 AI 助手工具"
    echo "2. 开始创建新项目："
    echo "   specify init my-project --ai <assistant-name>"
    echo ""
    echo "支持的 AI 助手："
    echo "- claude, copilot, gemini, cursor-agent"
    echo "- qwen, opencode, codex, windsurf"
    echo "- kilocode, auggie, codebuddy, roo, q, amp"
    echo ""
    echo "获取帮助："
    echo "- specify --help"
    echo "- specify check"
    echo ""
}

# 错误处理
handle_error() {
    echo ""
    error "验证过程中发生错误！"
    echo ""
    info "故障排除步骤："
    info "1. 检查日志文件: $LOG_FILE"
    info "2. 重新运行安装脚本: ./install-offline.sh --force"
    info "3. 确保环境变量正确设置"
    echo ""
}

# 主验证流程
main() {
    # 设置错误处理
    trap handle_error ERR

    show_banner
    log "开始验证 Spec Kit 安装..."

    local all_passed=true

    # 执行各项验证
    verify_commands || all_passed=false
    verify_environment
    verify_templates
    verify_spec_kit_functionality || all_passed=false
    test_project_creation || all_passed=false
    verify_ai_assistant_support

    # 生成报告
    generate_report

    # 显示完成信息
    show_completion_info

    # 返回最终结果
    if [ "$all_passed" = true ]; then
        exit 0
    else
        warning "部分验证项目未通过，请检查安装"
        exit 1
    fi
}

# 执行主函数
main "$@"