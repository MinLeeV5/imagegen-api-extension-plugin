<p align="center">
  <img src="plugins/imagegen-api/assets/icon.png" width="144" height="144" alt="Imagegen API 图标" />
</p>

<h1 align="center">Imagegen API</h1>

<p align="center"><strong>让 Agent 用你的 API Key 生成、编辑和批量制作图片。</strong></p>

<p align="center">
  <a href="plugins/imagegen-api/plugin.json"><img src="https://img.shields.io/badge/version-1.1.0-E4A326" alt="版本 1.1.0" /></a>
  <a href="plugins/imagegen-api/skills/imagegen-api/references/image-api.md"><img src="https://img.shields.io/badge/GPT_Image-2.6-3776AB" alt="默认使用 GPT Image 2.6" /></a>
  <a href="plugins/imagegen-api/skills/imagegen-api/references/setup.md"><img src="https://img.shields.io/badge/Python-3.10%2B-3776AB" alt="Python 3.10 及以上" /></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-Apache--2.0-green" alt="Apache-2.0 许可证" /></a>
</p>

<p align="center">
  <a href="#快速开始">快速开始</a> ·
  <a href="#常用任务">常用任务</a> ·
  <a href="#模型与默认值">模型与默认值</a> ·
  <a href="#安装与默认设置">安装与默认设置</a> ·
  <a href="#进一步阅读">更多文档</a>
</p>

Imagegen API 是独立的 Codex 图片生成插件。你用自然语言描述需求、附上参考图，Agent 通过你配置的图片 API 执行任务，把原始图片保存到工作区。默认使用 GPT Image 2.6 Flare，也可选择 Sunburst 或明确指定 2.5 模型。

## 适合你吗

如果你希望在 Agent 对话中制作图片，并沿用自己的 API Key、服务地址和模型选择，可以用它。

| 你能得到什么 | 需要准备或确认什么 |
| --- | --- |
| 在同一对话中生成、编辑图片，使用参考图和制作透明素材 | 能运行本地脚本的 Agent、Python 3.10+ 和可访问图片模型的 API Key |
| 沿用已有密钥和接口，按要求选择模型、尺寸与质量 | 所选模型和参数需要你的 API 服务及账号支持 |
| 批量制作不同素材，保存原始返回图片 | 有精确尺寸或透明度要求时，核对实际图片结果 |

插件独立于系统自带的 imagegen。你仍可在需要时明确选择内置或订阅生图。

## 快速开始

以下使用支持 `codex plugin` 命令的 Codex。推荐安装 `uv`，由它自动准备脚本依赖；其他 Python 环境见[运行环境说明](plugins/imagegen-api/skills/imagegen-api/references/setup.md)。桌面端也可按 [ChatGPT Desktop 安装说明](#chatgpt-desktop)接入。

### 1. 安装插件

在终端执行：

```bash
codex plugin marketplace add MinLeeV5/imagegen-api-extension-plugin
codex plugin add imagegen-api@imagegen-api-marketplace
```

两条命令分别添加插件目录、安装插件，无需手动克隆仓库。安装后重启 Codex 应用并开启新对话，确认技能列表中出现 **Imagegen API**。

### 2. 配置 API Key

Codex 已配置 API provider 时，可以用[环境加载脚本](#从-codex-配置加载环境变量)复用其中的地址与密钥。已有图片 API 环境变量时直接沿用，也可以在运行 Agent 的环境中手动配置：

```bash
export OPENAI_API_KEY="your-api-key"
```

已有 `OPENAI_API_KEY` 或 `OPENAI_KEY` 时直接沿用；两者都有值时优先使用 `OPENAI_API_KEY`。使用兼容服务时，设置该服务提供的 `OPENAI_BASE_URL`；未设置时使用 OpenAI SDK 默认地址。

插件从进程环境读取配置，不自动加载 `.env`。在终端中设置变量只对相应环境生效；从 Dock 或开始菜单启动桌面应用时，也要确保应用执行脚本的环境能读取配置。密钥无需发送到对话中。

### 3. 生成第一张图片

向 Agent 发送：

```text
使用 $imagegen-api:imagegen-api，生成一只黄色小鸭，柔和自然光，
保存到 output/imagegen/duck.png。
```

默认请求 `gpt-image-2.6-flare`，尺寸 `auto`、质量 `medium`，输出 PNG。Agent 会检查返回图片，并给出文件位置。

希望以后直接说“生成一张图片”就优先使用本插件，可继续[设为默认生图方式](#设为默认生图方式)。

## 常用任务

在请求中说明“使用 imagegen-api 插件”，或使用完整技能名 `$imagegen-api:imagegen-api`，再描述要做的事：

| 我想做什么 | 可以这样说 |
| --- | --- |
| 从文字生成图片 | 生成一只黄色小鸭，柔和自然光，画面简洁，保存到 `output/imagegen/duck.png`。 |
| 修改已有图片 | 把这张图的背景改成日落，保留小鸭的造型、颜色和轮廓。 |
| 使用多张参考图 | 第一张图提供角色外观，第二张图提供配色，生成一张新的海报，文字为“周末出发”。 |
| 制作透明素材 | 为这只小鸭制作透明背景 PNG，保留轮廓细节。 |
| 批量生成不同素材 | 分别生成小鸭、马克杯和盆栽，风格统一，各自保存到 `output/imagegen/`。 |

编辑和参考图任务需要附上输入图片，说明每张图的用途，以及哪些内容必须保留。指定模型和参数也可以直接写进请求：

```text
使用 imagegen-api 插件，指定 gpt-image-2.6-sunburst，
生成一只黄色小鸭，横版 1536×1024，quality=xhigh。
```

## 模型与默认值

| 模型 | CLI 可用名称 | 用法 |
| --- | --- | --- |
| GPT Image 2.6 Flare | `gpt-image-2.6-flare`、`image-2.6`、`flare` | 默认模型 |
| GPT Image 2.6 Sunburst | `gpt-image-2.6-sunburst`、`sunburst` | 在请求中明确选择 |
| GPT Image 2.5 Flare | `gpt-image-2.5-flare` | 使用完整名称保留 2.5 选择 |
| GPT Image 2.5 Sunburst | `gpt-image-2.5-sunburst` | 使用完整名称保留 2.5 选择 |

默认参数为 `size=auto`、`quality=medium`、`output_format=png`。2.6 和 2.5 的 Flare / Sunburst 都支持 `xhigh`、`max` 等质量选项；选择模型不会自动提高质量或分辨率。

请求使用你指定的模型、参数和服务地址；失败时报告错误并保留这些选择。Agent 会核对明确要求的尺寸和透明效果，保留原始返回图片，按需另存缩小副本。完整校验规则见[模型与参数](plugins/imagegen-api/skills/imagegen-api/references/image-api.md)。

## 安装与默认设置

### 从 Codex 配置加载环境变量

附带的两个脚本按 `config.toml` 顶层的 `model_provider` 读取对应 provider 的 `base_url`，以及 `env_key` 指向的环境变量或 `experimental_bearer_token`，将它们加载为 `OPENAI_BASE_URL` 和 `OPENAI_API_KEY`。同时配置两种密钥来源时，优先使用 `env_key`；该变量需要已存在于运行脚本的环境中。字段含义见 [OpenAI 官方配置参考](https://learn.chatgpt.com/docs/config-file/config-reference)。

下载本仓库后，在仓库根目录执行对应平台的脚本；也可单独下载脚本后调整命令中的路径。

**macOS / Linux** · [setup-codex-env.sh](scripts/setup-codex-env.sh)

```bash
sh scripts/setup-codex-env.sh
```

默认安装到 `~/.config/codex-env/env.sh`（设置 `XDG_CONFIG_HOME` 时使用该目录），并在当前 Shell 的启动文件中加入加载区块。支持 Zsh、Bash，其他 Shell 使用 `.profile`；Zsh 的非交互命令会话也会加载。安装后新建终端或命令会话；Bash 非交互会话需要继承已加载的环境，或显式加载 `env.sh`。

**Windows** · [setup-codex-env.ps1](scripts/setup-codex-env.ps1)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup-codex-env.ps1
```

默认安装到 `%LOCALAPPDATA%\codex-env\env.ps1`，把变量保存到 Windows 当前用户环境，并在现有执行策略允许时配置 Windows PowerShell / PowerShell 7 启动文件。完成后完全退出并重开 Codex、终端及其启动器。命令中的 `Bypass` 只作用于本次安装进程；脚本保留系统执行策略。

脚本默认读取 `CODEX_HOME/config.toml`，未设置 `CODEX_HOME` 时读取 `~/.codex/config.toml`；`CODEX_ENV_CONFIG` 可指定其他文件，Windows 还支持 `-ConfigPath`。Shell 使用自定义配置路径时，后续会话也需要能读取 `CODEX_ENV_CONFIG`。

地址与密钥均完整时，加载器会更新这两个环境变量；配置缺失或不完整时保留已有值。重复安装会更新自身的加载区块，保留其他启动配置，并备份需要改动的已有启动文件。脚本支持常见的单行 TOML 字符串；API Key 从 provider 配置获取，不读取 `auth.json` 或 ChatGPT 登录凭据。

<details>
<summary>自定义目录与配置诊断</summary>

可用 `CODEX_ENV_INSTALL_DIR` 指定加载器目录，`CODEX_ENV_STARTUP_DIR` 指定启动文件目录。Windows 对应参数为 `-InstallDir`、`-StartupDir`；`-NoPersist` 跳过用户环境变量保存，`-NoProfile` 跳过启动文件修改。

默认安装位置的诊断命令如下，只检查配置加载，不调用图片 API，也不显示密钥：

```bash
CODEX_ENV_STRICT=1 sh "${XDG_CONFIG_HOME:-$HOME/.config}/codex-env/env.sh"
```

```powershell
& "$env:LOCALAPPDATA\codex-env\env.ps1" -Check
```

</details>

### 让 Agent 帮你安装

在能执行本机命令的 Agent 中复制发送以下内容。目标是 ChatGPT Desktop 时，可补充“我要在 ChatGPT Desktop 中使用”。

```text
请阅读以下仓库的 README，在本机安装 Imagegen API，并设为我的默认生图方式：
https://github.com/MinLeeV5/imagegen-api-extension-plugin

检查当前环境，按 README 选择安装流程；已有安装时核对并沿用。
按“设为默认生图方式”更新用户级 AGENTS.md，保留原有内容和内置 imagegen。
沿用已有 OPENAI_API_KEY 或 OPENAI_KEY，以及 OPENAI_BASE_URL，不要显示密钥。
缺少图片 API 环境变量时先完成安装，再按 README 说明手动配置或从 Codex provider 加载的方法。
安装验证只检查插件状态或使用 dry-run，不发起真实生图请求。
若没有 Codex CLI，按桌面端本地项目流程准备目录，并说明还需我完成的界面步骤。
最后报告安装状态、待办事项，以及如何在新对话中使用。
```

### 设为默认生图方式

插件允许自动调用。与系统 imagegen 同时可用时，可在用户级 `AGENTS.md` 追加以下偏好，保留原有内容。Codex 默认位置是 `~/.codex/AGENTS.md`；自定义 `CODEX_HOME` 时使用该目录下的 `AGENTS.md`。

```markdown
## 图片生成偏好

普通图片生成、编辑、参考图和透明图片请求，默认优先使用
$imagegen-api:imagegen-api 插件，按插件说明调用 API。
仅在我明确要求内置工具或订阅生图时，使用系统 imagegen 的内置流程。
已有 OPENAI_API_KEY 或 OPENAI_KEY 配置时，直接用于我请求的生图任务，
无需再次确认使用密钥；保留 OPENAI_BASE_URL 和明确指定的模型。
```

修改后开启新对话。安装插件本身不会修改全局偏好或系统技能；使用上面的安装指令时，Agent 会按你的要求设置偏好。

### ChatGPT Desktop

适用于提供 **Work / Codex** 模式和 **Plugins Directory（插件目录）** 入口的桌面版本。先准备插件来源，再在应用中安装：

1. **已有 Codex CLI**：执行快速开始中的 `codex plugin marketplace add MinLeeV5/imagegen-api-extension-plugin`。**没有 CLI**：克隆或下载本仓库，将包含 `.agents/` 和 `plugins/` 的仓库根目录作为 Work / Codex 本地项目。
2. 完全退出并重新打开 ChatGPT Desktop，回到相应模式或本地项目，打开插件目录。
3. 在来源选择器中选择 **Imagegen API**（`imagegen-api-marketplace`），安装并确认启用；已经通过 CLI 安装时，核对现有状态即可。
4. 确保脚本运行环境能读取 API 配置，开启新对话，按快速开始中的示例发起请求。

本仓库已包含本地插件目录清单。使用下载或克隆方式时，保留完整目录和隐藏的 `.agents/` 文件夹。没有 Work / Codex 或插件目录入口时，需要先确认桌面版本和账号是否提供这些功能。

桌面步骤依据 [OpenAI 官方插件目录说明](https://developers.openai.com/plugins/build/plugins#build-your-own-curated-plugin-list)和[本地插件安装说明](https://developers.openai.com/plugins/build/plugins#install-a-local-plugin-manually)编写；本包的安装、启用和技能发现已在 Codex CLI `0.166.0` 验证。

### 本地源码安装

需要先查看或修改源码时，可改用本地来源：

```bash
git clone https://github.com/MinLeeV5/imagegen-api-extension-plugin.git
cd imagegen-api-extension-plugin
codex plugin marketplace add .
codex plugin add imagegen-api@imagegen-api-marketplace
```

GitHub 来源和本地来源选择一种即可。检查安装状态使用 `codex plugin list --marketplace imagegen-api-marketplace`。

## 命令行使用

也可以直接运行随插件提供的 CLI。在本仓库根目录执行：

```bash
uv run --script plugins/imagegen-api/skills/imagegen-api/scripts/image_gen.py generate \
  --prompt "A small yellow duck in soft daylight" \
  --out output/imagegen/duck.png
```

追加 `--model sunburst --size 1536x1024 --quality xhigh` 可指定模型和参数；追加 `--dry-run` 只预览请求，不调用图片 API。

`generate` 用于文字生图，`edit` 用于编辑和参考图，`generate-batch` 用于 JSONL 批量任务。多张参考图、透明输出、批量覆盖参数和缩小副本等示例见 [CLI 说明](plugins/imagegen-api/skills/imagegen-api/references/cli.md)。

## 进一步阅读

- [CLI 命令与批量任务](plugins/imagegen-api/skills/imagegen-api/references/cli.md) · [模型与参数校验](plugins/imagegen-api/skills/imagegen-api/references/image-api.md)
- [运行环境、密钥与配置排查](plugins/imagegen-api/skills/imagegen-api/references/setup.md)
- 从 Codex 配置加载环境：[macOS / Linux 脚本](scripts/setup-codex-env.sh) · [Windows 脚本](scripts/setup-codex-env.ps1)
- [提示词写法](plugins/imagegen-api/skills/imagegen-api/references/prompting.md) · [示例提示词](plugins/imagegen-api/skills/imagegen-api/references/sample-prompts.md)
- [Agent 执行流程](plugins/imagegen-api/skills/imagegen-api/SKILL.md) · [本地模拟接口测试](tests/test_api_cli.py)

## 开发与维护

插件目录入口是 [`.agents/plugins/marketplace.json`](.agents/plugins/marketplace.json)，实现位于 [`plugins/imagegen-api/`](plugins/imagegen-api/)。更新版本时，同步修改 [`plugin.json`](plugins/imagegen-api/plugin.json) 与 [`.codex-plugin/plugin.json`](plugins/imagegen-api/.codex-plugin/plugin.json)，保持两份清单的公共元数据一致，并更新本 README 的版本标记。

在已安装 [requirements.txt](requirements.txt) 依赖的 Python 环境中验证：

```bash
python -m unittest discover -s tests -v
```

测试使用本机模拟接口、临时启动文件和虚构密钥，覆盖模型选择、生成、编辑、批量任务、密钥优先级、环境加载和失败处理，不调用真实图片 API。环境脚本测试不修改本机启动文件或 Windows 用户环境变量；未安装 PowerShell 时跳过对应测试，可通过 `CODEX_ENV_TEST_PWSH` 指定其可执行文件。

采用 [Apache-2.0](LICENSE) 许可证。派生来源和修改说明见 [NOTICE](NOTICE)。这是独立扩展。
