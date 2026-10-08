# Contributing to Waymark / 参与贡献

Thank you for helping make Waymark calmer, safer, and more useful. Contributions should preserve its map-first design, local-data model, and honest distinction between a travel journal and a navigation or tracking app.

感谢你帮助 Waymark 变得更安静、可靠、好用。贡献应尊重它以地图为中心、本地保存数据的设计，并清楚区分“旅行记录”与“导航或轨迹追踪”。

## Before you start / 开始之前

- Search [existing issues](../../issues) before opening a new one.
- For a bug, include macOS version, Mac architecture, exact steps, expected behavior, and actual behavior.
- For a larger feature or data-format change, open an issue first so the design and migration impact can be discussed.
- Never attach a real Waymark library, personal travel history, or private photos to a public issue. Use a minimal fictional fixture.

- 新建 Issue 前，请先搜索[现有 Issue](../../issues)。
- 报告错误时，请写明 macOS 版本、Mac 架构、完整复现步骤、预期结果与实际结果。
- 较大的功能或数据格式调整，请先通过 Issue 讨论设计与迁移影响。
- 不要把真实 Waymark 资料库、个人行程或私人照片附在公开 Issue 中；请使用最小化的虚构测试数据。

## Development setup / 开发环境

Waymark requires macOS 14 or later and Apple's Command Line Tools. The downloadable release is Apple Silicon-only; source builds on Intel are currently untested.

Waymark 需要 macOS 14 或更高版本以及 Apple Command Line Tools。下载版仅支持 Apple 芯片；Intel 源码构建目前未经测试。

```bash
xcode-select --install
git clone https://github.com/Weichengphy/Waymark-Mac.git Waymark
cd Waymark
swift test
./script/build_and_run.sh
```

The project is a Swift Package with no third-party package dependencies.

项目是一个不含第三方包依赖的 Swift Package。

## Useful commands / 常用命令

| Command / 命令 | Purpose / 用途 |
| --- | --- |
| `swift test` | Run the test suite / 运行测试 |
| `./script/build_and_run.sh` | Release build and normal launch / Release 构建并普通启动 |
| `./script/build_and_run.sh --verify` | Release build and verify the app signature / Release 构建并验证 App 签名 |
| `./script/build_and_run.sh --debug` | Release build and open the executable in LLDB / Release 构建并用 LLDB 打开可执行文件 |
| `./script/build_and_run.sh --logs` | Release build, launch, and stream Waymark logs / Release 构建、启动并查看 Waymark 日志 |
| `./package.sh` or `./package.sh --build` | Build `dist/Waymark.app` / 构建应用包 |
| `./package.sh --run` | Package and launch the normal library / 打包并启动普通资料库 |
| `./package.sh --demo` | Package and launch a new isolated demo instance / 打包并启动新的独立演示实例 |
| `./package.sh --dmg` | Produce the app, versioned DMG, and SHA-256 manifest / 生成 App、带版本的 DMG 与 SHA-256 清单 |

Do not commit `.build/`, `dist/`, app bundles, DMGs, local databases, logs, or personal data. The repository's `.gitignore` covers the common cases.

请勿提交 `.build/`、`dist/`、App 包、DMG、本地数据库、日志或个人数据；仓库的 `.gitignore` 已覆盖常见情况。

## Pull requests / Pull Request 要求

Keep each pull request focused. In its description:

1. Explain the user-visible problem and the chosen behavior.
2. List the files or data formats affected.
3. Describe tests run and any manual verification.
4. Include screenshots for visible UI changes, using only the isolated demo library or fictional data.
5. Call out privacy, deletion, migration, performance, and accessibility implications.

请让每个 Pull Request 保持单一、清晰的目标，并在说明中：

1. 解释用户可见的问题与所选择的行为。
2. 列出受影响的文件或数据格式。
3. 说明已运行的测试与手动验证。
4. 涉及界面变化时附上截图，但只能使用独立演示资料库或虚构数据。
5. 明确说明隐私、删除、迁移、性能与无障碍方面的影响。

Run `swift test` before submitting. When packaging behavior changes, also build `dist/Waymark.app` and verify the normal and demo launch paths. Demo mode must remain isolated from `~/Library/Application Support/Waymark/`.

提交前请运行 `swift test`。修改打包行为时，还应构建 `dist/Waymark.app`，并验证普通模式与演示模式；演示模式必须始终与 `~/Library/Application Support/Waymark/` 隔离。

## Code and product principles / 代码与产品原则

- Prefer small, native SwiftUI and MapKit solutions over new dependencies.
- Keep persistence changes backward-compatible or provide an explicit, tested migration.
- Treat user-initiated deletion as high risk: confirm scope, write metadata safely, and never reach outside Waymark's own data directory.
- Preserve original photo bytes. User-facing edits such as dates and rotation should remain Waymark metadata unless a future feature clearly asks for an export.
- Do not add analytics, accounts, network sync, or external services without prior public design discussion and corresponding privacy documentation.
- The current app interface is Chinese. English documentation must not imply that the UI is localized into English. New interface text should follow the existing Chinese terminology; localization work should be proposed as a coherent feature.
- Trips are date-derived summaries with straight map segments, not navigation routes or recorded GPS tracks.

- 优先采用小而原生的 SwiftUI、MapKit 方案，谨慎引入依赖。
- 持久化变更应向后兼容；否则必须提供明确且经过测试的迁移方案。
- 把用户发起的删除视为高风险操作：确认范围，安全写入元数据，并且绝不越出 Waymark 自己的数据目录。
- 保持原图字节不变。日期、旋转等编辑应继续作为 Waymark 元数据，除非未来明确设计“导出修改后文件”功能。
- 未经公开设计讨论并同步更新隐私文档，请勿增加分析、账号、网络同步或外部服务。
- 当前 App 界面为中文。英文文档不应暗示界面已经英文化。新增界面文字请沿用现有中文术语；本地化应作为完整功能提出。
- 旅程是从日期推导的摘要，地图上使用直线连接，不是导航路线或 GPS 轨迹。

## Licensing / 许可证

By contributing, you agree that your contribution may be distributed under the repository's [MIT License](LICENSE). Do not submit code, media, or data that you do not have the right to redistribute.

提交贡献即表示你同意相关内容可按仓库的 [MIT License](LICENSE) 分发。请勿提交无权重新分发的代码、媒体或数据。
