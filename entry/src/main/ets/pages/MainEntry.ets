// pages/MainEntry.ets

import { display } from '@kit.ArkUI';
import { LuniusColors, ThemeMode, getColors, SidebarWidth } from '../utils/Theme';
import { ResponsiveState } from '../utils/ResponsiveLayout';
import { WorkspaceViewModel, TabState } from '../viewmodels/WorkspaceViewModel';
import { NoteViewModel } from '../viewmodels/NoteViewModel';
import { Ribbon } from '../components/Ribbon';
import { FileTree } from '../components/FileTree';
import { TabBar } from '../components/TabBar';
import { MarkdownEditor } from '../components/MarkdownEditor';
import { RightSidebar } from '../components/RightSidebar';
import { GraphView } from '../components/GraphView';
import { CollaborationPanel } from '../components/CollaborationPanel';
import { CommandPalette } from '../components/commandpalette/CommandPalette';
import { FileNode, NodeType } from '../models/FileNode';
import { fileIo } from '@kit.CoreFileKit';
import { fileService } from '../services/IFileService';
import { FileService } from '../utils/FileService';
import { DailyNoteHelper } from '../utils/DailyNoteHelper';
import { TabManager } from '../utils/TabManager';
import { ExportHelper } from '../utils/ExportHelper';
import { CollaborationService } from '../services/CollaborationService';
import { CollaborationSession, RemoteCursorState } from '../models/CollaborationTypes';
import { harmonyShare, systemShare } from '@kit.ShareKit';
import { uniformTypeDescriptor as utd } from '@kit.ArkData';

interface TabBarItem {
  id: string;
  title: string;
  isModified?: boolean;
  isActive?: boolean;
  isPinned?: boolean;
}

interface ToolMenuItem {
  icon: string;
  label: string;
  action: () => void;
}

@Entry
@Component
struct LuniusApp {
  @StorageLink('themeMode') themeMode: ThemeMode = ThemeMode.DARK;
  @State responsive: ResponsiveState = new ResponsiveState();
  @State workspace: WorkspaceViewModel = new WorkspaceViewModel();

  // UI 状态
  @State showCommandPalette: boolean = false;
  @State showMobileSidebar: boolean = false;
  @State showMobileRightPanel: boolean = false;
  @State currentView: string = 'editor'; // editor | graph
  @State activeFileId: string = '';
  @State expandedNodes: Set<string> = new Set(['root']);
  @State fileTreeData: FileNode[] = [];
  @State isLoading: boolean = true;

  // 协同状态
  @State showCollaborationPanel: boolean = false;
  @State collaborationSession: CollaborationSession | null = null;
  @State remoteCursors: RemoteCursorState[] = [];
  private collabService: CollaborationService | null = null;

  private localFileService: FileService = FileService.getInstance();

  // 碰一碰回调 —— 必须在组件级别保存引用以便注销
  private knockCallback: (target: harmonyShare.SharableTarget) => void = (target) => {
    const tab = this.activeTab();
    if (!tab) return;

    const shareData = new systemShare.SharedData({
      utd: utd.UniformDataType.HYPERLINK,
      content: `https://lunius.drcn.agconnect.link/edit?noteId=${tab.noteId}`,
      title: `Lunius 笔记: ${tab.title}`,
      description: `字数: ${tab.viewModel.getWordCount()} | 标签: ${tab.viewModel.metadata?.tags?.join(', ') ?? ''}`
    });
    target.share(shareData);
  };

  private colors(): LuniusColors {
    return getColors(this.themeMode);
  }

  private showToast(message: string, duration?: number): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message, duration: duration ?? 2000 });
    } catch (e) {
      console.error('showToast error:', JSON.stringify(e));
    }
  }

  private navigateTo(url: string): void {
    try {
      this.getUIContext().getRouter().pushUrl({ url: url });
    } catch (e) {
      console.error('navigateTo error:', JSON.stringify(e));
    }
  }

  async aboutToAppear(): Promise<void> {
    this.updateScreenSize();
    try {
      display.on('change', () => this.updateScreenSize());
    } catch (e) {
      console.error('Display listener error:', e);
    }

    // 注册碰一碰监听
    try {
      harmonyShare.on('knockShare', this.knockCallback);
    } catch (e) {
      console.error('knockShare register error:', e);
    }

    // 初始化协同服务
    await this.initCollaborationService();

    // 加载文件树
    await this.loadFileTree();

    // 恢复上次标签会话
    await this.workspace.restoreSession();

    // 若没有已保存的标签，打开第一个文件或显示空白状态
    const pane = this.workspace.panes[0];
    if (pane && pane.tabs.length === 0 && this.fileTreeData.length > 0) {
      const root = this.fileTreeData[0];
      if (root.children && root.children.length > 0) {
        const firstFile = root.children[0];
        this.activeFileId = firstFile.id;
        this.workspace.openNote(firstFile.id, firstFile.name);
      }
    } else if (pane && pane.tabs.length > 0) {
      const activeTab = pane.tabs.find(t => t.isActive);
      if (activeTab) {
        this.activeFileId = activeTab.noteId;
      }
    }

    // 处理待处理的分享意图
    this.handlePendingShareAction();

    this.isLoading = false;
  }

  aboutToDisappear(): void {
    // 注销碰一碰监听
    try {
      harmonyShare.off('knockShare', this.knockCallback);
    } catch (e) {
      console.error('knockShare unregister error:', e);
    }
  }

  private async initCollaborationService(): Promise<void> {
    try {
      const deviceId = `device-${Date.now().toString(36)}`;
      const deviceName = `设备-${Date.now().toString(36).slice(-4)}`;
      const deviceType = this.responsive.isPhone ? 'phone' :
        this.responsive.isTablet ? 'tablet' : '2in1';

      this.collabService = new CollaborationService(
        deviceId, deviceName, deviceType
      );
      await this.collabService.init();
    } catch (e) {
      console.error('CollaborationService init error:', e);
    }
  }

  private async loadFileTree(): Promise<void> {
    try {
      this.fileTreeData = await fileService.getFileTree();
      if (this.fileTreeData.length > 0) {
        this.expandedNodes.add(this.fileTreeData[0].id);
      }
    } catch (e) {
      console.error('Failed to load file tree: ' + JSON.stringify(e));
    }
  }

  // 处理来自碰一碰/分享/跨端迁移的待处理操作
  private async handlePendingShareAction(): Promise<void> {
    const action = AppStorage.get<string>('pendingShareAction');
    if (!action) return;

    const noteId = AppStorage.get<string>('pendingShareNoteId');
    const collabSessionId = AppStorage.get<string>('pendingCollaborationSessionId');
    const shareFileUri = AppStorage.get<string>('pendingShareFileUri');

    if (action === 'openSharedFile' && shareFileUri) {
      await this.importSharedFile(shareFileUri);
    } else if (action === 'openSharedNote' && noteId) {
      this.activeFileId = noteId;
      this.workspace.openNote(noteId, '收到的笔记');
      this.currentView = 'editor';
    } else if (action === 'joinCollaboration' && collabSessionId) {
      this.joinCollaboration(collabSessionId);
    }

    // 清除待处理标志
    AppStorage.setOrCreate('pendingShareAction', '');
    AppStorage.setOrCreate('pendingShareNoteId', '');
    AppStorage.setOrCreate('pendingCollaborationSessionId', '');
    AppStorage.setOrCreate('pendingShareFileUri', '');
  }

  // 从分享 URI 导入文件并打开
  private async importSharedFile(uri: string): Promise<void> {
    try {
      const stat = fileIo.statSync(uri);
      if (stat.size > 2 * 1024 * 1024) {
        this.showToast('文件过大，无法导入');
        return;
      }

      const content = fileIo.readTextSync(uri);
      if (content.length === 0) {
        this.showToast('文件内容为空');
        return;
      }

      // 从内容提取标题
      let title = '收到的笔记';
      const h1Match = content.match(/^#\s+(.+)$/m);
      if (h1Match && h1Match[1]) {
        title = h1Match[1].trim();
      }

      const result = await fileService.createNote('/', title, content);
      await this.loadFileTree();
      this.activeFileId = result.id;
      this.workspace.openNote(result.id, result.title);
      this.currentView = 'editor';

      this.showToast('笔记已导入');
    } catch (e) {
      console.error('importSharedFile error:', JSON.stringify(e));
      this.showToast('导入失败');
    }
  }

  private updateScreenSize(): void {
    try {
      const info = display.getDefaultDisplaySync();
      const w = info.width / info.densityPixels;
      const h = info.height / info.densityPixels;
      this.responsive.updateSize(w, h);

      this.workspace.leftSidebarVisible = !this.responsive.isPhone;
      this.workspace.rightSidebarVisible = this.responsive.isPC || (this.responsive.isTablet && this.responsive.isLandscape);
      this.workspace.ribbonCollapsed = this.responsive.isPhone;
    } catch (e) {
      console.error('Screen size error:', e);
    }
  }

  private handleFileSelect(node: FileNode): void {
    if (node.type === NodeType.FILE) {
      this.activeFileId = node.id;
      const tab = this.workspace.openNote(node.id, node.name);
      // 注入协同服务到 ViewModel
      if (this.collabService) {
        tab.viewModel.setCollaborationService(this.collabService);
      }
      // 持续追踪当前编辑的笔记
      AppStorage.setOrCreate('currentNoteId', node.id);
      this.currentView = 'editor';
      if (this.responsive.isPhone) {
        this.showMobileSidebar = false;
      }
    }
  }

  // ─── 协同操作方法 ────────────────────────────

  private async startCollaboration(): Promise<void> {
    const tab = this.activeTab();
    if (!tab || !this.collabService) return;

    try {
      // 延迟初始化协同服务（需要 context）
      if (!this.collabService.isInSession()) {
        // Context 通过 AppStorage 传递
      }

      const sessionId = await tab.viewModel.startCollaboration();
      this.collaborationSession = this.collabService.getCurrentSession();

      this.showToast('协同会话已创建，其他设备可通过会话 ID 加入');
    } catch (e) {
      this.showToast('创建协同会话失败');
      console.error('startCollaboration error:', JSON.stringify(e));
    }
  }

  private async joinCollaboration(sessionId: string): Promise<void> {
    const tab = this.activeTab();
    if (!tab || !this.collabService) return;

    try {
      await tab.viewModel.joinCollaboration(sessionId);
      this.collaborationSession = this.collabService.getCurrentSession();

      this.showToast('已加入协同会话');
    } catch (e) {
      this.showToast('加入协同会话失败');
      console.error('joinCollaboration error:', JSON.stringify(e));
    }
  }

  private async leaveCollaboration(): Promise<void> {
    const tab = this.activeTab();
    if (!tab || !this.collabService) return;

    try {
      await tab.viewModel.leaveCollaboration();
      this.collaborationSession = null;
      this.remoteCursors = [];

      this.showToast('已退出协同会话');
    } catch (e) {
      console.error('leaveCollaboration error:', JSON.stringify(e));
    }
  }

  private toggleCollaborationPanel(): void {
    this.showCollaborationPanel = !this.showCollaborationPanel;
  }

  // ─── 导出 ────────────────────────────────────

  private async handleExportCommand(commandId: string): Promise<void> {
    const tab = this.activeTab();
    if (!tab) return;
    try {
      if (commandId === 'exportHtml') {
        const path = await ExportHelper.exportAsHtml(tab.noteId, tab.viewModel.content, tab.viewModel.title);
        this.showToast('HTML 已保存: ' + path);
      } else if (commandId === 'exportMd') {
        const path = await ExportHelper.exportMarkdown(tab.noteId, tab.viewModel.content, tab.viewModel.title);
        this.showToast('MD 已保存: ' + path);
      } else if (commandId === 'exportPdf') {
        const path = await ExportHelper.exportAsPdf(tab.noteId, tab.viewModel.content, tab.viewModel.title);
        this.showToast('PDF: ' + path);
      }
    } catch (e) {
      this.showToast('导出失败');
    }
  }

  private async openDailyNote(): Promise<void> {
    try {
      const result = await DailyNoteHelper.openOrCreateDailyNote();
      await this.loadFileTree();
      this.activeFileId = result.noteId;
      this.workspace.openNote(result.noteId, result.title);
      this.currentView = 'editor';
    } catch (e) {
      console.error('Daily note error: ' + JSON.stringify(e));
    }
  }

  private async createNoteWithTemplate(template?: string): Promise<void> {
    try {
      const tpl = template || '# 未命名\n\n开始写作...\n';
      const result = await fileService.createNote('/', '未命名', tpl);
      await this.loadFileTree();
      this.activeFileId = result.id;
      this.workspace.openNote(result.id, result.title);
      this.currentView = 'editor';
    } catch (e) {
      console.error('Failed to create note: ' + JSON.stringify(e));
    }
  }

  private async handleCreateNewNote(): Promise<void> {
    this.createNoteWithTemplate();
  }

  private async handleCreateFromTemplate(): Promise<void> {
    const tpl = '# 模板笔记\n\n## 概述\n\n## 详细内容\n\n## 总结\n\n';
    this.createNoteWithTemplate(tpl);
  }

  private handleRibbonAction(action: string): void {
    switch (action) {
      case 'switchToSearch':
        this.navigateTo('pages/SearchPage');
        break;
      case 'switchToGraph':
        this.currentView = 'graph';
        break;
      case 'openSettings':
        this.navigateTo('pages/SettingsPage');
        break;
      case 'openDailyNote':
        this.openDailyNote();
        break;
    }
  }

  // 获取当前激活的 Tab
  private activeTab(): TabState | undefined {
    const pane = this.workspace.panes.find(p => p.id === this.workspace.activePaneId);
    if (!pane) return undefined;
    return pane.tabs.find(t => t.id === pane.activeTabId);
  }

  // 从 WorkspaceViewModel 构建 TabBar 所需的 TabItem 数组
  private tabBarItems(): TabBarItem[] {
    const pane = this.workspace.panes.find(p => p.id === this.workspace.activePaneId);
    if (!pane) return [];
    const items: TabBarItem[] = [];
    for (let i = 0; i < pane.tabs.length; i++) {
      const t = pane.tabs[i];
      const item: TabBarItem = {
        id: t.id,
        title: t.title,
        isModified: t.isModified,
        isActive: t.isActive,
        isPinned: false
      };
      items.push(item);
    }
    return items;
  }

  private tabBarActiveId(): string {
    const pane = this.workspace.panes.find(p => p.id === this.workspace.activePaneId);
    return pane?.activeTabId ?? '';
  }

  @Builder
  WorkspaceContent() {
    Stack() {
      Row({ space: 0 }) {
        // Ribbon
        if (this.responsive.showRibbon) {
          Ribbon({
            isCollapsed: this.workspace.ribbonCollapsed,
            activeTool: 'file-explorer',
            onToolAction: (action: string) => this.handleRibbonAction(action)
          })
          .height('100%')
        }

        // 左侧文件树
        if (this.workspace.leftSidebarVisible && !this.responsive.isPhone) {
          FileTree({
            data: this.fileTreeData,
            activeFileId: this.activeFileId,
            expandedNodes: this.expandedNodes,
            isPC: this.responsive.isPC,
            onFileSelect: (node: FileNode) => this.handleFileSelect(node),
            onCreateNew: () => this.handleCreateNewNote(), onCreateFromTemplate: () => this.handleCreateFromTemplate()
          })
          .width(this.responsive.isPC ? SidebarWidth.PC_LEFT : SidebarWidth.TABLET_LEFT)
          .height('100%')
          .border({ width: { right: 1 }, color: this.colors().divider })
        }

        // 主编辑区
        Column({ space: 0 }) {
          // 顶部栏
          if (this.responsive.isPhone) {
            Row() {
              Button({ type: ButtonType.Circle }) {
                Text('☰').fontSize(18).fontColor(this.colors().iconPrimary)
              }
              .width(36).height(36).backgroundColor(Color.Transparent)
              .onClick(() => this.showMobileSidebar = true)

              Text(this.activeTab()?.title ?? 'Lunius')
                .fontSize(14).fontWeight(FontWeight.Medium)
                .fontColor(this.colors().textPrimary)
                .layoutWeight(1).textAlign(TextAlign.Center)
                .textOverflow({ overflow: TextOverflow.Ellipsis }).maxLines(1)

              Button({ type: ButtonType.Circle }) {
                Text('⌘').fontSize(18).fontColor(this.colors().iconPrimary)
              }
              .width(36).height(36).backgroundColor(Color.Transparent)
              .onClick(() => this.showCommandPalette = true)
            }
            .width('100%').height(48).padding({ left: 8, right: 8 })
            .backgroundColor(this.colors().bgSecondary)
            .border({ width: { bottom: 1 }, color: this.colors().divider })
          } else {
            // PC/平板：TabBar + 协同按钮 + 命令面板
            Row() {
              TabBar({
                tabs: this.tabBarItems(),
                activeTabId: this.tabBarActiveId(),
                onTabChange: (tabId: string) => {
                  this.workspace.activateTab(tabId);
                },
                onTabClose: (tabId: string) => {
                  this.workspace.closeTab(tabId);
                },
                onTabPin: (tabId: string) => {
                  const tabMgr = TabManager.getInstance();
                  tabMgr.togglePin(tabId);
                }
              })
              .layoutWeight(1)

              // 协同按钮
              Button({ type: ButtonType.Circle }) {
                Text('⊞').fontSize(14).fontColor(
                  this.activeTab()?.viewModel?.isCollaborating ? '#2ECC71' : this.colors().iconSecondary
                )
              }
              .width(28).height(28).backgroundColor(this.colors().bgHover)
              .margin({ right: 4 })
              .onClick(() => this.toggleCollaborationPanel())

              Button({ type: ButtonType.Circle }) {
                Text('⌘').fontSize(14).fontColor(this.colors().iconSecondary)
              }
              .width(28).height(28).backgroundColor(this.colors().bgHover)
              .margin({ right: 8 })
              .onClick(() => this.showCommandPalette = true)
            }
            .width('100%')
          }

          // 内容区：编辑器或图谱
          if (this.currentView === 'editor' && this.activeTab()) {
            MarkdownEditor({
              vm: this.activeTab()!.viewModel,
              isSplitView: this.workspace.isSplitView,
              onNavigateBack: () => { this.workspace.navigateBack(); },
              onNavigateForward: () => { this.workspace.navigateForward(); }
            })
            .width('100%').layoutWeight(1)
          } else if (this.currentView === 'graph') {
            GraphView()
              .width('100%').layoutWeight(1)
          } else {
            // 无打开文件时的空状态
            Column({ space: 12 }) {
              Text('📝').fontSize(48)
              Text('欢迎使用 Lunius').fontSize(22).fontWeight(FontWeight.Bold)
                .fontColor(this.colors().textPrimary)
              Text('点击左侧 "+" 创建新笔记，或选择文件开始编辑')
                .fontSize(14).fontColor(this.colors().textSecondary)
              Button('创建新笔记')
                .backgroundColor(this.colors().accent)
                .borderRadius(8)
                .margin({ top: 8 })
                .onClick(() => this.handleCreateNewNote())
            }
            .width('100%').layoutWeight(1)
            .justifyContent(FlexAlign.Center)
            .backgroundColor(this.colors().editorBg)
          }
        }
        .width('100%').height('100%').layoutWeight(1)
        .backgroundColor(this.colors().editorBg)

        // 右侧边栏
        if (this.workspace.rightSidebarVisible && !this.responsive.isPhone && this.activeTab()) {
          RightSidebar({
            responsive: this.responsive,
            vm: this.activeTab()!.viewModel,
            isVisible: true,
            panelWidth: this.responsive.isPC ? SidebarWidth.PC_RIGHT : SidebarWidth.TABLET_RIGHT,
            onClose: () => { this.workspace.rightSidebarVisible = false; }
          })
          .height('100%')
        }
      }
      .width('100%').height('100%').backgroundColor(this.colors().bgPrimary)

      // 加载中遮罩
      if (this.isLoading) {
        Column() {
          Text('⏳').fontSize(32)
          Text('加载中...').fontSize(14).fontColor(this.colors().textSecondary).margin({ top: 8 })
        }
        .width('100%').height('100%')
        .backgroundColor(this.colors().bgPrimary)
        .justifyContent(FlexAlign.Center)
      }

      // 协同面板（浮动）
      if (this.showCollaborationPanel) {
        Stack({ alignContent: Alignment.TopEnd }) {
          Column().width('100%').height('100%')
            .backgroundColor('rgba(0,0,0,0.3)')
            .onClick(() => this.showCollaborationPanel = false)
            .zIndex(99)

          CollaborationPanel({
            session: this.collaborationSession,
            remoteCursors: this.remoteCursors,
            isVisible: true,
            onStartSession: () => this.startCollaboration(),
            onJoinSession: (sessionId: string) => this.joinCollaboration(sessionId),
            onLeaveSession: () => this.leaveCollaboration(),
            onInviteDevice: (deviceId: string) => {
              this.showToast(`邀请设备: ${deviceId}`);
            },
            onClose: () => this.showCollaborationPanel = false
          })
          .margin({ top: 52, right: 12 })
          .zIndex(100)
        }
        .width('100%').height('100%')
        .position({ x: 0, y: 0 })
        .zIndex(100)
      }

      // 命令面板
      if (this.showCommandPalette) {
        CommandPalette({
          isVisible: true,
          onClose: () => this.showCommandPalette = false,
          onCommand: (commandId: string) => this.handleExportCommand(commandId)
        })
      }

      // 手机侧边栏遮罩
      if (this.showMobileSidebar) {
        Row() {
          Column() {
            Column() {
              Row() {
                Text('文件列表').fontSize(16).fontWeight(FontWeight.Medium).fontColor(this.colors().textPrimary)
                Button({ type: ButtonType.Circle }) {
                  Text('✕').fontSize(14).fontColor(this.colors().textMuted)
                }
                .width(32).height(32).backgroundColor(Color.Transparent)
                .onClick(() => this.showMobileSidebar = false)
              }
              .width('100%').height(48).padding({ left: 16, right: 16 })
              .justifyContent(FlexAlign.SpaceBetween)
              .backgroundColor(this.colors().sidebarBg)
              .border({ width: { bottom: 1 }, color: this.colors().divider })

              FileTree({
                data: this.fileTreeData,
                activeFileId: this.activeFileId,
                expandedNodes: this.expandedNodes,
                isPC: false,
                onFileSelect: (node: FileNode) => this.handleFileSelect(node),
                onCreateNew: () => this.handleCreateNewNote(), onCreateFromTemplate: () => this.handleCreateFromTemplate()
              })
              .layoutWeight(1)
            }
            .width('100%').height('100%').backgroundColor(this.colors().sidebarBg)
          }
          .width('80%').height('100%').alignItems(HorizontalAlign.Start)

          Column()
            .width('20%').height('100%').backgroundColor('rgba(0,0,0,0.4)')
            .onClick(() => this.showMobileSidebar = false)
        }
        .width('100%').height('100%').zIndex(100)
        .animation({ duration: 250, curve: Curve.EaseOut })
      }
    }
    .width('100%').height('100%').backgroundColor(this.colors().bgPrimary)
  }

  build() {
    Tabs({ barPosition: BarPosition.End, index: 0 }) {
      TabContent() { this.WorkspaceContent() }
      .tabBar(this.TabBarBuilder('笔记', '✏️', 0))

      TabContent() {
        Column() {
          Text('全局搜索').fontSize(20).fontWeight(FontWeight.Bold)
            .fontColor(this.colors().textPrimary).margin(24)
          Button('打开独立搜索页')
            .backgroundColor(this.colors().accent)
            .onClick(() => {
              this.navigateTo('pages/SearchPage');
            })
        }
        .width('100%').height('100%').backgroundColor(this.colors().bgPrimary)
      }
      .tabBar(this.TabBarBuilder('搜索', '🔍', 1))

      TabContent() {
        Column({ space: 16 }) {
          Text('工具').fontSize(20).fontWeight(FontWeight.Bold)
            .fontColor(this.colors().textPrimary).margin({ top: 24, left: 24, right: 24 })

          Column({ space: 0 }) {
            ForEach([
              { icon: '⚙️', label: '设置', action: () => this.navigateTo('pages/SettingsPage') },
              { icon: '🌓', label: '切换主题', action: () => {
                this.themeMode = this.themeMode === ThemeMode.DARK ? ThemeMode.LIGHT : ThemeMode.DARK;
              }},
              { icon: '⇄', label: '分屏模式', action: () => {
                this.workspace.splitView('vertical');
              }},
              { icon: '⊞', label: '超级终端协同', action: () => {
                this.toggleCollaborationPanel();
              }},
              { icon: '📝', label: '新建笔记', action: () => this.handleCreateNewNote() },
              { icon: 'ℹ️', label: '关于', action: () => {} }
            ], (item: ToolMenuItem, index: number) => {
              Row({ space: 12 }) {
                Text(item.icon).fontSize(20)
                Text(item.label).fontSize(15).fontColor(this.colors().textPrimary).layoutWeight(1)
                Text('›').fontSize(16).fontColor(this.colors().textMuted)
              }
              .width('100%').height(52).padding({ left: 24, right: 24 })
              .backgroundColor(this.colors().bgPrimary)
              .border({ width: { bottom: 1 }, color: this.colors().divider })
              .onClick(item.action)
            }, (item: ToolMenuItem) => item.label)
          }
          .width('100%').layoutWeight(1)
        }
        .width('100%').height('100%').backgroundColor(this.colors().bgPrimary)
      }
      .tabBar(this.TabBarBuilder('更多', '⋯', 2))
    }
    .width('100%').height('100%')
    .backgroundColor(this.colors().bgPrimary)
    .onChange((index: number) => {})
    .scrollable(true)
    .animationDuration(300)
    .barHeight(56)
    .barMode(BarMode.Fixed)
  }

  @Builder
  TabBarBuilder(title: string, icon: string, index: number) {
    Column({ space: 2 }) {
      Text(icon).fontSize(20)
        .fontColor(this.colors().iconSecondary)
      Text(title).fontSize(10)
        .fontColor(this.colors().textMuted)
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Center)
  }
}
