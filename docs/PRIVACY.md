# Privacy / 隐私说明

Last updated / 最后更新：2026-10-08

## English

### The short version

Waymark has no account system, advertising, analytics SDK, or Waymark-operated backend. Your normal library is stored locally on your Mac. The app does use Apple's online map, search, and geocoding services; “local data” does not mean the map works entirely offline.

### What Waymark stores

The normal library lives under `~/Library/Application Support/Waymark/`:

- `data.json` stores places, coordinates, categories, visits, reflections, photo metadata, and Waymark rotation metadata.
- `cities.json` stores city classifications.
- `Photos/` contains a local copy of each imported original image.

Waymark reads image capture time and, when present, GPS coordinates from photo metadata to prepare an import. Those values can be stored in `data.json`. Editing a date, caption, or rotation in Waymark does not change the stored original's pixels or EXIF metadata. Gallery previews are generated on demand and cached in memory.

Clipboard image bytes are read only after an explicit paste action. A clipboard image may be staged in a uniquely named system temporary folder while the import confirmation is open; Waymark removes that staging folder when it is no longer needed. Pasting files imports copies and does not modify the source files.

### Network access

Waymark uses Apple's MapKit and Core Location geocoding APIs for:

- map tiles and map presentation;
- place-name search;
- converting coordinates to place and city names; and
- locating a city from a typed name.

These actions can send map regions, search terms, coordinates, or place names to Apple under Apple's policies. Waymark does not send your journal or imported photos to a Waymark server because no such server exists.

The app does not request or record continuous device location. It provides no real-time GPS tracking or turn-by-turn navigation. Photo GPS metadata, if present, comes from the file you choose to import.

### Demo mode

Demo mode stores its files separately under `~/Library/Application Support/Waymark-Demo/`. It contains 10 public Portuguese landmark locations, fictional 2025 visits and notes, and three AI-generated scenic illustrations that are not landmark photographs. It does not read or modify the normal library.

### Deletion, backups, and security

Deleting a photo, place, or city inside Waymark can also delete the corresponding imported copies in Waymark's `Photos/` folder after confirmation. It does not delete the original files from which you imported. Deletions inside Waymark are not reversible by the app.

Removing the app does not automatically remove its Application Support folders. To erase all Waymark data, quit the app and remove the `Waymark` folder; remove `Waymark-Demo` separately if you used demo mode. Make a backup first if you want to preserve your journal.

Waymark does not add application-level encryption. Access is governed by your macOS account, disk encryption settings, file permissions, and backup configuration. Time Machine, cloud-backup software, or other tools configured on your Mac may copy the Waymark folder independently of the app.

For a privacy or security concern, please [open an issue](../../../issues). Avoid attaching a real library or personal photos to a public issue.

---

## 简体中文

### 简要说明

Waymark 没有账号系统、广告、分析 SDK，也没有由 Waymark 运营的后端。普通资料库保存在你的 Mac 本地。但应用会使用 Apple 的在线地图、搜索与地理编码服务；“数据保存在本地”并不等于地图可以完全离线使用。

### Waymark 保存什么

普通资料库存放在 `~/Library/Application Support/Waymark/`：

- `data.json` 保存地点、坐标、分类、到访、感受、照片信息与 Waymark 的旋转信息。
- `cities.json` 保存城市分类。
- `Photos/` 保存每张导入原图的一份本地副本。

准备导入时，Waymark 会读取照片元数据中的拍摄时间，以及照片带有的 GPS 坐标；这些值可能写入 `data.json`。在 Waymark 中修改日期、说明或旋转方向，不会改变所保存原图的像素或 EXIF。画廊预览按需生成并缓存在内存中。

只有用户明确执行粘贴操作时，Waymark 才会读取剪贴板中的图片。剪贴板图片在导入确认期间可能暂存到系统临时目录中一个随机命名的文件夹；不再需要时，Waymark 会删除该暂存目录。粘贴文件只会导入副本，不会修改源文件。

### 网络访问

Waymark 使用 Apple 的 MapKit 和 Core Location 地理编码 API 来完成：

- 地图瓦片与地图显示；
- 地点名称搜索；
- 把坐标转换为地点和城市名称；
- 根据输入的城市名定位城市。

这些操作可能会按照 Apple 的政策，把地图区域、搜索词、坐标或地点名称发送给 Apple。Waymark 不会把你的旅行记录或导入照片发送到 Waymark 服务器，因为不存在这样的服务器。

应用不会请求或记录设备的连续位置，也不提供实时 GPS 轨迹或逐向导航。如果导入照片含有 GPS 信息，该信息来自你主动选择的文件。

### 演示模式

演示模式把文件单独保存在 `~/Library/Application Support/Waymark-Demo/`。其中包含葡萄牙的 10 个公共地标位置、虚构的 2025 年到访和文字，以及三张并非景点实拍的 AI 风景示意图。演示模式不会读取或修改普通资料库。

### 删除、备份与安全

在 Waymark 内删除照片、地点或城市并确认后，也可能删除 Waymark `Photos/` 文件夹中的对应导入副本；不会删除最初用于导入的外部源文件。Waymark 自身无法撤销这些删除操作。

移除 App 不会自动删除 Application Support 中的数据。若要清除全部 Waymark 数据，请先退出应用，再删除 `Waymark` 文件夹；如使用过演示模式，还需单独删除 `Waymark-Demo`。如果希望保留旅行记录，请先备份。

Waymark 不提供应用层加密。数据访问取决于你的 macOS 账户、磁盘加密设置、文件权限和备份配置。Time Machine、云备份软件或 Mac 上配置的其他工具可能在 Waymark 之外复制这些文件。

如发现隐私或安全问题，请[提交 Issue](../../../issues)。请勿在公开 Issue 中附上真实资料库或个人照片。
