# Speck Kit 离线安装包

一键式 Spec Kit 离线安装解决方案，单个命令生成完整离线安装包。

## 快速操作流程

```
外网操作：./build-offline-package.sh → 生成 speck-kit-offline-installer.tar.gz
内网操作：tar -xzf speck-kit-offline-installer.tar.gz && ./install.sh
```

## 外网操作（有网络）

### 一键生成离线安装包

```bash
# 进入项目目录
cd /opt/docs/speck-kit-offline-package

# 运行构建脚本
chmod +x build-offline-package.sh
bash build-offline-package.sh

# 注意：必须使用 bash，不支持 sh
```

**脚本会自动完成：**
- 下载 Spec Kit 源码和所有依赖
- 下载 AI 助手模板文件（27个）
- 生成自包含的安装脚本
- 打包为独立的 tar.gz 文件

**输出结果：**
```
speck-kit-offline-installer.tar.gz    (约50-100MB)
```

#### 缓存加速选项

```bash
# 使用缓存加速（默认）
bash build-offline-package.sh

# 强制重新构建（忽略缓存）
bash build-offline-package.sh --force

# 清理所有缓存
bash build-offline-package.sh --clean

# 指定缓存目录
bash build-offline-package.sh --cache-dir /path/to/cache
```

**缓存效果：**
- **首次构建**：5-15分钟（正常速度）
- **后续构建**：30秒-2分钟（提升70-90%）
- **缓存位置**：`~/.speck-kit-cache/`

#### 离线模式支持

脚本支持离线模式，当无法连接到 GitHub 时：

```bash
# 离线模式（使用缓存）
bash build-offline-package.sh
# 输出：[WARN] 无法连接到 GitHub，将使用离线模式
```

**离线模式要求：**
- 必须先在联网环境运行过脚本生成缓存
- 优先使用本地缓存的源码和模板文件
- 跳过网络下载，只使用缓存内容

**使用场景：**
- 开发调试：使用缓存快速构建
- 网络不稳定：离线模式继续工作
- 缓存共享：多人共用同一个缓存目录

### 验证生成的安装包

```bash
# 检查文件大小
ls -lh speck-kit-offline-installer.tar.gz

# 检查文件内容
tar -tzf speck-kit-offline-installer.tar.gz | head -10
```

### 传输到内网

```bash
# 将单个 tar.gz 文件复制到 U 盘
cp speck-kit-offline-installer.tar.gz /media/usb/
```

## 内网操作（无网络）

### 一键安装

```bash
# 解压安装包
tar -xzf speck-kit-offline-installer.tar.gz

# 运行安装脚本
chmod +x install.sh
./install.sh
```

### 验证安装

```bash
# 检查命令是否可用
which specify
specify --help
specify check
```

### 开始使用

```bash
# 创建新项目
specify init my-project --ai claude

# 进入项目
cd my-project
specify check
```

## 支持的 AI 助手

```bash
# 可选的 AI 助手
specify init project --ai claude        # Claude Code
specify init project --ai copilot       # GitHub Copilot
specify init project --ai gemini        # Gemini CLI
specify init project --ai qwen          # Qwen Code
specify init project --ai cursor-agent  # Cursor
# ... 其他助手
```

## 故障排除

### 外网问题
- **网络连接失败**：检查是否能访问 GitHub
- **Python 版本**：需要 Python 3.11+
- **磁盘空间**：至少需要 200MB

### 内网问题
- **命令找不到**：检查 PATH 环境变量
  ```bash
  export PATH=$HOME/.local/bin:$PATH
  source ~/.bashrc
  ```
- **模板文件问题**：检查 templates 目录是否有 27+ 个 zip 文件
- **权限问题**：确保脚本有执行权限

### 调试命令
```bash
# 检查安装
which specify
specify check

# 重新安装
./install.sh
```

### Ubuntu 系统注意事项

#### 安装前准备
```bash
# 更新系统包
sudo apt update

# 安装 Python 3.11+ (如果系统版本较旧)
sudo apt install python3.11 python3.11-venv python3.11-dev python3-pip

# 安装必要工具
sudo apt install curl tar git
```

#### Ubuntu 版本支持
- ✅ Ubuntu 20.04+ (需要手动安装 Python 3.11)
- ✅ Ubuntu 22.04+ (推荐，Python 3.11+ 内置)
- ✅ Ubuntu 24.04+ (最佳支持)

#### 可能的问题和解决方案
```bash
# 如果提示 pip 版本过低
sudo python3 -m pip install --upgrade pip

# 如果虚拟环境创建失败
sudo apt install python3.11-venv

# 如果出现权限问题
sudo chown -R $USER:$USER ~/.local
```

## 版本信息

- **Spec Kit 版本**: v0.0.20
- **模板版本**: v0.0.79
- **支持 AI 助手**: 14 个
- **模板文件数**: 27 个

---

**核心流程：外网一键构建 → U盘传输 → 内网一键安装**