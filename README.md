# Lunius — Obsidian 风格知识管理应用 (HarmonyOS)

基于 HarmonyOS ArkTS 构建的本地化知识管理应用，采用 Obsidian 风格的界面设计，支持 Markdown 实时编辑、Wiki 链接知识图谱、反向链接追踪、多标签管理等核心能力。

## 项目结构

```
Lunius/
├── entry/src/main/ets/
│   ├── entryability/           # 入口 Ability（服务初始化 + 上下文注入）
│   ├── entrybackupability/     # 备份恢复 Ability
│   ├── pages/                  # 4 个页面
│   │   ├── MainEntry.ets       # 主工作区（文件树 + 编辑器 + 侧边栏）
│   │   ├── SearchPage.ets      # 全局搜索
│   │   ├── SettingsPage.ets    # 设置 + Vault 统计
│   │   └── Index.ets           # 首页入口
│   ├── components/             # UI 组件
│   │   ├── breadcrumb/         # 面包屑导航（路径层级）
│   │   ├── commandpalette/     # 命令面板（命令搜索 + 快捷执行）
│   │   ├── modal/              # 通用模态框（确认 / 提示 / 输入）
│   │   ├── properties/         # Frontmatter 属性面板（YAML 可视化编辑）
│   │   ├── splitview/          # 分屏编辑器（左右拖拽 + 实时预览）
│   │   ├── statusbar/          # 底部状态栏（字数 / 同步状态 / 视图切换）
│   │   ├── BacklinksView.ets   # 反向链接 + 标签面板
│   │   ├── FileTree.ets        # 文件浏览器（树形展开 + 新建笔记）
│   │   ├── GraphView.ets       # 知识图谱（鼠标拖拽 + 缩放 + 局部图谱）
│   │   ├── MarkdownEditor.ets  # Markdown 编辑器（三模式 + 自动补全 + 语法高亮）
│   │   ├── OutlineView.ets     # 文档大纲（标题层级导航）
│   │   ├── Ribbon.ets          # 左侧功能栏（支持路由跳转）
│   │   ├── RightSidebar.ets    # 右侧面板容器（大纲 + 反向链接）
│   │   └── TabBar.ets          # 标签页切换栏
│   ├── models/                 # 数据模型
│   │   └── FileNode.ets        # 文件节点 / 大纲 / 标签 / 反向链接模型
│   ├── services/               # ★ 服务层（前后端分离）
│   │   ├── ApiTypes.ets        # 全部接口类型定义
│   │   ├── IFileService.ets    # 文件系统服务接口 + MockFileService
│   │   ├── IGraphService.ets   # 知识图谱服务接口 + MockGraphService
│   │   ├── ISyncService.ets    # 同步服务接口 + SyncService（JSON 持久化）
│   │   ├── RealFileService.ets # ★ 真实文件 I/O 服务（本地 .md 文件读写）
│   │   ├── RealGraphService.ets# ★ 真实图谱引擎（[[wikilink]] 解析 + 节点/边构建）
│   │   ├── VaultIndex.ets      # ★ Vault 索引（全局标签索引 + 统计）
│   │   └── Index.ets           # 统一服务导出 + 预热入口
│   ├── utils/                  # 工具类
│   │   ├── FileService.ets     # 文件 I/O 单例（@kit.CoreFileKit 封装）
│   │   ├── TabManager.ets      # 标签页状态管理（JSON 持久化 + 防抖）
│   │   ├── MarkdownHighlighter.ets  # 语法高亮（MutableStyledString）
│   │   ├── MarkdownSegmenter.ets    # Markdown 分段解析（语法 / 内容分离）
│   │   ├── MarkdownToHtml.ets       # Markdown → HTML 转换
│   │   ├── MarkdownCompleter.ets    # 自动补全引擎
│   │   ├── Theme.ets           # 主题配色 + 响应式断点 + 字体规范
│   │   └── ResponsiveLayout.ets# 响应式布局状态（手机 / 平板 / PC）
│   └── viewmodels/             # ★ MVVM 状态管理层
│       ├── NoteViewModel.ets   # 单笔记状态（加载 / 保存 / Frontmatter / 自动保存）
│       └── WorkspaceViewModel.ets # 工作区状态（多标签 / 分屏 / 历史导航 / 会话恢复）
```

## 架构设计

### MVVM + Service 三层分离

| 层级 | 职责 | 关键文件 |
|------|------|----------|
| **Service** | 数据存取、外部 API、索引构建 | `RealFileService` / `RealGraphService` / `SyncService` / `VaultIndex` |
| **ViewModel** | 业务逻辑、状态管理、UI 无关 | `NoteViewModel` / `WorkspaceViewModel` |
| **Component** | 纯 UI 渲染、事件委托 | `MarkdownEditor` / `FileTree` / `GraphView` 等 |

### 数据流

```
文件系统 (CoreFileKit)
  └─ FileService（单例）
       └─ RealFileService（实现 IFileService）
            ├─ NoteViewModel → MarkdownEditor / PropertiesPanel
            ├─ VaultIndex（标签统计 / Vault 仪表盘）
            ├─ RealGraphService（[[wikilink]] 图谱）
            └─ TabManager（标签持久化 → tabs_state.json）

启动链:
EntryAbility.onCreate
  ├─ FileService.setContext(context)
  ├─ TabManager.init()
  └─ initAllServices() → fileTree + graphData + vaultIndex + syncStatus
```

## 后端能力一览

| 功能 | 状态 | 实现 |
|------|------|------|
| 本地文件读写（`.md`） | ✅ | `RealFileService` + `FileService`（CoreFileKit） |
| YAML Frontmatter 解析/写入 | ✅ | 纯字符串解析，输出 `Map<string, FrontmatterValue>` |
| 文件树（目录层级） | ✅ | 自动扫描 `filesDir` 下所有 `.md` 文件 |
| 笔记 CRUD | ✅ | 创建 / 读取 / 保存 / 删除 / 重命名 |
| 全文搜索 | ✅ | 逐文件内容匹配 + 行号 / 片段高亮 |
| 反向链接 | ✅ | 全量 [[wikilink]] 索引 + 交叉引用查询 |
| 知识图谱（全局） | ✅ | 解析全部 notes 的 wiki 链接，构建节点/边 |
| 知识图谱（局部） | ✅ | BFS 遍历，中心节点高亮 |
| 标签索引 | ✅ | `VaultIndex` 全局标签收集 + 按标签筛选 |
| Vault 统计 | ✅ | 总笔记数 / 词数 / 链接数 / 标签数 |
| 标签页持久化 | ✅ | `TabManager` JSON 文件存储 + 会话恢复 |
| 同步状态管理 | ✅ | `SyncService` JSON 持久化（local-only） |
| Wiki 链接解析 | ✅ | `[[笔记名]]` 语法识别 + 链接/反链双向索引 |

## Markdown 编辑器

| 模式 | 功能 |
|------|------|
| **编辑模式** | 纯文本编辑，支持自动补全触发 |
| **预览模式** | Markdown → HTML 渲染（MardownToHtml） |
| **分屏模式** | 左编辑右预览，拖拽调整比例 |

自动补全支持：标题（`#`）、粗体/斜体（`*`）、代码（`` ` ``）、引用（`>`）、列表（`-`/`1.`）、链接（`[text](url)`）、分割线（`---`）。

语法高亮基于 `MutableStyledString`，支持标题层级配色、粗体/斜体/代码/链接样式区分。

## 多设备适配

| 设备 | 布局 | 特性 |
|------|------|------|
| **手机** | 底部 Tabs + 遮罩侧边栏 | 全屏编辑、简化命令面板 |
| **平板** | 双栏 / 三栏自适应 | 分屏支持 |
| **PC / 2in1** | 完整三栏 + Ribbon | 上下文菜单、键盘快捷键 |

## 快速开始

1. 用 DevEco Studio 打开项目
2. `Sync Project`（SDK >= 5.0.0(12)）
3. 运行 → 首次启动自动创建空 Vault
4. 点击 `+` 创建笔记 → 开始 Markdown 写作
5. 使用 `[[笔记名]]` 创建 Wiki 链接 → 图谱页查看关系

## 技术栈

- **框架**: HarmonyOS ArkTS (API 12+)
- **语言**: ArkTS (TypeScript 严格超集)
- **文件 I/O**: `@kit.CoreFileKit`
- **UI 组件**: ArkUI 声明式
- **状态管理**: `@Observed` / `@ObjectLink` / `@StorageLink`
- **持久化**: JSON 文件（`tabs_state.json` / `sync_status.json`）
- **Markdown 解析**: 自研（Frontmatter YAML + Wiki Link + 内联语法）
