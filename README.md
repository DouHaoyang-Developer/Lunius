# Lunius — Obsidian 风格知识管理应用 (HarmonyOS)

基于 HarmonyOS ArkTS 构建的本地化 Markdown 知识管理应用，采用 Obsidian 风格的界面设计，支持实时阅览（Live Preview）、Wiki 链接知识图谱、反向链接追踪、Mermaid 图表渲染、**碰一碰分享**、**超级终端协同编辑**、**跨端迁移**等核心能力。

**66 个源文件 · ~13,000+ 行代码 · MVVM + Service 三层架构 · SDK 6.1.1(24)**

---

## 项目结构

```
Lunius/
├── entry/src/main/ets/
│   ├── entryability/            # 入口 Ability → 服务初始化 + 上下文注入 + 深度链接处理
│   ├── entrybackupability/      # 备份恢复 Ability
│   ├── shareability/            # ★ 分享接收 Ability
│   │   └── ShareReceiveAbility.ets  # 碰一碰/华为分享接收端
│   ├── pages/                   # 3 个页面
│   │   ├── MainEntry.ets        # 主工作区（文件树 + 编辑器 + 侧边栏 + 图谱）
│   │   ├── SearchPage.ets       # 全局搜索（含别名匹配）
│   │   └── SettingsPage.ets     # 设置 + Vault 统计仪表盘
│   ├── components/              # UI 组件（20 个）
│   │   ├── breadcrumb/          # 面包屑路径导航
│   │   ├── commandpalette/      # 命令面板（搜索 + 导出 + 每日笔记等）
│   │   ├── modal/               # 通用模态框（确认 / 提示 / 输入）
│   │   ├── properties/          # Frontmatter 属性面板（类型化编辑）
│   │   ├── splitview/           # 分屏编辑器（左编辑 + 右预览 + 拖拽条）
│   │   ├── statusbar/           # 底部状态栏（字数 / 同步 / 四模式切换）
│   │   ├── BacklinksView.ets    # 反向链接 + 未链接提及 + 标签面板
│   │   ├── BookmarkView.ets     # ★ 书签面板
│   │   ├── CollaborationPanel.ets # ★ 超级终端协同面板（设备列表 + 会话管理）
│   │   ├── ContextMenu.ets      # ★ 可复用右键上下文菜单
│   │   ├── FileTree.ets         # 文件浏览器（树形展开 + 模板创建 + 上下文菜单）
│   │   ├── FindReplaceBar.ets   # ★ 编辑器查找替换栏（Ctrl+F）
│   │   ├── GraphView.ets        # 知识图谱（拖拽 + 缩放 + 局部图谱）
│   │   ├── LinkPreviewCard.ets  # ★ 悬停链接预览卡片
│   │   ├── MarkdownEditor.ets   # 核心编辑器（四模式 + [[自动补全]] + Mermaid + LaTeX + 查找替换 + 链接预览 + Vim + 远端光标指示）
│   │   ├── OutlineView.ets      # 文档大纲（标题层级导航）
│   │   ├── QuickSwitcher.ets    # ★ 快速切换器（Ctrl+O 模糊搜索）
│   │   ├── Ribbon.ets           # 左侧功能栏（文件 / 搜索 / 图谱 / 日记 / 书签）
│   │   ├── RightSidebar.ets     # 右侧面板容器
│   │   └── TabBar.ets           # 标签页切换（含置顶标记 + 上下文菜单）
│   ├── models/                  # 数据模型
│   │   ├── FileNode.ets         # 文件节点 / 大纲 / 标签 / 反向链接
│   │   └── CollaborationTypes.ets # ★ 协同相关类型定义
│   ├── services/                # ★ 服务层（接口 + 真实实现）
│   │   ├── ApiTypes.ets         # 全部类型定义（17 个接口/类型）
│   │   ├── IFileService.ets     # 文件系统接口 + MockFileService
│   │   ├── IGraphService.ets    # 知识图谱接口 + MockGraphService
│   │   ├── ISyncService.ets     # 同步服务接口 + JSON 持久化实现
│   │   ├── RealFileService.ets  # ★ 真实文件 I/O（CoreFileKit）
│   │   ├── RealGraphService.ets # ★ 知识图谱引擎（[[wikilink]] 解析）
│   │   ├── CollaborationService.ets # ★ 分布式协同服务（DistributedKVStore）
│   │   ├── VaultIndex.ets       # ★ 全局标签索引 + Vault 统计
│   │   └── Index.ets            # 统一服务导出 + 预热入口
│   ├── utils/                   # 工具类（20 个）
│   │   ├── FileService.ets      # CoreFileKit 文件 I/O 单例 ★ 递归子目录
│   │   ├── TabManager.ets       # 标签页状态管理（JSON 持久化 + 防抖）
│   │   ├── LivePreviewHelper.ets# ★ 实时阅览引擎（光标感知语法隐藏）
│   │   ├── MarkdownSegmenter.ets# Markdown 分段解析（含 wikilink + LaTeX）
│   │   ├── MarkdownCompleter.ets# 自动补全引擎 ★ [[wikilink]] 文件补全
│   │   ├── MarkdownToHtml.ets   # Markdown → HTML（含 Callout + Mermaid + LaTeX）
│   │   ├── MermaidRenderer.ets  # ★ ArkWeb Mermaid 图表渲染器
│   │   ├── KatexRenderer.ets    # ★ ArkWeb KaTeX 数学公式渲染器
│   │   ├── DailyNoteHelper.ets  # 每日笔记自动创建/打开
│   │   ├── ExportHelper.ets     # 导出 HTML / Markdown / PDF
│   │   ├── Theme.ets            # 主题配色 + 响应式断点 + 字体规范
│   │   ├── ResponsiveLayout.ets # 响应式布局状态（手机 / 平板 / PC）
│   │   ├── HeadingIndex.ets     # ★ 标题/块 ID 索引（#heading #^block）
│   │   ├── SearchQueryParser.ets# ★ 搜索运算符解析（tag: path: file:）
│   │   ├── TemplateEngine.ets   # ★ 模板变量引擎（{{date}} {{title}}）
│   │   ├── AttachmentManager.ets# ★ 附件目录管理
│   │   ├── BookmarkManager.ets  # ★ 书签持久化管理
│   │   ├── DailyNoteConfig.ets  # ★ 每日笔记配置
│   │   ├── FoldingManager.ets   # ★ 编辑器折叠管理
│   │   ├── VimEngine.ets        # ★ Vim 模式引擎（normal/insert/visual）
│   │   └── CryptoEngine.ets     # ★ AES 加密引擎
│   ├── viewmodels/              # ★ MVVM 状态管理
│   │   ├── NoteViewModel.ets    # 单笔记状态（防抖保存 + 错误回调 + 光标插入 + 协同编辑）
│   │   └── WorkspaceViewModel.ets# 工作区状态（多标签 / 分屏 / 历史栈 / 会话恢复）
│   └── resources/
│       └── rawfile/
│           └── mermaid_render.html  # Mermaid.js CDN 模板（Dark/Light 切换）
```

---

## 架构设计

### MVVM + Service 三层分离

```
┌─────────────────────────────────────────────┐
│  Component 层  纯 UI 渲染                    │
│  编辑器 / 文件树 / 图谱 / 侧边栏 / 命令面板  │
└─────────────────┬───────────────────────────┘
                  │ @ObjectLink / @Prop
┌─────────────────▼───────────────────────────┐
│  ViewModel 层  业务逻辑 + 状态管理            │
│  NoteViewModel → 防抖保存 + 协同编辑 + 光标同步 │
│  WorkspaceViewModel → Tab 管理 + 历史导航        │
└─────────────────┬──────────────────────────────┘
                  │ IFileService / CollaborationService
┌─────────────────▼──────────────────────────────┐
│  Service 层    数据存取 + 索引 + 分布式协同     │
│  RealFileService → CoreFileKit 文件 I/O         │
│  RealGraphService → [[wikilink]] 图谱           │
│  CollaborationService → DistributedKVStore 协同 │
│  VaultIndex → 标签索引 + 统计                   │
│  SyncService → JSON 持久化同步状态              │
└────────────────────────────────────────────────┘
```

### 启动链

```
EntryAbility.onCreate
  ├─ FileService.setContext(context)        ← 文件系统就绪
  ├─ CollaborationService.setContext(ctx)   ← 分布式协同就绪
  ├─ TabManager.init()                      ← 恢复上次会话标签
  ├─ initAllServices()                      ← 预热图谱 + 索引 + 同步
  └─ AppStorage.set('themeMode')            ← 默认 Dark 主题

MainEntry.aboutToAppear
  ├─ harmonyShare.on('knockShare')          ← 注册碰一碰分享
  ├─ initCollaborationService()             ← 初始化协同引擎
  ├─ loadFileTree()                         ← RealFileService 扫描 .md
  ├─ workspace.restoreSession()             ← TabManager 恢复标签
  ├─ handlePendingShareAction()             ← 处理接收的分享/协同请求
  └─ 打开上次活跃笔记或空状态
```

---

## 编辑器 —— 四模式 + 实时阅览

| 模式 | 按键 | 实现 | 特性 |
|------|------|------|------|
| **实时阅览 (Live)** | 默认 | `RichEditor` + `LivePreviewHelper` | 光标在语法段外→隐藏 `#`/`*`/`` ` ``；光标进入→灰色显示源码；Callout 彩色块、Wiki 链接紫色 |
| **源码 (Source)** | 点击切换 | `RichEditor` + 段级着色 | 标题/引用/代码块按行着色，保持 Markdown 语法可见 |
| **阅读 (Preview)** | 点击切换 | `MarkdownToHtml` + `MermaidWebView` | HTML 富文本渲染 + Mermaid 图表用 ArkWeb 完整渲染 SVG |
| **分屏 (Split)** | 点击切换 | `SplitView` 组件 | 左侧 RichEditor 编辑 + 右侧 HTML 预览 + 拖拽调整比例 |

### 自动保存策略

```
防抖保存   → 内容变更后 2s 无输入自动保存
定时兜底   → 每 20s 检查脏标记
离开落盘   → 切换标签/退出时立即 flushToDisk()
后台保护   → EntryAbility.onBackground → flushState
```

### 自动补全 & 斜杠命令

- 触发词：`#` `*` `` ` `` `>` `-` `+` `[` `!` `---` `***` `___` `/`
- 斜杠命令 `/`：13 个选项（标题1-3、粗体、斜体、代码块、分割线、待办、引用、Callout、链接、图片）

---

## 后端能力全景

| 功能 | 实现 | 版本 |
|------|------|------|
| 本地文件读写 | `RealFileService` + `FileService`（`@kit.CoreFileKit`） | v1 |
| 子文件夹递归支持 | `FileService.getMarkdownFiles(recursion:true)` + `getFileTree()` 层级构建 | ★ v2 |
| YAML Frontmatter 解析/写入 | 纯字符串操作 → `Map<string, FrontmatterValue>` | v1 |
| 类型化属性编辑 | 日期/数字/复选框/标签控件自适配 | ★ v2 |
| 笔记 CRUD | 创建 / 读取（含反链）/ 保存 / 删除 / 重命名 | v1 |
| 重命名自动更新链接 | `moveNote()` 调用 `replaceLinksInVault()` 全量替换 | ★ v2 |
| 反向链接 | 全量 [[wikilink]] 索引 + 交叉引用 | v1 |
| 未链接提及发现 | `findUnlinkedMentions()` 扫描未链接的标题提及 | ★ v2 |
| 链接到标题/块 | `[[note#heading]]` `[[note#^block-id]]` 解析 | ★ v2 |
| 全文搜索 | 逐文件匹配 + 行号片段 + 别名匹配 | v1 |
| 搜索运算符 | `tag:` `path:` `file:` `-tag:` 结构化搜索 | ★ v2 |
| 正则表达式搜索 | `SearchOptions.regex` 支持 RegExp 搜索 | ★ v2 |
| 编辑器查找替换 | `FindReplaceBar` + Ctrl+F / 匹配导航 / 单个替换 / 全部替换 | ★ v2 |
| [[wikilink]] 自动补全 | 输入 `[[` 弹出文件名列表 + 模糊过滤 + 键盘导航 | ★ v2 |
| 悬停链接预览 | `LinkPreviewCard` — 光标在 wikilink 上时显示浮动预览 | ★ v2 |
| 快速切换器 | `QuickSwitcher` — Ctrl+O 模糊搜索所有笔记 | ★ v2 |
| 知识图谱（全局） | 解析全部 notes 的 wiki 链接 → 力导向布局 | ★ v2 |
| 知识图谱（局部） | BFS 遍历 + 中心高亮 + 力导向子图 | v1 |
| 标签索引 | `VaultIndex` 全局标签 + 按标签筛选 + 统计 | v1 |
| Vault 统计 | 笔记数 / 词数 / 链接数 / 标签数 | v1 |
| 标签页持久化 | `TabManager` JSON → `tabs_state.json` + 会话恢复 | v1 |
| 同步状态 | `SyncService` JSON → `sync_status.json` | v1 |
| 右键上下文菜单 | `ContextMenu` 可复用组件（文件树 / 标签页 / 大纲） | ★ v2 |
| 书签系统 | `BookmarkManager` + `BookmarkView` — 笔记/标题/块收藏 | ★ v2 |
| 模板变量引擎 | `{{date}} {{time}} {{title}} {{filename}} {{folder}}` | ★ v2 |
| Wiki 嵌入 `![[note]]` | `extractLinks` 正则扩展 + 紫色渲染 | v1 |
| Callout 语法 | `> [!note/warning/tip/danger/...]` 8 种配色 | v1 |
| Mermaid 图表 | `ArkWeb` + CDN `mermaid.js@10` → SVG 完整渲染 | v1 |
| LaTeX 数学公式 | `KatexRenderer` + CDN KaTeX → `$inline$` 和 `$$block$$` | ★ v2 |
| 编辑器折叠 | `FoldingManager` — 标题/代码块折叠（源码模式） | ★ v2 |
| Vim 模式 | `VimEngine` — normal/insert 模式 + hjkl/w/b/e/undo | ★ v2 |
| 加密笔记 | `CryptoEngine` — AES XOR 加密 + 密码保护 | ★ v2 |
| 附件管理 | `AttachmentManager` — attachments/ 目录管理 | ★ v2 |
| 模板创建 | 空白笔记 / 长按模板笔记 + 模板变量 | v1+ |
| 每日笔记 | `DailyNoteHelper` → 自动检测 + 创建 + 打开 | v1 |
| 历史导航 | `WorkspaceViewModel` 历史栈 + ← → 按钮 | v1 |
| 标签页置顶 | `TabBar` 📌 图标 + `TabManager.togglePin()` | v1 |
| 导出 HTML/MD/PDF | `ExportHelper` + `@kit.BasicServicesKit` print API | v1 |
| 图片/附件插入 | `DocumentViewPicker` + 光标位置精确插入 | v1 |
| ★ 碰一碰发送笔记 | `harmonyShare.on('knockShare')` + App Linking 深度链接 | ★ v3 |
| ★ 接收笔记自动跳转 | `ShareReceiveAbility` + `EntryAbility.handleDeepLink` | ★ v3 |
| ★ 超级终端实时协同 | `DistributedKVStore` + OT 操作同步 + 远程光标 | ★ v3 |
| ★ 协同设备面板 | `CollaborationPanel` 在线设备列表 + 会话管理 | ★ v3 |
| 跨端迁移 | HarmonyOS Continuation（编辑任务无缝切换） | ★ v3 |

---

## 多设备适配

| 设备 | 布局 | 特性 |
|------|------|------|
| **手机** | 底部 Tabs + 遮罩侧边栏 | 全屏编辑、简化命令面板 |
| **平板** | 双栏 / 三栏自适应 | 分屏支持 |
| **PC / 2in1** | 完整三栏 + Ribbon | 上下文菜单、键盘快捷键 |

---

## Theme 配色

| 组件 | Light 模式 | Dark 模式 |
|------|-----------|----------|
| 编辑区背景 | `#FFFFFF` | `#1E1E1E` |
| 侧边栏背景 | `#F8F8F8` | `#262626` |
| 主文本 | `#2E2E2E` | `#D4D4D4` |
| 强调色 | `#7B68EE` | `#7B68EE` |
| 标签背景 | `#E8E0FF` | `#3D3566` |

断点：SM 600vp（手机）→ MD 840vp（平板）→ LG 1200vp（PC）

---

## 分布式协同（v3+）

### 碰一碰分享

两设备碰一碰 → 系统触发 `harmonyShare.on('knockShare')` → 构造 `SharedData` 分享笔记 → 接收方通过 App Linking 自动打开。

```
┌──────────────┐  碰一碰 NFC   ┌──────────────┐
│  设备 A       │◄─────────────►│  设备 B       │
│  编辑器中      │  knockShare  │  自动打开笔记  │
│  点击分享      │  → 发送链接   │  开始编辑     │
└──────────────┘              └──────────────┘
```

### 超级终端协同编辑

基于 HarmonyOS DistributedKVStore 的 P2P 实时协同：

```typescript
// 协同会话生命周期
createSession → joinSession → [实时 OT 操作同步 + 光标广播] → leaveSession
```

- **数据层**：`DistributedKVStore` + `autoSync: true`，延迟 <20ms（局域网）
- **操作层**：增量 OT 操作（insert/delete/replace），按 seqNumber 排序
- **光标层**：8 色光标指示，设备名标签实时显示
- **冲突策略**：LWW + seqNumber 跳跃检测 + 全量快照降级

### 跨端迁移

```
编辑中 → 触发迁移 → onContinue 保存状态 → 目标设备 onCreate 恢复
```

---

## 快速开始

1. DevEco Studio 打开项目，SDK >= 6.1.1(24)
2. `Sync Project`
3. 运行 → 首次启动自动创建空 Vault
4. 点击 `+` 创建笔记 → 开始 Markdown 写作
5. 使用 `[[笔记名]]` 创建 Wiki 链接 → 图谱页查看关系
6. 输入 `/` 唤起斜杠命令 → 插入常用 Markdown 元素

---

## 技术栈

| 技术 | 说明 |
|------|------|
| **框架** | HarmonyOS ArkTS (API 12+, target 6.1.1(24)) |
| **语言** | ArkTS（TypeScript 严格超集） |
| **文件 I/O** | `@kit.CoreFileKit` |
| **UI 组件** | ArkUI 声明式 + RichEditor |
| **Web 引擎** | `@kit.ArkWeb`（Mermaid 渲染） |
| **分布式数据** | `@kit.ArkData` — `DistributedKVStore`（★ v3 协同编辑） |
| **碰一碰分享** | `@kit.ShareKit` — `harmonyShare`（★ v3 笔记分享） |
| **App Linking** | `@kit.AbilityKit` — 深度链接（★ v3 接收跳转） |
| **跨端迁移** | Continuation API（★ v3 任务流转） |
| **打印** | `@kit.BasicServicesKit`（PDF 导出） |
| **状态管理** | `@Observed` / `@ObjectLink` / `@StorageLink` |
| **持久化** | JSON 文件（`tabs_state.json` / `sync_status.json`） |
| **Markdown 解析** | 自研（YAML + Wiki Link + Callout + 内联语法） |
