# Waymark 2.3.0

## English

Keep the places. Keep the feeling.

A native, local-first travel journal for macOS 14 and later. This release brings together direct map check-ins, city and trip browsing, per-visit reflections, clipboard photo import, batch photo metadata editing, and a movable, resizable image viewer with zoom and rotation.

- Download `Waymark-2.3.0-macOS-arm64.dmg` for Apple Silicon Macs.
- Verify the download against `SHA256SUMS` with `shasum -a 256 -c SHA256SUMS` in the download folder.
- Open the DMG and drag Waymark to Applications. Quit a running older copy before replacing it.
- The app uses ad-hoc signing, not Developer ID signing, and is **not Apple-notarized**. Follow the README's trust-aware first-launch guidance. A managed Mac may not permit it.
- Normal first launch starts empty. The optional demo library uses fictional visits and AI illustrations, completely separate from your own journal.
- Source builders: run `./package.sh`; Intel builds are not tested.

34 automated tests passed on the release machine. Map tiles/search need network access; the interface is currently Chinese. This is not a GPS tracker or navigation app.

## 简体中文

收藏走过的地方，也收藏当时的心情。

这是一款为 macOS 14 及以上系统设计的本地旅行手账：地图选点打卡、按城市与行程回顾、每次到访独立记录感受、粘贴导入照片、批量编辑照片信息，以及可以移动、缩放窗口并放大、旋转图片的查看器。

- Apple Silicon Mac 下载 `Waymark-2.3.0-macOS-arm64.dmg`。
- 将 DMG 与 `SHA256SUMS` 放在同一下载目录，运行 `shasum -a 256 -c SHA256SUMS` 校验。
- 打开 DMG，把 Waymark 拖入应用程序；替换旧版本前先退出旧版本。
- App 采用临时签名，**未使用 Developer ID 签名，也尚未经过 Apple 公证**。首次启动请阅读 README 的安全说明；受管理的 Mac 可能不允许启动。
- 普通首次启动是空白资料库；可选演示资料库采用虚构到访和 AI 示意图，与自己的记录完全分开。
- 源码构建运行 `./package.sh`；Intel 构建尚未测试。

本次发布已通过 34 项自动化测试。地图和搜索需要联网，应用界面目前为中文，不提供实时 GPS 追踪或导航。
