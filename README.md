# ccswitch 工具说明

这个项目的目的，是让已经通过 `cc-switch` 维护好的供应商配置，能够被本机安装的 `codex`、`claude`、`gemini`、`opencode` 命令行工具直接复用。

核心思路不是修改这些 CLI 的源码，而是覆盖它们在 `node_global` 里的 `.cmd` / `.ps1` 启动脚本。启动时先从 `~/.cc-switch/settings.json` 和 `~/.cc-switch/cc-switch.db` 读取当前选中的 provider，再把对应的 `API Key`、环境变量、`Base URL` 注入进当前进程，然后继续调用原始 CLI。

## 项目包含什么

- `install-ccswitch-final.ps1`
  安装脚本。会备份原始启动脚本，然后写入新的包装脚本。
- `uninstall-ccswitch-final.ps1`
  卸载脚本。会把备份恢复回来，并删除安装时生成的辅助文件。
- `show_claude.py`
  调试脚本。用于查看 `claude` 的 provider、endpoint 和相关设置。
- `show_tables.py`
  调试脚本。用于打印 `cc-switch.db` 的表结构。

## 主要功能

- 让 `codex / claude / gemini / opencode` 自动读取 `cc-switch` 当前激活的供应商配置
- 自动注入数据库里保存的 `env` 和 `auth` 字段
- 自动读取对应 endpoint，并写入：
  - `OPENAI_BASE_URL`
  - `ANTHROPIC_BASE_URL`
- 安装时自动备份原始 `.cmd` / `.ps1`
- 卸载时自动恢复

## 适用场景

适合下面这种使用方式：

1. 你已经在本机安装并使用了 `cc-switch`
2. 你已经在 `cc-switch` 里维护了多个 provider
3. 你希望切换 provider 后，终端里的 `codex`、`claude`、`gemini`、`opencode` 直接跟着切换，而不是每次手动改环境变量

## 工作原理

安装脚本会做几件事：

1. 尝试定位 `node_global` 目录
2. 查找 `codex`、`claude`、`gemini`、`opencode` 的启动脚本
3. 首次安装时备份原始文件为 `*.ccswitch-backup`
4. 写入新的 `.cmd` 和 `.ps1` 包装脚本
5. 生成共享辅助脚本 `ccswitch-env.py`

真正启动 CLI 时，包装脚本会：

1. 从 `settings.json` 读取当前 app 对应的 `currentProviderXxx`
2. 从 `cc-switch.db` 的 `providers` 表读取配置
3. 从 `provider_endpoints` 表读取 endpoint
4. 把 `env`、`auth`、`OPENAI_BASE_URL`、`ANTHROPIC_BASE_URL` 注入当前进程
5. 再调用原始 CLI 或直接调用对应的 `node` 入口文件

## 使用前提

使用前请确认：

- Windows PowerShell 5.1 或更高版本
- 本机已安装 Node.js
- 本机已经能执行以下至少部分命令：`codex`、`claude`、`gemini`、`opencode`
- 用户目录下存在：
  - `%USERPROFILE%\\.cc-switch\\settings.json`
  - `%USERPROFILE%\\.cc-switch\\cc-switch.db`
- 本机已安装 Python，并且 `python` 命令可用

注意：

- `.cmd` 包装脚本固定使用 `python` 调用辅助脚本，所以没有 `python` 命令时，`cmd` 环境下注入会失效。
- `.ps1` 包装脚本会优先找 `python`，找不到时会尝试 `py`。

## 安装方法

在 PowerShell 中执行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\install-ccswitch-final.ps1"
```

安装完成后：

- 脚本会输出检测到的 `node_global` 目录
- 原始启动脚本会被备份为 `*.ccswitch-backup`
- 会生成 `ccswitch-env.py`

安装后请重启：

- 终端窗口
- IDE 内置终端

否则旧环境可能还在。

## 卸载方法

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\uninstall-ccswitch-final.ps1"
```

卸载会：

- 恢复 `.cmd` / `.ps1` 原始文件
- 删除 `ccswitch-env.py`
- 删除临时目录 `%TEMP%\\ccswitch-codex`（如果存在）

## 其他用户拿去用时，优先检查和修改这些地方

别人使用这个项目时，最需要确认的是下面几项。

### 1. `node_global` 默认路径

安装脚本和卸载脚本里都写了默认值：

```powershell
$nodeGlobalDir = "D:\Program Files\nodejs\node_global"
```

脚本虽然会尝试通过 `Get-Command` 自动探测，但如果对方机器：

- 没有把这些 CLI 加到 `PATH`
- 使用的不是这个全局安装目录
- 安装结构和你机器不同

那就需要手动改这里。

### 2. `cc-switch` 数据文件位置

当前脚本默认读取：

```powershell
$dbPath       = Join-Path $env:USERPROFILE ".cc-switch\cc-switch.db"
$settingsPath = Join-Path $env:USERPROFILE ".cc-switch\settings.json"
```

如果别人的 `cc-switch` 不在这个目录，必须改这里。

### 3. CLI 对应的 js 入口路径

安装脚本中有一段：

```powershell
$cliJsMap = @{
    'codex'    = Join-Path $nodeMod '@openai\codex\bin\codex.js'
    'claude'   = Join-Path $nodeMod '@anthropic-ai\claude-code\cli.js'
    'gemini'   = Join-Path $nodeMod '@google\gemini-cli\dist\index.js'
    'opencode' = Join-Path $nodeMod 'opencode\dist\index.js'
}
```

如果对方安装的包名、目录层级或版本结构不同，需要改这里。

### 4. 需要支持哪些 CLI

当前支持列表写死在：

```powershell
$clis = @("codex", "claude", "gemini", "opencode")
```

如果只想接管其中一部分，或者还要扩展别的命令，需要改这个数组，并补对应的 `cliJsMap`。

### 5. Python 命令可用性

如果对方机器只能用 `py`，不能用 `python`，那么：

- PowerShell 包装脚本大概率还能工作
- `.cmd` 包装脚本会失败

这种情况下，建议改 `install-ccswitch-final.ps1` 中生成 `.cmd` 的那一行，把 `python` 改成更适合对方环境的调用方式。

## 数据依赖

这个工具依赖 `cc-switch` 数据库里的两张核心表：

- `providers`
- `provider_endpoints`

其中脚本实际使用的信息包括：

- `providers.id`
- `providers.app_type`
- `providers.is_current`
- `providers.settings_config`
- `provider_endpoints.url`

`settings.json` 中还需要有类似下面这种键：

- `currentProviderCodex`
- `currentProviderClaude`
- `currentProviderGemini`
- `currentProviderOpencode`

## 调试方法

查看数据库表结构：

```powershell
python .\show_tables.py
```

查看 `claude` 当前 provider 相关数据：

```powershell
python .\show_claude.py
```

## 风险和注意事项

- 这个项目会直接覆盖全局 CLI 启动脚本，属于“侵入式安装”
- 安装前虽然会备份，但仍建议先确认目标目录
- 如果 CLI 升级后重写了自己的 `.cmd` / `.ps1`，可能需要重新执行安装脚本
- 如果 `cc-switch` 的数据库结构变化，这个脚本可能需要同步调整
- 如果某个 CLI 没有安装，安装脚本会跳过它

## 建议的使用顺序

1. 先确认 `cc-switch` 已正常工作，数据库里已有 provider 和 endpoint
2. 确认 `codex` / `claude` / `gemini` / `opencode` 已全局安装
3. 执行 `install-ccswitch-final.ps1`
4. 重启终端
5. 直接运行对应 CLI 验证是否已自动切换到当前 provider

如果要恢复原始环境，执行 `uninstall-ccswitch-final.ps1` 即可。
