#!/bin/bash

# Speck Kit Offline Package Git 初始化脚本
# 用于初始化 Git 仓库并推送到 GitHub

set -e

# 脚本配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPECK_KIT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_FILE="/tmp/speck-kit-git-init.log"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 默认配置
REPO_URL="git@github.com:huhuhuhr-1/speck-kit-offline-package.git"
SKIP_EXISTING=false

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --repo)
            REPO_URL="$2"
            shift 2
            ;;
        --skip-existing)
            SKIP_EXISTING=true
            shift
            ;;
        --help)
            echo "用法: $0 [--repo REPO_URL] [--skip-existing] [--help]"
            echo "  --repo           指定远程仓库 URL (默认: $REPO_URL)"
            echo "  --skip-existing   如果仓库已存在则跳过初始化"
            echo "  --help           显示帮助信息"
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

# 显示横幅
show_banner() {
    echo "=============================================="
    echo "Speck Kit Offline Package Git 初始化"
    echo "=============================================="
    echo ""
}

# 检查 Git 环境
check_git_environment() {
    log "检查 Git 环境..."

    # 检查 Git 命令
    if ! command -v git &> /dev/null; then
        error "Git 未安装，请先安装 Git"
        exit 1
    fi

    # 检查 Git 配置
    if ! git config --global user.name &> /dev/null; then
        warning "Git 用户名未配置，建议先配置："
        info "  git config --global user.name \"Your Name\""
        info "  git config --global user.email \"your.email@example.com\""
        echo ""
        read -p "是否继续？(y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi

    # 检查 SSH 密钥（如果使用 SSH URL）
    if [[ "$REPO_URL" == *"git@github.com"* ]]; then
        if ! ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
            warning "GitHub SSH 认证可能未配置"
            info "请确保已配置 SSH 密钥："
            info "  1. 生成 SSH 密钥: ssh-keygen -t ed25519 -C \"your.email@example.com\""
            info "  2. 添加到 GitHub: https://github.com/settings/keys"
            info "  3. 测试连接: ssh -T git@github.com"
            echo ""
        fi
    fi

    success "Git 环境检查完成"
}

# 初始化仓库
init_repository() {
    log "初始化 Git 仓库..."

    cd "$SPECK_KIT_DIR"

    # 检查是否已经是 Git 仓库
    if [ -d ".git" ]; then
        if [ "$SKIP_EXISTING" = true ]; then
            info "Git 仓库已存在，跳过初始化"
            return
        else
            warning "Git 仓库已存在，将重新初始化"
            rm -rf .git
        fi
    fi

    # 初始化仓库
    git init
    success "Git 仓库初始化完成"
}

# 创建 .gitignore
create_gitignore() {
    log "创建 .gitignore 文件..."

    cat > "$SPECK_KIT_DIR/.gitignore" << 'EOF'
# 日志文件
*.log
/tmp/

# 临时文件
*.tmp
*.temp
*.bak
*~

# 系统文件
.DS_Store
Thumbs.db

# 编辑器文件
.vscode/
.idea/
*.swp
*.swo
*#

# Python 文件
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
env/
venv/
.env

# uv 缓存
.uv-cache/
uv-cache/

# 本地配置
.env.local
.env.*.local

# 验证报告（可选）
VERIFICATION_REPORT.md
FINAL_TEST_REPORT.md

# 安装日志
speck-kit-install.log
speck-kit-prepare.log
speck-kit-verify.log

# 备份文件
*.orig
*.rej
EOF

    success ".gitignore 文件创建完成"
}

# 添加文件到仓库
add_files() {
    log "添加文件到 Git 仓库..."

    cd "$SPECK_KIT_DIR"

    # 添加所有文件
    git add .

    # 检查添加的文件
    STAGED_FILES=$(git diff --cached --name-only)
    if [ -z "$STAGED_FILES" ]; then
        warning "没有文件被添加到暂存区"
        return 1
    fi

    FILE_COUNT=$(echo "$STAGED_FILES" | wc -l)
    success "已添加 $FILE_COUNT 个文件到暂存区"

    # 显示添加的文件列表
    if [ "${#STAGED_FILES}" -gt 0 ]; then
        info "添加的文件："
        echo "$STAGED_FILES" | sed 's/^/  - /'
    fi
}

# 创建初始提交
create_initial_commit() {
    log "创建初始提交..."

    cd "$SPECK_KIT_DIR"

    # 获取当前时间戳
    TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    # 创建提交信息
    cat > /tmp/commit_message.txt << EOF
feat: 初始化 Speck Kit Offline Package v1.0

🎉 完整的 Spec Kit 离线安装解决方案

## ✅ 功能特性

### 📦 离线安装包
- 支持 14 个 AI 助手模板
- 27 个模板文件（1.5MB）
- 完整的依赖包管理
- 企业级离线部署支持

### 🛠️ 安装脚本
- prepare-online.sh: 外网环境准备
- install-offline.sh: 研发网离线安装
- verify-install.sh: 安装验证脚本

### 🎯 支持的 AI 助手
- Claude Code (sh + ps)
- GitHub Copilot (sh + ps)
- Gemini CLI (sh + ps)
- Qwen Code (sh + ps)
- opencode (sh + ps)
- Codex CLI (sh + ps)
- Windsurf (sh + ps)
- Kilo Code (sh + ps)
- Auggie CLI (sh + ps)
- CodeBuddy (sh + ps)
- Roo Code (sh + ps)
- Amazon Q Developer CLI (sh + ps)
- Amp (sh + ps)
- Cursor (仅 sh)

### 📚 完整文档
- 详细的安装指南
- 使用说明文档
- 故障排除指南
- 验证报告模板

## 🚀 快速开始

### 外网环境准备
\`\`\`bash
cd scripts
./prepare-online.sh
\`\`\`

### 研发网环境安装
\`\`\`bash
cd scripts
./install-offline.sh
source ~/.bashrc
\`\`\`

### 验证安装
\`\`\`bash
./verify-install.sh
\`\`\`

## 📋 系统要求

- Python 3.11+
- uv 包管理器
- Linux/macOS 环境
- 100MB 磁盘空间

## 🎯 适用场景

- 企业内网环境部署
- 研发网络隔离环境
- 离线开发环境搭建
- 批量项目初始化

---
提交时间: $TIMESTAMP
🤖 Generated with Speck Kit Offline Package
EOF

    # 创建提交
    git commit -F /tmp/commit_message.txt
    rm -f /tmp/commit_message.txt

    success "初始提交创建完成"
}

# 配置远程仓库
configure_remote() {
    log "配置远程仓库..."

    cd "$SPECK_KIT_DIR"

    # 添加远程仓库
    git remote add origin "$REPO_URL"
    success "远程仓库配置完成: $REPO_URL"

    # 设置 main 分支
    git branch -M main
    success "主分支设置为 main"
}

# 推送到远程仓库
push_to_remote() {
    log "推送到远程仓库..."

    cd "$SPECK_KIT_DIR"

    # 推送并设置上游
    if git push -u origin main; then
        success "成功推送到远程仓库"
    else
        error "推送到远程仓库失败"
        info "请检查："
        info "  1. 网络连接是否正常"
        info "  2. 仓库 URL 是否正确"
        info "  3. 认证配置是否有效"
        info "  4. 仓库是否存在且有写权限"
        exit 1
    fi
}

# 显示完成信息
show_completion_info() {
    echo ""
    echo "=============================================="
    success "Git 仓库初始化完成！"
    echo "=============================================="
    echo ""
    info "仓库信息："
    info "  本地路径: $SPECK_KIT_DIR"
    info "  远程仓库: $REPO_URL"
    info "  主分支: main"
    echo ""
    info "下一步操作："
    echo "1. 访问 GitHub 仓库: $(echo "$REPO_URL" | sed 's/git@github.com:/https:\/\/github.com\//')"
    echo "2. 检查文件是否正确上传"
    echo "3. 设置仓库描述和标签"
    echo "4. 添加 README 中的使用说明"
    echo ""
    info "常用 Git 命令："
    echo "  git status                    # 查看状态"
    echo "  git add .                     # 添加所有更改"
    echo "  git commit -m \"message\"      # 提交更改"
    echo "  git push                      # 推送到远程"
    echo "  git pull                      # 拉取更改"
    echo ""
    success "🎉 Speck Kit Offline Package 已准备就绪！"
}

# 错误处理
handle_error() {
    echo ""
    error "初始化过程中发生错误！"
    echo ""
    info "故障排除步骤："
    info "1. 检查日志文件: $LOG_FILE"
    info "2. 确保 Git 配置正确"
    info "3. 验证网络连接和认证"
    info "4. 检查远程仓库权限"
    echo ""
    info "重新运行脚本："
    info "$0 --skip-existing"
    echo ""
}

# 主流程
main() {
    # 设置错误处理
    trap handle_error ERR

    show_banner
    log "开始 Git 仓库初始化..."

    check_git_environment
    init_repository
    create_gitignore
    add_files
    create_initial_commit
    configure_remote
    push_to_remote
    show_completion_info

    log "Git 仓库初始化完成"
}

# 执行主函数
main "$@"