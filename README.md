# Lunius — Obsidian 风格知识管理应用 (HarmonyOS)

基于 HarmonyOS ArkTS 构建的本地化 Markdown 知识管理应用，采用 Obsidian 风格的界面设计，支持实时阅览（Live Preview）、Wiki 链接知识图谱、反向链接追踪、Mermaid 图表渲染等核心能力。

**41 个源文件 · 7,352 行代码 · MVVM + Service 三层架构**

---

## 项目结构

```
Lunius/
├── entry/src/main/ets/
│   ├── entryability/            # 入口 Ability → 服务初始化 + 上下文注入
│   ├── entrybackupability/      # 备份恢复 Ability
│   ├── pages/                   # 3 个页面
│   │   ├── MainEntry.ets        # 主工作区（文件树 + 编辑器 + 侧边栏 + 图谱）
│   │   ├── SearchPage.ets       # 全局搜索（含别名匹配）
│   │   └── SettingsPage.ets     # 设置 + Vault 统计仪表盘
│   ├── components/              # UI 组件（15 个）
│   │   ├── breadcrumb/          # 面包屑路径导航
│   │   ├── commandpalette/      # 命令面板（搜索 + 导出 + 每日笔记等）
│   │   ├── modal/               # 通用模态框（确认 / 提示 / 输入）
│   │   ├── properties/          # Frontmatter 属性面板 + 别名展示
│   │   ├── splitview/           # 分屏编辑器（左编辑 + 右预览 + 拖拽条）
│   │   ├── statusbar/           # 底部状态栏（字数 / 同步 / 四模式切换）
│   │   ├── BacklinksView.ets    # 反向链接 + 标签面板
│   │   ├── FileTree.ets         # 文件浏览器（树形展开 + 模板创建）
│   │   ├── GraphView.ets        # 知识图谱（拖拽 + 缩放 + 局部图谱）
│   │   ├── MarkdownEditor.ets   # 核心编辑器（四模式 + 自动补全 + Mermaid）
│   │   ├── OutlineView.ets      # 文档大纲（标题层级导航）
│   │   ├── Ribbon.ets           # 左侧功能栏（文件 / 搜索 / 图谱 / 日记）
│   │   ├── RightSidebar.ets     # 右侧面板容器
│   │   └── TabBar.ets           # 标签页切换（含置顶标记）
│   ├── models/                  # 数据模型
│   │   └── FileNode.ets         # 文件节点 / 大纲 / 标签 / 反向链接
│   ├── services/                # ★ 服务层（接口 + 真实实现）
│   │   ├── ApiTypes.ets         # 全部类型定义（17 个接口/类型）
│   │   ├── IFileService.ets     # 文件系统接口 + MockFileService
│   │   ├── IGraphService.ets    # 知识图谱接口 + MockGraphService
│   │   ├── ISyncService.ets     # 同步服务接口 + JSON 持久化实现
│   │   ├── RealFileService.ets  # ★ 真实文件 I/O（CoreFileKit）
│   │   ├── RealGraphService.ets # ★ 知识图谱引擎（[[wikilink]] 解析）
│   │   ├── VaultIndex.ets       # ★ 全局标签索引 + Vault 统计
│   │   └── Index.ets            # 统一服务导出 + 预热入口
│   ├── utils/                   # 工具类（11 个）
│   │   ├── FileService.ets      # CoreFileKit 文件 I/O 单例
│   │   ├── TabManager.ets       # 标签页状态管理（JSON 持久化 + 防抖）
│   │   ├── LivePreviewHelper.ets# ★ 实时阅览引擎（光标感知语法隐藏）
│   │   ├── MarkdownSegmenter.ets# Markdown 分段解析（语法 / 内容分离）
│   │   ├── MarkdownCompleter.ets# 自动补全引擎 + 斜杠命令（13 选项）
│   │   ├── MarkdownToHtml.ets   # Markdown → HTML（含 Callout + Mermaid）
│   │   ├── MermaidRenderer.ets  # ★ ArkWeb Mermaid 图表渲染器
│   │   ├── DailyNoteHelper.ets  # 每日笔记自动创建/打开
│   │   ├── ExportHelper.ets     # 导出 HTML / Markdown / PDF
│   │   ├── Theme.ets            # 主题配色 + 响应式断点 + 字体规范
│   │   └── ResponsiveLayout.ets # 响应式布局状态（手机 / 平板 / PC）
│   ├── viewmodels/              # ★ MVVM 状态管理
│   │   ├── NoteViewModel.ets    # 单笔记状态（防抖保存 + 错误回调 + 光标插入）
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
│  NoteViewModel → 防抖保存 + 错误回调         │
│  WorkspaceViewModel → Tab 管理 + 历史导航     │
└─────────────────┬───────────────────────────┘
                  │ IFileService / IGraphService
┌─────────────────▼───────────────────────────┐
│  Service 层    数据存取 + 索引 + 外部能力     │
│  RealFileService → CoreFileKit 文件 I/O      │
│  RealGraphService → [[wikilink]] 图谱        │
│  VaultIndex → 标签索引 + 统计                │
│  SyncService → JSON 持久化同步状态           │
└─────────────────────────────────────────────┘
```

### 启动链

```
EntryAbility.onCreate
  ├─ FileService.setContext(context)     ← 文件系统就绪
  ├─ TabManager.init()                   ← 恢复上次会话标签
  ├─ initAllServices()                   ← 预热图谱 + 索引 + 同步
  └─ AppStorage.set('themeMode')         ← 默认 Dark 主题

MainEntry.aboutToAppear
  ├─ loadFileTree()                      ← RealFileService 扫描 .md
  ├─ workspace.restoreSession()          ← TabManager 恢复标签
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

| 功能 | 实现 |
|------|------|
| 本地文件读写 | `RealFileService` + `FileService`（`@kit.CoreFileKit`） |
| YAML Frontmatter 解析/写入 | 纯字符串操作 → `Map<string, FrontmatterValue>` |
| 笔记 CRUD | 创建 / 读取（含反链）/ 保存 / 删除 / 重命名 |
| 反向链接 | 全量 [[wikilink]] 索引 + 交叉引用 |
| 全文搜索 | 逐文件匹配 + 行号片段 + 别名匹配 |
| 知识图谱（全局） | 解析全部 notes 的 wiki 链接 → 节点/边 SVG |
| 知识图谱（局部） | BFS 遍历 + 中心高亮 |
| 标签索引 | `VaultIndex` 全局标签 + 按标签筛选 + 统计 |
| Vault 统计 | 笔记数 / 词数 / 链接数 / 标签数 |
| 标签页持久化 | `TabManager` JSON → `tabs_state.json` + 会话恢复 |
| 同步状态 | `SyncService` JSON → `sync_status.json` |
| Wiki 嵌入 `![[note]]` | `extractLinks` 正则扩展 + 紫色渲染 |
| Callout 语法 | `> [!note/warning/tip/danger/...]` 8 种配色 |
| Mermaid 图表 | `ArkWeb` + CDN `mermaid.js@10` → SVG 完整渲染 |
| 模板创建 | 空白笔记 / 长按模板笔记 |
| 每日笔记 | `DailyNoteHelper` → 自动检测 + 创建 + 打开 |
| 历史导航 | `WorkspaceViewModel` 历史栈 + ← → 按钮 |
| 标签页置顶 | `TabBar` 📌 图标 + `TabManager.togglePin()` |
| 导出 HTML/MD/PDF | `ExportHelper` + `@kit.BasicServicesKit` print API |
| 图片/附件插入 | `DocumentViewPicker` + 光标位置精确插入 |

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

## 快速开始

1. DevEco Studio 打开项目，SDK >= 5.0.0(12)
2. `Sync Project`
3. 运行 → 首次启动自动创建空 Vault
4. 点击 `+` 创建笔记 → 开始 Markdown 写作
5. 使用 `[[笔记名]]` 创建 Wiki 链接 → 图谱页查看关系
6. 输入 `/` 唤起斜杠命令 → 插入常用 Markdown 元素

---

## 技术栈

| 技术 | 说明 |
|------|------|
| **框架** | HarmonyOS ArkTS (API 12+) |
| **语言** | ArkTS（TypeScript 严格超集） |
| **文件 I/O** | `@kit.CoreFileKit` |
| **UI 组件** | ArkUI 声明式 + RichEditor |
| **Web 引擎** | `@kit.ArkWeb`（Mermaid 渲染） |
| **打印** | `@kit.BasicServicesKit`（PDF 导出） |
| **状态管理** | `@Observed` / `@ObjectLink` / `@StorageLink` |
| **持久化** | JSON 文件（`tabs_state.json` / `sync_status.json`） |
| **Markdown 解析** | 自研（YAML + Wiki Link + Callout + 内联语法） |
