# Rebased 简体中文语言包（自动化构建）

为 [Rebased](https://github.com/DetachHead/rebased)（基于 IntelliJ 平台的 Git 客户端）生成**简体中文语言包** `localization-zh.jar`，并用 GitHub Actions 自动跟随 Rebased 新版本构建、发布。

> 本仓库只包含「构建脚本 + 工作流 + 已构建的语言包」。它不是 Rebased 主仓库的 fork，不需要编译 Rebased 源码。

## 这是什么 / 原理

Rebased 基于 IntelliJ 平台，但没有内置中文。JetBrains 官方「中文语言包」插件（id `com.intellij.zh`）本质上是一堆 UI 翻译资源（`*.properties`）加一个 `META-INF/plugin.xml`，其中 `plugin.xml` 用 `<idea-version since-build until-build>` 限定它能装在哪个 build 号的 IDE 上。

因此汉化只需要三步：

1. 准备一份通用的中文语言包源 `localization-zh-source.jar`；
2. 读取目标 Rebased 发行包里的 `build.txt` / `product-info.json` 拿到 build 号（例如 `262.11879.SNAPSHOT`）；
3. 改写 `plugin.xml` 里的 `<version>` 与 `<idea-version>` 为目标 build 号，重新打包成 `localization-zh.jar`。

脚本 [`scripts/make-zh-pack.sh`](scripts/make-zh-pack.sh) 完成以上全部工作；工作流 [`.github/workflows/build-zh.yml`](.github/workflows/build-zh.yml) 在 Rebased 发布新版时自动运行并把产物发布到本仓库的 Release。

> 已验证：用本脚本对 Rebased **1.1.23** 重建的 jar，与社区维护者预编译的 jar **SHA256 完全一致**（`bd916d32…88ca4`）。

## 自动构建（GitHub Actions）

工作流 `build-zh.yml`：

- **触发**：每天定时（`cron: 0 3 * * *`）、`main` 分支 push、或手动 `workflow_dispatch`；
- **流程**：解析 Rebased 目标版本 → 若无对应产物则下载 `rebased.tar.gz` 生成 `localization-zh.jar` → 提交进 `assets/<版本>/` → 创建/更新 Release（tag `zh-<版本>`）并上传 jar。

需要 `Settings → Actions → General → Workflow permissions` 选择 **Read and write permissions**（工作流已声明 `permissions: contents: write`）。

### 手动触发并指定版本

`Actions → Build Chinese language pack → Run workflow`：

- `version`：如 `1.1.23`（留空则用 Rebased 最新版）；
- `download_url`：一般留空，会自动从 DetachHead/rebased 的 Release 解析 `rebased.tar.gz`。若官方资产改名/无法访问，可手动填入直链。

下载产物：

```text
https://github.com/xinvxueyuan/rebased-zh/releases/download/zh-<版本>/localization-zh.jar
```

## 本地手动生成（可选）

依赖：`bash`、`curl`、`tar`、`find`、`perl`、`zip`、`unzip`、`jq`（Linux 上一条命令装齐：`sudo apt-get install -y zip unzip jq perl`）。

```bash
# 方式一：直接给下载地址
bash scripts/make-zh-pack.sh --version 1.1.23 \
  --url https://github.com/DetachHead/rebased/releases/download/1.1.23/rebased.tar.gz

# 方式二：用已下载的发行包
bash scripts/make-zh-pack.sh --version 1.1.23 --tar /path/to/rebased.tar.gz
```

输出：`assets/<版本>/localization-zh.jar`。

## 安装到 Rebased

把 `localization-zh.jar` 放到 Rebased 插件目录，或直接在 IDE 里本地安装：

- **推荐（通用）**：打开 Rebased → `Settings → Plugins → ⚙ → Install Plugin from Disk…` → 选择 `localization-zh.jar` → 重启。
- **手动放置**（目录结构为 `plugins/localization-zh/lib/localization-zh.jar`）：
  - **Windows**：`%APPDATA%\JetBrains\<数据目录>\plugins\localization-zh\lib\localization-zh.jar`
    （数据目录名见 Rebased 安装目录下 `product-info.json` 的 `dataDirectoryName`，如 `IdeaIC1.1`；也可放在安装目录 `...\Rebased\plugins\...` 下）
  - **Linux**：`~/.local/share/JetBrains/<数据目录>/plugins/localization-zh/lib/localization-zh.jar`，或安装目录 `/opt/rebased/plugins/localization-zh/lib/`
  - **macOS**：`~/Library/Application Support/JetBrains/<数据目录>/plugins/localization-zh/lib/localization-zh.jar`

安装后在 **Settings → Appearance & Behavior → System Settings → Language and Region** 选择「中文（简体）」并重启。

## 注意

- 语言包必须与 Rebased 的 **build 号**匹配，版本跨度太大可能加载失败或仍显示英文；请使用与本机 Rebased 版本一致的 jar。
- `localization-zh-source.jar` 来自 JetBrains 官方中文语言包，版权归 JetBrains 所有；本项目仅做兼容性重打包，遵循其许可，仅供个人学习使用。
- Rebased 更新后如界面出现少量未翻译项属正常现象（新文案尚未被官方语言包覆盖），等待上游语言包更新后重新构建即可。

## 致谢

- [DetachHead/rebased](https://github.com/DetachHead/rebased)
- [duanluan/aur-packages](https://github.com/duanluan/aur-packages)（AUR `rebased-zh-bin` 与语言包生成脚本思路）