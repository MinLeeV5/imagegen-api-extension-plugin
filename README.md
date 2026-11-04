# Imagegen API

独立的 Codex 图片生成插件，使用用户自己的 API Key。默认请求 `gpt-image-2.5-flare`，也支持明确选择 `gpt-image-2.5-sunburst`。

- 支持生成、编辑、参考图、透明图片和批量任务。
- 已配置密钥时，执行用户请求的生图任务无需再次确认使用密钥。
- 优先读取 `OPENAI_API_KEY`；为空时读取 `OPENAI_KEY`。保留 `OPENAI_BASE_URL`。
- 保留用户指定的模型和参数；请求失败时报告错误，不自动换模型或生图方式。
- 保存原始返回图片；有明确尺寸要求时核对实际像素，不自动放大。

插件不会修改系统自带的 imagegen 技能。所选模型及参数能否使用，取决于用户配置的 API 服务和账号权限。

## 从 GitHub 安装

需要支持 `codex plugin` 命令的 Codex。本包已在 Codex CLI `0.166.0` 验证安装、启用和技能发现。

在终端执行以下两条命令，无需手动克隆仓库：

```bash
codex plugin marketplace add MinLeeV5/imagegen-api-extension-plugin
codex plugin add imagegen-api@imagegen-api-marketplace
```

第一条命令添加本仓库的插件目录，第二条安装 **Imagegen API**。

检查安装状态：

```bash
codex plugin list --marketplace imagegen-api-marketplace
```

安装后重启 Codex 应用并开启新对话，在技能列表选择 **Imagegen API**。完整技能名为 `$imagegen-api:imagegen-api`；也可在请求中明确说“使用 imagegen-api 插件”。

### 本地源码安装

如果想先查看或修改源码，可以克隆仓库后安装：

```bash
git clone https://github.com/MinLeeV5/imagegen-api-extension-plugin.git
cd imagegen-api-extension-plugin
codex plugin marketplace add .
codex plugin add imagegen-api@imagegen-api-marketplace
```

也可以下载仓库 ZIP，解压后进入包含本 README 的根目录，执行后两条命令。保留完整目录，包括隐藏的 `.agents` 文件夹；本地目录后续刷新时仍会用到。

GitHub 安装和本地源码安装选择一种即可。

## 在 ChatGPT Desktop 中安装

以下使用官方文档中的本地插件目录流程，适用于已提供 **Work** 或 **Codex** 模式及 **Plugins Directory（插件目录）** 入口的 ChatGPT 桌面版本。

### 已安装 Codex CLI

1. 在终端添加本仓库的插件目录：

   ```bash
   codex plugin marketplace add MinLeeV5/imagegen-api-extension-plugin
   ```

2. 完全退出并重新打开 **ChatGPT Desktop**。
3. 进入 **Work** 或 **Codex** 模式，打开 **Plugins Directory（插件目录）**。
4. 在目录来源选择器中选择 **Imagegen API**，其目录标识为 `imagegen-api-marketplace`。
5. 打开 **Imagegen API** 插件，点击 **Install（安装）**，确认插件已启用。若此前已按上面的 CLI 步骤安装，则查看现有安装状态即可。
6. 开启新对话，发送“使用 Imagegen API 插件，生成一只黄色小鸭”。运行环境和 API Key 按下节配置。

### 没有 Codex CLI

1. 从本仓库的 **Code → Download ZIP** 下载并解压，或使用 Git 克隆仓库。
2. 在 ChatGPT Desktop 的 Work/Codex 中，将解压或克隆后的**仓库根目录**作为本地项目目录。该目录应同时包含 `.agents/` 和 `plugins/`；不要只打开 `plugins/imagegen-api/` 子目录。
3. 本仓库已包含 `.agents/plugins/marketplace.json`，无需另建目录清单。完全退出并重开 ChatGPT Desktop，再回到该本地项目。
4. 按上面的第 3–6 步，在插件目录切换到 **Imagegen API** 来源并安装。

如果桌面应用没有 Work/Codex 或插件目录入口，需要先确认所用版本和账号是否提供这些功能；普通聊天页的图片生成功能不承担此插件的安装。

官方流程参考：[OpenAI 文档：自定义插件目录](https://developers.openai.com/plugins/build/plugins#build-your-own-curated-plugin-list)与[本地插件安装](https://developers.openai.com/plugins/build/plugins#install-a-local-plugin-manually)。桌面界面步骤依据官方文档编写；本仓库的安装、启用与技能发现已通过 Codex CLI 验证。

## 配置密钥和运行环境

每位使用者配置自己的 `OPENAI_API_KEY` 或 `OPENAI_KEY`，确保 Codex 或 ChatGPT Desktop 执行脚本的环境能够读取它。两者都有值时使用 `OPENAI_API_KEY`。已有配置可以直接使用，无需在对话中提交密钥。插件不自动加载 `.env` 文件。

仅在某个终端中设置环境变量，不代表从 Dock 或开始菜单启动的 ChatGPT Desktop 能读取这些变量；桌面端使用时也要确认其运行环境中已配置密钥。

兼容服务可以设置 `OPENAI_BASE_URL`；未设置时使用 OpenAI SDK 默认地址。本包不含密钥或私人服务地址。

脚本需要 Python 3.10 或更新版本。推荐安装 `uv`，技能会使用 `uv run --script` 自动准备脚本声明的依赖。首次执行需要下载依赖。没有 `uv` 时，可以在工作目录创建 Python 虚拟环境，安装本包的 `requirements.txt`；技能也包含相同的依赖说明。

## 在 Codex 中使用

```text
使用 imagegen-api 插件，生成一只黄色小鸭。
```

默认请求 `gpt-image-2.5-flare`，`size=auto`，`quality=medium`，输出 PNG。

```text
使用 imagegen-api 插件，指定 gpt-image-2.5-sunburst，生成一只黄色小鸭，
横版 1536×1024，quality=xhigh。
```

编辑时可以附上图片，说明要修改和保留的部分。失败时插件会保留所选模型、参数和接口，并说明错误。

## 直接运行脚本

在本包根目录运行默认 Flare 生成：

```bash
uv run --script plugins/imagegen-api/skills/imagegen-api/scripts/image_gen.py generate \
  --prompt "A small yellow duck in soft daylight" \
  --out output/imagegen/duck.png
```

使用 Sunburst：

```bash
uv run --script plugins/imagegen-api/skills/imagegen-api/scripts/image_gen.py generate \
  --model sunburst \
  --prompt "A small yellow duck in soft daylight" \
  --size 1536x1024 --quality xhigh \
  --out output/imagegen/duck-sunburst.png
```

追加 `--dry-run` 可以预览参数，不请求图片 API。更多用法见 [CLI 说明](plugins/imagegen-api/skills/imagegen-api/references/cli.md)。

## 分享与维护

将本仓库地址分享给其他使用者，按“从 GitHub 安装”中的两条命令即可安装。每位使用者配置自己的密钥。仓库根目录的 `.agents/plugins/marketplace.json` 是插件目录入口，插件实现位于 `plugins/imagegen-api/`。

更新插件时，同时修改两个插件清单中的版本号，保持 `plugin.json` 与 `.codex-plugin/plugin.json` 元数据一致。保留 `.agents/plugins/marketplace.json` 的目录结构。

开发验证可在已安装 `requirements.txt` 依赖的 Python 环境执行：

```bash
python -m unittest discover -s tests -v
```

这些测试使用本机模拟接口和虚构密钥，覆盖模型、编辑、批量请求、密钥优先级、缺失密钥及失败处理，不调用真实图片 API。

采用 Apache-2.0 许可证；派生来源和修改说明见 [NOTICE](NOTICE)。这是独立扩展。
