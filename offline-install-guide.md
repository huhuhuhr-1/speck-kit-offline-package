# Spec Kit 离线安装详细指南

## 目录

1. [环境准备](#环境准备)
2. [外网准备阶段](#外网准备阶段)
3. [传输阶段](#传输阶段)
4. [研发网安装阶段](#研发网安装阶段)
5. [验证测试](#验证测试)
6. [使用指南](#使用指南)
7. [故障排除](#故障排除)

## 环境准备

### 系统要求检查

在开始之前，请确认系统满足以下要求：

```bash
# 检查 Python 版本（需要 3.11+）
python3 --version

# 检查操作系统
uname -a

# 检查磁盘空间（至少需要 200MB）
df -h /opt

# 检查网络连接（仅外网环境需要）
curl -I https://github.com
```

### 权限要求

- 对 `/opt/docs` 目录的读写权限
- 能够安装 Python 包到用户目录或系统目录
- 能够执行脚本文件

## 外网准备阶段

### 步骤 1：运行准备脚本

```bash
# 进入脚本目录
cd /opt/docs/scripts

# 确保脚本有执行权限
chmod +x prepare-online.sh

# 运行准备脚本
./prepare-online.sh
```

脚本会自动执行以下操作：
1. 检查系统环境
2. 下载 Spec Kit 源码
3. 下载所有 Python 依赖包
4. 下载 uv 包管理器
5. 生成离线安装包

### 步骤 2：检查模板文件

脚本会自动尝试下载所有模板文件：

1. **自动下载过程**
   - 脚本会自动从 GitHub API 获取最新版本信息
   - 下载所有 `spec-kit-template-*-*.zip` 模板文件
   - 验证下载文件的完整性

2. **检查下载结果**
   ```bash
   # 查看下载的模板文件
   ls -la /opt/docs/templates/*.zip

   # 统计文件数量
   find /opt/docs/templates/ -name "*.zip" | wc -l
   ```

3. **如果自动下载失败**
   - 脚本会生成备用下载说明文件
   - 参考 `/opt/docs/templates/DOWNLOAD_INSTRUCTIONS.md` 手动下载
   - 常见原因：网络问题、API 访问限制、权限问题

### 推荐的模板文件列表**（根据需要选择）：
   ```
   spec-kit-template-claude-sh.zip
   spec-kit-template-claude-ps.zip
   spec-kit-template-copilot-sh.zip
   spec-kit-template-copilot-ps.zip
   spec-kit-template-gemini-sh.zip
   spec-kit-template-gemini-ps.zip
   spec-kit-template-cursor-agent-sh.zip
   spec-kit-template-cursor-agent-ps.zip
   spec-kit-template-qwen-sh.zip
   spec-kit-template-qwen-ps.zip
   spec-kit-template-opencode-sh.zip
   spec-kit-template-opencode-ps.zip
   spec-kit-template-codex-sh.zip
   spec-kit-template-codex-ps.zip
   spec-kit-template-windsurf-sh.zip
   spec-kit-template-windsurf-ps.zip
   spec-kit-template-kilocode-sh.zip
   spec-kit-template-kilocode-ps.zip
   spec-kit-template-auggie-sh.zip
   spec-kit-template-auggie-ps.zip
   spec-kit-template-codebuddy-sh.zip
   spec-kit-template-codebuddy-ps.zip
   spec-kit-template-roo-sh.zip
   spec-kit-template-roo-ps.zip
   spec-kit-template-q-sh.zip
   spec-kit-template-q-ps.zip
   spec-kit-template-amp-sh.zip
   spec-kit-template-amp-ps.zip
   ```

### 步骤 3：验证准备结果

```bash
# 检查下载的文件
ls -la /opt/docs/packages/
ls -la /opt/docs/templates/

# 检查文件完整性（可选）
cd /opt/docs/packages/
find . -name "*.whl" | wc -l  # 应该有多个 wheel 文件

cd /opt/docs/templates/
find . -name "*.zip" | wc -l   # 根据需要下载的模板数量
```

## 传输阶段

### 方案一：使用 U 盘或移动硬盘

```bash
# 1. 复制整个目录到外部存储
cp -r /opt/docs /path/to/usb/drive/

# 2. 验证复制完整性
rsync -av --progress /opt/docs/ /path/to/usb/drive/docs/
```

### 方案二：使用网络传输（如果允许）

```bash
# 1. 打包压缩
cd /opt
tar -czf spec-kit-offline.tar.gz docs/

# 2. 传输到研发网（使用允许的网络方式）
# scp spec-kit-offline.tar.gz user@research-network:/path/

# 3. 在目标机器解压
tar -xzf spec-kit-offline.tar.gz
```

### 方案三：使用光盘或 DVD

```bash
# 1. 创建 ISO 镜像
mkisofs -o spec-kit-offline.iso /opt/docs/

# 2. 刻录到光盘
#（使用光盘刻录软件）

# 3. 在研发网挂载和复制
mount /dev/cdrom /mnt
cp -r /mnt/docs /opt/
```

## 研发网安装阶段

### 步骤 1：环境检查

```bash
# 进入脚本目录
cd /opt/docs/scripts

# 检查 Python 版本
python3 --version

# 检查当前用户权限
whoami
id

# 检查磁盘空间
df -h /opt
```

### 步骤 2：运行安装脚本

```bash
# 确保脚本有执行权限
chmod +x install-offline.sh

# 运行安装脚本
./install-offline.sh
```

安装脚本会执行以下操作：
1. 检查 Python 环境
2. 安装 uv 包管理器
3. 安装 Spec Kit 及依赖
4. 配置本地模板路径
5. 设置环境变量

### 步骤 3：配置环境变量

```bash
# 添加到 ~/.bashrc 或 ~/.zshrc
echo 'export PATH=$HOME/.local/bin:$PATH' >> ~/.bashrc
echo 'export SPECIFY_TEMPLATE_DIR=/opt/docs/templates' >> ~/.bashrc

# 重新加载环境变量
source ~/.bashrc
```

## 验证测试

### 基本功能验证

```bash
# 运行验证脚本
./verify-install.sh
```

### 手动验证步骤

```bash
# 1. 检查 Spec Kit 是否安装成功
specify --version
specify --help

# 2. 检查系统工具
specify check

# 3. 测试项目初始化
mkdir -p /tmp/test-spec-kit
cd /tmp/test-spec-kit

# 使用 Claude 模板初始化项目
specify init test-project --ai claude

# 检查项目结构
ls -la test-project/
ls -la test-project/.specify/

# 4. 验证模板文件
cd test-project
ls .specify/templates/
```

### 功能测试

```bash
# 进入测试项目
cd /tmp/test-spec-kit/test-project

# 测试基本命令
specify check

# 查看可用的 slash 命令（如果有 AI 助手）
# 根据你安装的 AI 助手类型进行测试
```

## 使用指南

### 基本使用流程

```bash
# 1. 创建新项目
specify init my-new-project --ai claude

# 2. 进入项目目录
cd my-new-project

# 3. 启动 AI 助手（根据你选择的类型）
# 例如：claude, gemini, code 等

# 4. 在 AI 助手中使用 slash 命令
/speckit.constitution
/speckit.specify
/speckit.plan
/speckit.tasks
/speckit.implement
```

### 支持的 AI 助手选项

```bash
# Claude Code
specify init project --ai claude

# GitHub Copilot
specify init project --ai copilot

# Gemini CLI
specify init project --ai gemini

# Cursor
specify init project --ai cursor-agent

# 其他 AI 助手...
specify init project --ai qwen
specify init project --ai opencode
specify init project --ai codex
specify init project --ai windsurf
specify init project --ai kilocode
specify init project --ai auggie
specify init project --ai codebuddy
specify init project --ai roo
specify init project --ai q
specify init project --ai amp
```

### 脚本类型选择

```bash
# POSIX Shell (Linux/macOS)
specify init project --script sh

# PowerShell (Windows)
specify init project --script ps
```

## 故障排除

### 安装问题

#### 1. Python 版本不兼容

**症状**：
```
ERROR: This package requires Python >=3.11
```

**解决方案**：
```bash
# 安装更新的 Python 版本
# Ubuntu/Debian:
sudo apt update
sudo apt install python3.11 python3.11-venv python3.11-dev

# CentOS/RHEL:
sudo yum install python311 python311-pip python311-devel

# 或者使用 pyenv 管理多个 Python 版本
```

#### 2. 权限问题

**症状**：
```
Permission denied: '/usr/local/bin'
```

**解决方案**：
```bash
# 使用用户安装模式
export PIP_USER=true
pip install --user ./packages/*.whl

# 或者使用 sudo（不推荐）
sudo pip install ./packages/*.whl
```

#### 3. 磁盘空间不足

**症状**：
```
No space left on device
```

**解决方案**：
```bash
# 清理临时文件
sudo apt clean
pip cache purge

# 检查磁盘使用情况
df -h
du -sh /opt/docs/*
```

### 运行时问题

#### 1. 模板文件找不到

**症状**：
```
Error: No matching release asset found
```

**解决方案**：
```bash
# 检查模板文件目录
ls -la /opt/docs/templates/

# 检查环境变量
echo $SPECIFY_TEMPLATE_DIR

# 手动设置环境变量
export SPECIFY_TEMPLATE_DIR=/opt/docs/templates
```

#### 2. 命令无法找到

**症状**：
```
bash: specify: command not found
```

**解决方案**：
```bash
# 检查 PATH 环境变量
echo $PATH

# 添加 uv 工具路径到 PATH
echo 'export PATH=$HOME/.cargo/bin:$PATH' >> ~/.bashrc
echo 'export PATH=$HOME/.local/bin:$PATH' >> ~/.bashrc

# 重新加载环境变量
source ~/.bashrc
```

#### 3. 依赖包问题

**症状**：
```
ModuleNotFoundError: No module named 'typer'
```

**解决方案**：
```bash
# 重新安装依赖
cd /opt/docs/scripts
./install-offline.sh --force

# 或者手动安装
uv pip install --no-index --find-links /opt/docs/packages specify-cli
```

### 调试方法

#### 1. 查看详细日志

```bash
# 查看安装日志
tail -f /tmp/spec-kit-install.log

# 查看系统日志
journalctl -xe
```

#### 2. 手动测试

```bash
# 测试 Python 导入
python3 -c "import specify_cli; print('OK')"

# 测试 uv 工具
uv --version

# 测试 pip 工具
pip list | grep specify
```

#### 3. 环境检查

```bash
# 检查 Python 环境
python3 -c "import sys; print(sys.path)"

# 检查 uv 环境
uv pip list

# 检查系统路径
which python3
which uv
which specify
```

## 维护和更新

### 更新 Spec Kit

```bash
# 1. 在外网环境重新准备离线包
cd /opt/docs/scripts
./prepare-online.sh --update

# 2. 传输新的离线包到研发网

# 3. 在研发网更新安装
./install-offline.sh --update
```

### 备份和恢复

```bash
# 备份安装
tar -czf spec-kit-backup.tar.gz /opt/docs/

# 恢复安装
tar -xzf spec-kit-backup.tar.gz -C /
```

### 卸载

```bash
# 卸载 Spec Kit
uv tool uninstall specify-cli

# 清理文件
rm -rf /opt/docs/
```

---

**注意**：如果遇到未在本文档中列出的问题，请检查日志文件或联系技术支持。