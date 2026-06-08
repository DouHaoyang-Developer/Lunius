# Lunius — Obsidian 风格知识管理应用 (HarmonyOS)

基于 HarmonyOS ArkTS 构建的本地化 Markdown 知识管理应用，采用 Obsidian 风格的界面设计，支持实时阅览（Live Preview）、Wiki 链接知识图谱、**无限画布白板**、**Bases 数据库视图**、**LQL 查询语言**、**插件框架**、**碰一碰分享**、**超级终端协同编辑**、**跨端迁移**等核心能力。

**~85 个源文件 · ~17,000 行代码 · MVVM + Service 三层架构 · SDK 6.1.1(24)**

---

## 项目结构

```
Lunius/
├── entry/src/main/ets/
│   ├── entryability/            # 入口 Ability → 服务初始化 + 插件恢复 + 深度链接处理
│   ├── entrybackupability/      # 备份恢复 Ability
│   ├── shareability/            # ★ 分享接收 Ability
│   │   └── ShareReceiveAbility.ets  # 碰一碰/华为分享接收端
│   ├── pages/                   # 3 个页面
│   │   ├── MainEntry.ets        # 主工作区（文件树 + 编辑器 + 侧边栏 + 图谱）
│   │   ├── SearchPage.ets       # 全局搜索（选项接线 + 别名匹配 + 正则）
│   │   └── SettingsPage.ets     # 设置 + Vault 统计 + ★ 插件管理
│   ├── components/              # UI 组件（28 个）
│   │   ├── breadcrumb/          # 面包屑路径导航
│   │   ├── bases/               # ★ Bases 数据库视图组件
│   │   │   ├── TableView.ets    #   表格视图（列头排序 + 数据行 + 分页）
│   │   │   ├── FilterEditor.ets #   筛选条件编辑器（属性/运算符/值）
│   │   │   └── ColumnConfigBar.ets#  列配置栏（显隐切换）
│   │   ├── canvas/              # ★ Canvas 无限画布组件
│   │   │   ├── CanvasView.ets   #   画布容器（手势路由 + 绘制模式切换）
│   │   │   ├── CanvasNode.ets   #   节点渲染（5 类型含 drawing）
│   │   │   ├── CanvasEdgeLayer.ets#  连线绘制层（贝塞尔曲线 + 箭头）
│   │   │   ├── CanvasToolbar.ets#   正常模式工具栏
│   │   │   ├── FreehandLayer.ets#   ★ 自由手绘层（压感笔刷 + 增量渲染）
│   │   │   ├── DrawingToolbar.ets#  ★ 绘制工具栏（笔刷/颜色/宽度/橡皮擦）
│   │   │   ├── InstantShapeLayer.ets#★ 一笔成形识别引擎
│   │   │   └── PenKitCard.ets   #   ★ Pen Kit 手写卡片
│   │   ├── commandpalette/      # 命令面板（搜索 + 导出 + 每日笔记等）
│   │   ├── modal/               # 通用模态框（确认 / 提示 / 输入）
│   │   ├── properties/          # ★ Frontmatter 属性面板
│   │   │   ├── PropertiesPanel.ets    # 属性面板（类型化编辑 + 点击弹出编辑框）
│   │   │   ├── PropertyEditDialog.ets # 属性编辑弹出框（类型选择器 + 值编辑器）
│   │   │   └── GlobalPropertyPanel.ets# 全局属性列表面板
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
│   │   ├── MarkdownEditor.ets   # 核心编辑器（四模式 + [[自动补全]] + Mermaid + LaTeX + 查找替换 + Vim + 远端光标）
│   │   ├── OutlineView.ets      # 文档大纲（标题层级导航）
│   │   ├── QuickSwitcher.ets    # ★ 快速切换器（Ctrl+O 模糊搜索）
│   │   ├── Ribbon.ets           # 左侧功能栏（文件 / 搜索 / 图谱 / 日记 / 书签 / ★ Bases / ★ Canvas）
│   │   ├── RightSidebar.ets     # 右侧面板容器
│   │   └── TabBar.ets           # 标签页切换（含置顶标记 + 上下文菜单）
│   ├── models/                  # 数据模型（6 个）
│   │   ├── FileNode.ets         # 文件节点 / 大纲 / 标签 / 反向链接
│   │   ├── CollaborationTypes.ets # ★ 协同相关类型定义
│   │   ├── CanvasTypes.ets      # ★ Canvas 节点/连线/画布数据类型 (JSON Canvas 1.0)
│   │   ├── DrawingTypes.ets     # ★ DrawingPath / BrushType / 颜色预设
│   │   ├── BasesTypes.ets       # ★ ColumnDef / FilterCondition / TableViewConfig
│   │   └── PluginTypes.ets      # ★ LuniusPlugin 基类 / PluginAPI / Capability
│   ├── services/                # ★ 服务层（接口 + 真实实现 · 14 个）
│   │   ├── ApiTypes.ets         # 全部类型定义（含 PropertyType/PropertySchema/PropertyUsage）
│   │   ├── IFileService.ets     # 文件系统接口 + MockFileService
│   │   ├── IGraphService.ets    # 知识图谱接口 + MockGraphService
│   │   ├── ISyncService.ets     # 同步服务接口 + JSON 持久化实现
│   │   ├── RealFileService.ets  # ★ 真实文件 I/O（CoreFileKit + YAML 解析）
│   │   ├── RealGraphService.ets # ★ 知识图谱引擎（[[wikilink]] 解析 + 力导向）
│   │   ├── CollaborationService.ets # ★ 分布式协同服务（DistributedKVStore）[已修复]
│   │   ├── VaultIndex.ets       # ★ 全局标签+属性索引 + Vault 统计
│   │   ├── PropertySchemaService.ets # ★ 属性 Schema 管理
│   │   ├── CanvasFileService.ets# ★ Canvas .canvas JSON 读写
│   │   ├── PluginManager.ets    # ★ 插件注册/启用/禁用/状态持久化
│   │   ├── PluginAPI.ets        # ★ PluginAPI 实现（命令/文件/UI 代理）
│   │   └── Index.ets            # 统一服务导出 + 预热入口 + initAllPlugins
│   ├── plugins/                 # ★ 内置插件
│   │   └── BookmarkPlugin.ets   # 书签插件（Ribbon 按钮 + 能力声明）
│   ├── utils/                   # 工具类（26 个）
│   │   ├── FileService.ets      # CoreFileKit 文件 I/O 单例 ★ 递归子目录
│   │   ├── TabManager.ets       # 标签页状态管理（JSON 持久化 + 防抖）
│   │   ├── LivePreviewHelper.ets# ★ 实时阅览引擎（光标感知语法隐藏）
│   │   ├── MarkdownSegmenter.ets# Markdown 分段解析（含 wikilink + LaTeX）
│   │   ├── MarkdownCompleter.ets# 自动补全引擎 ★ [[wikilink]] 文件补全
│   │   ├── MarkdownToHtml.ets   # Markdown → HTML（含 Callout + lql 代码块 + LQL 异步渲染）
│   │   ├── MermaidRenderer.ets  # ★ ArkWeb Mermaid 图表渲染器
│   │   ├── KatexRenderer.ets    # ★ ArkWeb KaTeX 数学公式渲染器
│   │   ├── DailyNoteHelper.ets  # 每日笔记自动创建/打开
│   │   ├── ExportHelper.ets     # 导出 HTML / Markdown / PDF
│   │   ├── Theme.ets            # 主题配色 + 响应式断点 + 字体规范
│   │   ├── ResponsiveLayout.ets # 响应式布局状态（手机 / 平板 / PC）
│   │   ├── HeadingIndex.ets     # ★ 标题/块 ID 索引（#heading #^block）
│   │   ├── SearchQueryParser.ets# ★ 搜索运算符解析（tag: path: file: property:）
│   │   ├── TemplateEngine.ets   # ★ 模板引擎（简单变量 + 异步高级模板 #if/#each/lql:/date:）
│   │   ├── TemplateParser.ets   # ★ 模板表达式解析器（{{...}} 块类型识别）
│   │   ├── TemplateExecutor.ets # ★ 模板执行器（条件/循环/日期/LQL内联）
│   │   ├── AttachmentManager.ets# ★ 附件目录管理
│   │   ├── BookmarkManager.ets  # ★ 书签持久化管理
│   │   ├── DailyNoteConfig.ets  # ★ 每日笔记配置
│   │   ├── FoldingManager.ets   # ★ 编辑器折叠管理
│   │   ├── VimEngine.ets        # ★ Vim 模式引擎（normal/insert/visual 完整三模式）
│   │   ├── CryptoEngine.ets     # ★ 加密引擎
│   │   ├── BrushEngine.ets      # ★ 画笔引擎（Catmull-Rom 平滑 + 压感映射 + 4笔刷）
│   │   ├── PalmRejection.ets    # ★ 手掌误触检测（多触点/大面积/高压力过滤）
│   │   ├── DrawingExport.ets    # ★ 图纸导出（DrawingPath → SVG / PNG）
│   │   ├── LQLTokenizer.ets     # ★ LQL 词法分析器
│   │   ├── LQLParser.ets        # ★ LQL 递归下降语法分析器
│   │   ├── LQLExecutor.ets      # ★ LQL 查询执行引擎
│   │   └── LQLRenderer.ets      # ★ LQL 结果渲染器（TABLE/LIST/TASK/CALENDAR）
│   ├── viewmodels/              # ★ MVVM 状态管理（4 个）
│   │   ├── NoteViewModel.ets    # 单笔记状态（防抖保存 + 错误回调 + 光标插入 + 协同编辑）
│   │   ├── WorkspaceViewModel.ets# 工作区状态（多标签 / 分屏 / 历史栈 / ★ openCanvas/openBasesView）
│   │   ├── CanvasViewModel.ets  # ★ 画布状态（节点/连线/手绘路径 CRUD + 绘制模式 + 撤销栈）
│   │   └── BasesViewModel.ets   # ★ 数据库视图状态（筛选引擎 + 排序引擎 + 数据加载）
│   └── resources/
│       └── rawfile/
│           └── mermaid_render.html  # Mermaid.js CDN 模板（Dark/Light 切换）
```

---

## 架构设计

### MVVM + Service 三层分离 + 插件横切层

```
┌─────────────────────────────────────────────┐
│  Component 层  纯 UI 渲染                    │
│  编辑器 / 文件树 / 图谱 / 画布 / 表格 / 侧边栏 │
└─────────────────┬───────────────────────────┘
                  │ @ObjectLink / @Prop
┌─────────────────▼───────────────────────────┐
│  ViewModel 层  业务逻辑 + 状态管理            │
│  Note / Workspace / Canvas / Bases          │
└─────────────────┬───────────────────────────┘
                  │ Service 接口
┌─────────────────▼───────────────────────────┐
│  Service 层    数据存取 + 索引 + 协同         │
│  File / Graph / VaultIndex / CanvasFile     │
│  PropertySchema / PluginManager / Collab    │
└─────────────────────────────────────────────┘
                  ↕
┌─────────────────────────────────────────────┐
│  Plugin 层    内置插件（横切）               │
│  BookmarkPlugin ···                         │
│  ↕ PluginAPI → 文件 / 命令 / UI 注入点       │
└─────────────────────────────────────────────┘
                  ↕
┌─────────────────────────────────────────────┐
│  Query 层     LQL 查询语言引擎               │
│  词法分析 → 语法分析 → 执行 → 渲染           │
└─────────────────────────────────────────────┘
```

### 启动链

```
EntryAbility.onCreate
  ├─ FileService.setContext(context)        ← 文件系统就绪
  ├─ CollaborationService.setContext(ctx)   ← 分布式协同就绪
  ├─ TabManager.init()                      ← 恢复上次会话标签
  ├─ initAllPlugins(basePath)               ← ★ 插件系统启动（注册+恢复）
  ├─ initAllServices()                      ← 预热图谱 + 索引 + 同步
  └─ AppStorage.set('themeMode')            ← 默认 Dark 主题

MainEntry.aboutToAppear
  ├─ harmonyShare.on('knockShare')          ← 注册碰一碰分享
  ├─ loadFileTree()                         ← RealFileService 扫描 .md
  ├─ workspace.restoreSession()             ← TabManager 恢复标签
  ├─ handlePendingShareAction()             ← 处理接收的分享/协同请求
  └─ 打开上次活跃笔记或空状态
```

---

## 核心功能矩阵

### 编辑器四模式 + 实时阅览

| 模式 | 按键 | 实现 | 特性 |
|------|------|------|------|
| **实时阅览 (Live)** | 默认 | `RichEditor` + `LivePreviewHelper` | 光标在语法段外→隐藏 `#`/`*`/`` ` ``；光标进入→灰色显示源码；Callout 彩色块、Wiki 链接紫色 |
| **源码 (Source)** | 点击切换 | `RichEditor` + 段级着色 | 标题/引用/代码块按行着色，保持 Markdown 语法可见 |
| **阅读 (Preview)** | 点击切换 | `MarkdownToHtml` + `MermaidWebView` | HTML 富文本渲染 + Mermaid 图表 ArkWeb + ★ LQL 代码块异步渲染 |
| **分屏 (Split)** | 点击切换 | `SplitView` 组件 | 左侧 RichEditor 编辑 + 右侧 HTML 预览 + 拖拽调整比例 |

### 自动保存策略

```
防抖保存   → 内容变更后 2s 无输入自动保存
定时兜底   → 每 20s 检查脏标记
离开落盘   → 切换标签/退出时立即 flushToDisk()
后台保护   → EntryAbility.onBackground → flushState
```

### ★ Canvas 无限画布白板

| 能力 | 说明 |
|------|------|
| **JSON Canvas 1.0** | 开放规范 `.canvas` 文件存储 |
| **5 种节点** | text / file / link / group / drawing |
| **连线系统** | 贝塞尔曲线 + 箭头 + 标签 + 颜色 |
| **无限平移缩放** | PinchGesture 缩放 + PanGesture 平移 |
| **自由手绘** | Catmull-Rom 平滑 + 4 种笔刷（钢笔/铅笔/马克笔/荧光笔） + 压感映射 |
| **橡皮擦** | 包围盒快速剔除 + 点线距精确擦除 |
| **一笔成形** | 圆度/矩形度/线性度几何识别 → 自动转标准图形 |
| **手掌误触** | 多触点 + 大面积 + 高压力三重过滤 |
| **Pen Kit 卡片** | HandwriteComponent 集成点（真机就绪） |
| **撤销/重做** | 50 层 undo/redo 栈（含节点+连线+手绘路径） |
| **SVG/PNG 导出** | DrawingPath → SVG 路径 / Canvas 渲染 |
| **绘制模式切换** | 正常 → 自由绘制 → 一笔成形 → 橡皮擦 → 正常 循环 |

### ★ Bases 数据库视图

| 能力 | 说明 |
|------|------|
| **表格视图** | 列头排序 + 数据行 + 分页 + 底栏统计 |
| **列配置** | 显隐切换 + 动态属性列扩展 |
| **筛选引擎** | 11 种运算符（equals/contains/greater_than/exists...） |
| **排序引擎** | 多级排序 + 类型感知（数值/日期/文本） |
| **筛选编辑器** | 属性选择 + 运算符 + 值输入 + AND/OR 切换 |
| **数据源** | VaultIndex 属性索引 + RealFileService 元数据 |

### ★ LQL 查询语言

```sql
-- 表格视图
TABLE title, status, priority
FROM "项目"
WHERE status = "active" AND priority > 3
SORT priority DESC
LIMIT 10

-- 列表视图
LIST file.link
FROM #tag/项目
WHERE file.mtime > date("2025-01-01")

-- 任务视图
TASK
FROM "日记" OR "会议"
WHERE !completed
SORT due ASC
```

**架构**：词法分析（状态机）→ 递归下降解析（AST）→ 执行引擎（VaultIndex 索引 + 排序截断）→ HTML 渲染（TABLE/LIST/TASK/CALENDAR）

### ★ 脚本模板引擎

| 表达式 | 说明 | 示例 |
|--------|------|------|
| `{{date}}` | 日期变量 | `{{date}}` → `2026-06-08` |
| `{{date: +7d}}` | 日期偏移 | `{{date: +7d \| format "MM-DD"}}` |
| `{{#if}}` | 条件块 | `{{#if status == "draft"}}草稿{{/if}}` |
| `{{#each}}` | 循环块 | `{{#each tags}}- #{{this}}{{/each}}` |
| `{{lql:}}` | 内联 LQL | `{{lql: TABLE title FROM "日记" LIMIT 5}}` |

### ★ 插件框架

| 能力 | 说明 |
|------|------|
| **LuniusPlugin 基类** | onLoad/onUnload/onEnable/onDisable 生命周期 |
| **PluginManager** | 注册/启用/禁用/状态持久化（`plugin_state.json`） |
| **PluginAPI** | 受限接口代理（vault/commands/ui 注入点） |
| **能力声明** | 8 种 Capability（FILE_READ/UI_RIBBON/SEARCH 等） |
| **UI 注入** | Ribbon 按钮注册表 + 命令面板注册表 |
| **插件管理** | SettingsPage 插件列表 + Switch 启用/禁用 |

### ★ Properties 增强属性系统

| 能力 | 说明 |
|------|------|
| **6 种属性类型** | TEXT / NUMBER / CHECKBOX / DATE / TAGS / LIST |
| **全局属性索引** | propertyIndex: key → value → noteIds 三级索引 |
| **属性编辑弹出框** | 类型选择器 + 按类型渲染值编辑器 |
| **全局属性面板** | vault 所有属性 + 使用频次 + 值分布 |
| **搜索操作符** | `property:status` / `property:status:draft` / `property:priority:>3` |
| **PropertySchema** | 属性定义（类型约束/默认值/选项列表），JSON 持久化 |

---

## 后端能力全景表

| 功能 | 实现 | 版本 |
|------|------|:--:|
| 本地文件读写 | `RealFileService` + `FileService`（`@kit.CoreFileKit`） | v1 |
| 子文件夹递归支持 | `FileService.getMarkdownFiles(recursion:true)` | v2 |
| YAML Frontmatter 解析/写入 | 纯字符串 → `Map<string, FrontmatterValue>` | v1 |
| **属性类型系统** | 6 种类型 + Schema 管理 | ★ v4 |
| **属性搜索操作符** | `property:key:value` / `property:key:>N` | ★ v4 |
| **全局属性索引** | VaultIndex.propertyIndex 三级索引 | ★ v4 |
| 笔记 CRUD | 创建 / 读取（含反链）/ 保存 / 删除 / 重命名 | v1 |
| 重命名自动更新链接 | `moveNote()` → `replaceLinksInVault()` 全量替换 | v2 |
| 反向链接 | 全量 [[wikilink]] 索引 + 交叉引用 | v1 |
| 未链接提及发现 | `findUnlinkedMentions()` 扫描 | v2 |
| 链接到标题/块 | `[[note#heading]]` / `[[note#^block-id]]` | v2 |
| 全文搜索 | 逐文件匹配 + 行号片段 + 别名匹配 | v1 |
| **搜索选项接线** | 仅标题/包含内容/区分大小写/正则 | ★ v3 |
| 搜索运算符 | `tag:` `path:` `file:` `-tag:` `property:` | v4 |
| 编辑器查找替换 | `FindReplaceBar` + Ctrl+F / 导航 / 替换 | v2 |
| [[wikilink]] 自动补全 | `[[` 弹出文件名列表 + 模糊过滤 | v2 |
| 悬停链接预览 | `LinkPreviewCard` 浮动预览 | v2 |
| 快速切换器 | `QuickSwitcher` Ctrl+O 模糊搜索 | v2 |
| 知识图谱（全局） | 力导向布局 + Canvas 渲染 | v2 |
| 知识图谱（局部） | BFS 遍历 + 中心高亮 | v1 |
| 标签索引 | `VaultIndex` 全局标签 + 按标签筛选 | v1 |
| Vault 统计 | 笔记数/词数/链接数/标签数 | v1 |
| 标签页持久化 | `TabManager` + `tabs_state.json` + 会话恢复 | v1 |
| 右键上下文菜单 | `ContextMenu` 可复用组件 | v2 |
| 书签系统 | `BookmarkManager` + `BookmarkView` | v2 |
| **书签插件** | 重构为 `BookmarkPlugin`（首个内置插件） | ★ v4 |
| **插件框架** | LuniusPlugin 基类 + PluginManager + PluginAPI | ★ v4 |
| **Canvas 画布** | JSON Canvas 1.0 + 5 节点 + 连线 + handraw | ★ v4 |
| **白板手绘** | 4 笔刷 + 压感 + 橡皮擦 + 一笔成形 + 手掌误触 | ★ v4 |
| **Bases 数据库** | 表格视图 + 筛选引擎 + 排序引擎 + 列配置 | ★ v4 |
| **LQL 查询语言** | TABLE/LIST/TASK/CALENDAR + FROM/WHERE/SORT | ★ v4 |
| **脚本模板** | {{#if}}/{{#each}}/{{lql:}}/{{date:offset}} | ★ v4 |
| 模板变量引擎 | `{{date}} {{time}} {{title}} {{filename}} {{folder}}` | v2 |
| Wiki 嵌入 `![[note]]` | `extractLinks` 正则 + 紫色渲染 | v1 |
| Callout 语法 | `> [!note/warning/tip/danger/...]` 8 种配色 | v1 |
| Mermaid 图表 | `ArkWeb` + CDN `mermaid.js@10` → SVG | v1 |
| LaTeX 数学公式 | `KatexRenderer` + CDN KaTeX | v2 |
| 编辑器折叠 | `FoldingManager` 标题/代码块折叠 | v2 |
| **Vim 三模式** | normal/insert/visual + dd/yy/v/V + yank | ★ v3 |
| 加密笔记 | `CryptoEngine` XOR 加密 + 密码保护 | v2 |
| 附件管理 | `AttachmentManager` attachments/ 目录 | v2 |
| 每日笔记 | `DailyNoteHelper` 自动检测 + 创建 + 打开 | v1 |
| 历史导航 | `WorkspaceViewModel` 历史栈 | v1 |
| 标签页置顶 | `TabBar` 📌 + `TabManager.togglePin()` | v1 |
| 导出 HTML/MD/PDF | `ExportHelper` + print API | v1 |
| 图片/附件插入 | `DocumentViewPicker` + 光标位置插入 | v1 |
| 碰一碰分享 | `harmonyShare.on('knockShare')` | v3 |
| 跨设备协同编辑 | `DistributedKVStore` + OT 操作 + 远程光标 [已修复] | v3 |
| 跨端迁移 | Continuation API | v3 |

---

## 多设备适配

| 设备 | 布局 | 特性 |
|------|------|------|
| **手机** | 底部 Tabs + 遮罩侧边栏 | 全屏编辑、简化命令面板、Canvas 折叠工具栏 |
| **平板** | 双栏 / 三栏自适应 | 分屏支持、Canvas DrawingToolbar 完整显示、Bases 2 列+横向滚动 |
| **PC / 2in1** | 完整三栏 + Ribbon | 上下文菜单、键盘快捷键、Vim 全模式 |

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

### 超级终端协同编辑

基于 HarmonyOS DistributedKVStore 的 P2P 实时协同：

- **数据层**：`DistributedKVStore` + `autoSync: true`，延迟 <20ms（局域网）
- **操作层**：增量 OT 操作（insert/delete/replace），按 seqNumber 排序
- **光标层**：8 色光标指示，设备名标签实时显示
- **冲突策略**：LWW + seqNumber 跳跃检测 + 全量快照降级

### 跨端迁移

```
编辑中 → 触发迁移 → onContinue 保存状态 → 目标设备 onCreate 恢复
```

---

## LQL 查询语言参考

### 语法

```sql
<输出类型> <列名>...
FROM <数据源>...
WHERE <条件>
SORT <字段> [ASC|DESC]
GROUP BY <字段>
LIMIT <数量>
```

### 输出类型

| 类型 | 说明 |
|------|------|
| `TABLE col1, col2, ...` | 表格视图（含列头） |
| `LIST` | 无序列表视图 |
| `TASK` | 复选框任务列表 |
| `CALENDAR` | 日历卡片视图 |

### 数据源

| 语法 | 含义 |
|------|------|
| `"文件夹名"` | 按路径过滤 |
| `#tag` | 按标签过滤 |
| `#tag/子标签` | 嵌套标签 |
| `FROM src1 OR src2` | 多数据源 |

### 隐式字段

`file.name` / `file.path` / `file.link` / `file.ctime` / `file.mtime` / `file.size` / `file.tags` / `file.backlinks`

---

## 快速开始

1. DevEco Studio 打开项目，SDK >= 6.1.1(24)
2. `Sync Project`
3. 运行 → 首次启动自动创建空 Vault
4. 点击 `+` 创建笔记 → 开始 Markdown 写作
5. 使用 `[[笔记名]]` 创建 Wiki 链接 → 图谱页查看关系
6. 输入 `/` 唤起斜杠命令 → 插入常用 Markdown 元素
7. 在笔记中写入 ```lql TABLE ... ``` 代码块 → 阅读模式查看动态查询结果
8. SettingsPage → 插件管理 → 启用/禁用内置插件
9. 创建 `.canvas` 画布 → 添加节点 + 自由手绘 + 连线

---

## 技术栈

| 技术 | 说明 |
|------|------|
| **框架** | HarmonyOS ArkTS (API 12+, target 6.1.1(24)) |
| **语言** | ArkTS（TypeScript 严格超集） |
| **文件 I/O** | `@kit.CoreFileKit` |
| **UI 组件** | ArkUI 声明式 + RichEditor + Canvas |
| **Web 引擎** | `@kit.ArkWeb`（Mermaid / KaTeX 渲染） |
| **分布式数据** | `@kit.ArkData` — `DistributedKVStore`（★ 协同编辑） |
| **手写笔** | `@kit.PenKit` — HandwriteComponent / InstantShapeGenerator（★ 白板） |
| **碰一碰分享** | `@kit.ShareKit` — `harmonyShare`（★ 笔记分享） |
| **App Linking** | `@kit.AbilityKit` — 深度链接（★ 接收跳转） |
| **跨端迁移** | Continuation API（★ 任务流转） |
| **打印** | `@kit.BasicServicesKit`（PDF 导出） |
| **状态管理** | `@Observed` / `@ObjectLink` / `@StorageLink` |
| **持久化** | JSON 文件（`tabs_state.json` / `plugin_state.json` / `property_schemas.json` / `.canvas`） |
| **Markdown 解析** | 自研（YAML + Wiki Link + Callout + LQL 代码块） |
| **查询引擎** | LQL — 词法分析 + 递归下降解析 + VaultIndex 加速执行 |
