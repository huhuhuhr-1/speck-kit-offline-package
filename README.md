# Spec Kit 离线安装使用指南

## 概述

本文档提供在研发网离线环境中安装和使用 Spec Kit 的完整解决方案。Spec Kit 是一个用于规范驱动开发（Spec-Driven Development）的工具包，支持多种 AI 助手。

## 系统要求

- Python 3.11 或更高版本
- Linux/macOS/Windows 操作系统
- 约 100MB 可用磁盘空间

## 方案概述

### 离线安装策略

1. **外网准备阶段**：下载所有必要的文件和依赖包
2. **传输阶段**：将离线包传输到研发网环境
3. **内网安装阶段**：在离线环境中安装和配置
4. **验证阶段**：测试安装是否成功

### 文件结构

```
/opt/docs/
├── README.md                    # 本文档
├── offline-install-guide.md     # 离线安装详细指南
├── scripts/                     # 脚本目录
│   ├── prepare-online.sh        # 外网准备脚本
│   ├── install-offline.sh       # 研发网安装脚本
│   └── verify-install.sh        # 安装验证脚本
├── templates/                   # 模板文件目录（需要手动下载）
└── packages/                    # 离线包目录（由脚本生成）
```

## 快速开始

### 外网环境（有互联网）

```bash
# 1. 进入脚本目录
cd /opt/docs/scripts

# 2. 运行准备脚本（自动下载所有依赖和模板文件）
chmod +x prepare-online.sh
./prepare-online.sh

# 3. 脚本完成后，直接传输整个 /opt/docs 目录到研发网
# 注意：脚本会自动下载模板文件，无需手动操作
```

### 研发网环境（离线）

```bash
# 1. 传输整个 /opt/docs 目录到研发网

# 2. 进入脚本目录
cd /opt/docs/scripts

# 3. 运行安装脚本
chmod +x install-offline.sh
./install-offline.sh

# 4. 验证安装
./verify-install.sh
```

## 支持的 AI 助手

- Claude Code (`claude`)
- GitHub Copilot (`copilot`)
- Gemini CLI (`gemini`)
- Cursor (`cursor-agent`)
- Qwen Code (`qwen`)
- opencode (`opencode`)
- Codex CLI (`codex`)
- Windsurf (`windsurf`)
- Kilo Code (`kilocode`)
- Auggie CLI (`auggie`)
- CodeBuddy (`codebuddy`)
- Roo Code (`roo`)
- Amazon Q Developer CLI (`q`)
- Amp (`amp`)

## 使用方法

安装完成后，使用方法与在线版本相同：

```bash
# 检查安装
specify check

# 初始化新项目
specify init my-project --ai claude

# 在当前目录初始化
specify init . --ai claude --force

# 查看帮助
specify --help
```

## 故障排除

### 常见问题

1. **Python 版本不兼容**
   ```
   解决方案：确保使用 Python 3.11+ 版本
   ```

2. **模板文件缺失**
   ```
   解决方案：检查 /opt/docs/templates/ 目录是否包含所有必要的模板文件
   ```

3. **权限问题**
   ```
   解决方案：确保脚本有执行权限，使用 chmod +x 添加权限
   ```

4. **依赖安装失败**
   ```
   解决方案：检查 Python 环境和 uv 工具是否正确安装
   ```

### 日志和调试

- 安装日志：`/tmp/spec-kit-install.log`
- 错误信息：检查控制台输出和日志文件

## 维护和更新

### 更新离线包

当需要更新 Spec Kit 版本时：

1. 在外网环境重新运行 `prepare-online.sh`
2. 传输新的离线包到研发网
3. 重新运行安装脚本

### 清理旧版本

```bash
# 卸载旧版本
uv tool uninstall specify-cli

# 清理缓存
uv cache clean
```

## 技术支持

如遇到问题，请检查：

1. 系统要求是否满足
2. 所有步骤是否按顺序执行
3. 日志文件中的错误信息
4. 模板文件是否完整

## 附录

### A. 手动下载步骤

如果脚本无法运行，可以手动执行以下步骤：

1. **克隆仓库**
   ```bash
   git clone https://github.com/github/spec-kit.git /tmp/spec-kit-source
   ```

2. **下载依赖**
   ```bash
   cd /tmp/spec-kit-source
   uv pip lock
   uv pip download --requirements uv.lock -d /opt/docs/packages
   ```

3. **下载模板文件**
   - 访问 GitHub Releases 页面
   - 下载所有 `spec-kit-template-*-*.zip` 文件
   - 放置到 `/opt/docs/templates/` 目录

### B. 环境变量配置

```bash
# 可选：设置本地模板目录
export SPECIFY_TEMPLATE_DIR=/opt/docs/templates

# 可选：设置 Python 路径
export PATH=$HOME/.local/bin:$PATH
```

---

**版本信息**：Spec Kit v0.0.20
**文档更新**：2025-11-09
**适用环境**：离线研发网环境