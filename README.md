# Lunius

## 架构概览

```
obsidian_arkts/
├── entry/src/main/ets/
│   ├── entryability/          # 入口 Ability
│   ├── pages/                 # 3 个页面（MainEntry/Settings/Search）
│   ├── components/            # UI 组件
│   │   ├── breadcrumb/        # 面包屑导航
│   │   ├── commandpalette/    # 命令面板（Ctrl+P）
│   │   ├── modal/             # 通用模态框
│   │   ├── properties/        # Frontmatter YAML 属性面板
│   │   ├── splitview/         # 分屏编辑器
│   │   ├── statusbar/         # 底部状态栏
│   │   ├── BacklinksView.ets
│   │   ├── FileTree.ets       # 支持 PC 多窗口上下文菜单
│   │   ├── GraphView.ets
│   │   ├── MarkdownEditor.ets # 集成 VM、面包屑、状态栏、分屏
│   │   ├── OutlineView.ets
│   │   ├── Ribbon.ets         # 支持 router 跳转
│   │   ├── RightSidebar.ets
│   │   └── TabBar.ets
│   ├── models/                # 数据模型
│   ├── services/              # ★ 前后端分离服务层
│   │   ├── ApiTypes.ets       # 接口类型定义
│   │   ├── IFileService.ets   # 文件系统服务 + Mock 实现
│   │   ├── IGraphService.ets  # 图谱服务 + Mock 实现
│   │   └── ISyncService.ets   # 同步服务 + Mock 实现
│   ├── utils/                 # 工具类
│   └── viewmodels/            # ★ MVVM 状态管理层
│       ├── NoteViewModel.ets  # 单笔记状态（加载/保存/Frontmatter）
│       └── WorkspaceViewModel.ets # 工作区状态（多标签/分屏/历史）
```

## 核心改进（v3.0）

### 1. 前后端分离架构

| 层级 | 职责 | 文件 |
|------|------|------|
| **Service** | 定义数据接口 + Mock 实现 | `services/*.ets` |
| **ViewModel** | 业务逻辑 + 状态管理 | `viewmodels/*.ets` |
| **Component** | 纯 UI 渲染 | `components/*.ets` |

后端开发只需：
1. 实现 `IFileService` 接口（替换 `MockFileService`）
2. 实现 `IGraphService` 接口（替换 `MockGraphService`）
3. 实现 `ISyncService` 接口（替换 `MockSyncService`）

### 2. 完整的 Obsidian 界面还原

| 组件 | 功能 | 状态 |
|------|------|------|
| 面包屑 | 显示 Vault/文件夹/文件层级，支持点击跳转 | ✅ |
| 命令面板 | Ctrl+P 唤起，12+ 命令，支持搜索过滤 | ✅ |
| 状态栏 | 字数/字符/阅读时间/光标位置/同步状态/视图切换 | ✅ |
| 分屏编辑 | 左右拖拽调整比例，实时同步滚动（预留） | ✅ |
| 属性面板 | Frontmatter YAML 编辑，标签管理 | ✅ |
| 模态框 | 确认/提示/输入，通用组件 | ✅ |
| 上下文菜单 | PC 长按文件显示「在新窗口打开」 | ✅ |

### 3. ViewModel 状态管理

**NoteViewModel**
- `loadNote()` / `saveNote()` / 自动保存防抖
- `updateFrontmatter()` / `addTag()` / `removeTag()`
- `getWordCount()` / `getReadingTime()`
- 文件外部变更监听

**WorkspaceViewModel**
- `openNote()` / `closeTab()` / `activateTab()`
- `splitView()` / `closeSplitPane()` - 分屏管理
- `navigateBack()` / `navigateForward()` - 历史栈
- 多 Pane 状态持久化

### 4. 多设备适配

- **手机**：底部 Tabs + 遮罩层侧边栏 + 简化命令面板
- **平板**：双栏/三栏自适应 + 分屏支持
- **PC/2in1**：完整三栏 + 分屏编辑 + 上下文菜单 + 键盘快捷键

## 后端对接指南

### 步骤 1：实现 IFileService

```typescript
export class RealFileService implements IFileService {
  async getFileTree(): Promise<FileNode[]> {
    // 调用后端 API: GET /api/vault/tree
    return http.request('GET', '/api/vault/tree');
  }

  async readNote(noteId: string): Promise<{ content: string; metadata: NoteMetadata }> {
    // 调用后端 API: GET /api/notes/{noteId}
    return http.request('GET', `/api/notes/${noteId}`);
  }

  async writeNote(noteId: string, content: string, metadata?: Partial<NoteMetadata>): Promise<void> {
    // 调用后端 API: PUT /api/notes/{noteId}
    await http.request('PUT', `/api/notes/${noteId}`, { content, metadata });
  }
  // ... 其他方法
}
```

### 步骤 2：替换 Service 单例

```typescript
// services/IFileService.ets
// export const fileService: IFileService = new MockFileService();
export const fileService: IFileService = new RealFileService();
```

### 步骤 3：数据类型对齐

确保后端返回的 JSON 结构与 `ApiTypes.ets` 中的接口定义一致：
- `NoteMetadata` - 笔记元数据
- `SearchResultItem` - 搜索结果
- `GraphData` / `GraphNodeData` / `GraphEdgeData` - 图谱数据
- `SyncStatus` - 同步状态

## 运行验证

1. 解压导入 DevEco Studio
2. 放置图标到 `resources/base/media/`
3. Sync Project，SDK >= 6.0.2（22）
4. 运行验证：
   - [ ] 打开笔记 → 面包屑显示路径 → 状态栏显示字数
   - [ ] 点击属性面板 → 编辑 Frontmatter → 保存
   - [ ] Ctrl+P（或点击 ⌘ 图标）→ 命令面板弹出 → 选择命令
   - [ ] 分屏模式 → 左右拖拽调整比例
   - [ ] 更多 Tab → 设置 → 跳转独立设置页
   - [ ] PC 模拟器 → 长按文件 → 显示上下文菜单
