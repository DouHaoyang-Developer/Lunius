import { display } from '@kit.ArkUI';
import { LuniusColors, ThemeMode, getColors, SidebarWidth, Spacing } from '../utils/Theme';
import { ResponsiveState } from '../utils/ResponsiveLayout';
import { WorkspaceViewModel, TabState } from '../viewmodels/WorkspaceViewModel';
import { NoteViewModel } from '../viewmodels/NoteViewModel';
import { Ribbon } from '../components/Ribbon';
import { FileTree } from '../components/FileTree';
import { TabBar, TabItem } from '../components/TabBar';
import { MarkdownEditor } from '../components/MarkdownEditor';
import { RightSidebar } from '../components/RightSidebar';
import { GraphView } from '../components/GraphView';
import { CollaborationPanel } from '../components/CollaborationPanel';
import { CommandPalette } from '../components/commandpalette/CommandPalette';
import { QuickSwitcher } from '../components/QuickSwitcher';
import { FileNode, NodeType } from '../models/FileNode';
import { fileIo } from '@kit.CoreFileKit';
import { fileService } from '../services/IFileService';
import { FileService } from '../utils/FileService';
import { DailyNoteHelper } from '../utils/DailyNoteHelper';
import { TabManager } from '../utils/TabManager';
import { ExportHelper } from '../utils/ExportHelper';
import { CollaborationService } from '../services/CollaborationService';
import { CollaborationSession, RemoteCursorState } from '../models/CollaborationTypes';

@Entry
@Component
struct ObsidianApp {
  @StorageLink('themeMode') themeMode: ThemeMode = ThemeMode.DARK;
  @State responsive: ResponsiveState = new ResponsiveState();
  @State workspace: WorkspaceViewModel = new WorkspaceViewModel();
  @State fileTreeData: FileNode[] = [];
  @State expandedNodes: Set<string> = new Set(['root']);
  @State isLoading: boolean = true;
  @State activeFileId: string = '';
  @State currentView: string = 'editor';

  @State showCommandPalette: boolean = false;
  @State showQuickSwitcher: boolean = false;
  @State showMobileSidebar: boolean = false;
  @State showCollaborationPanel: boolean = false;
  @State collaborationSession: CollaborationSession | null = null;

  private collabService: CollaborationService | null = null;

  private colors(): LuniusColors {
    return getColors(this.themeMode);
  }

  async aboutToAppear(): Promise<void> {
    this.updateScreenSize();
    try {
      display.on('change', () => this.updateScreenSize());
    } catch (e) {
      console.error('Display listener error:', JSON.stringify(e));
    }

    await this.initCollaboration();
    await this.loadFileTree();
    await this.workspace.restoreSession();

    const pane = this.workspace.panes[0];
    if (pane && pane.tabs.length === 0 && this.fileTreeData.length > 0) {
      const root = this.fileTreeData[0];
      if (root.children && root.children.length > 0) {
        const firstFile = root.children[0];
        this.activeFileId = firstFile.id;
        this.workspace.openNote(firstFile.id, firstFile.name);
      }
    } else if (pane && pane.tabs.length > 0) {
      const activeTab = pane.tabs.find((t: TabState) => t.isActive);
      if (activeTab) {
        this.activeFileId = activeTab.noteId;
      }
    }

    this.handlePendingShareAction();
    this.isLoading = false;
  }

  private async initCollaboration(): Promise<void> {
    try {
      const deviceId = 'device-' + Date.now().toString(36);
      const deviceName = '\u8BBE\u5907-' + Date.now().toString(36).slice(-4);
      const deviceType = this.responsive.isPhone ? 'phone'
        : this.responsive.isTablet ? 'tablet' : '2in1';
      this.collabService = new CollaborationService(deviceId, deviceName, deviceType);
      await this.collabService.init();
    } catch (e) {
      console.error('CollaborationService init error:', JSON.stringify(e));
    }
  }

  private async loadFileTree(): Promise<void> {
    try {
      this.fileTreeData = await fileService.getFileTree();
      if (this.fileTreeData.length > 0) {
        this.expandedNodes.add(this.fileTreeData[0].id);
      }
    } catch (e) {
      console.error('Failed to load file tree:', JSON.stringify(e));
    }
  }

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
      this.workspace.openNote(noteId, '\u6536\u5230\u7684\u7B14\u8BB0');
      this.currentView = 'editor';
    } else if (action === 'joinCollaboration' && collabSessionId) {
      this.joinCollaboration(collabSessionId);
    }

    AppStorage.setOrCreate('pendingShareAction', '');
    AppStorage.setOrCreate('pendingShareNoteId', '');
    AppStorage.setOrCreate('pendingCollaborationSessionId', '');
    AppStorage.setOrCreate('pendingShareFileUri', '');
  }

  private async importSharedFile(uri: string): Promise<void> {
    try {
      const stat = fileIo.statSync(uri);
      if (stat.size > 2 * 1024 * 1024) {
        this.showToast('\u6587\u4EF6\u8FC7\u5927\uFF0C\u65E0\u6CD5\u5BFC\u5165');
        return;
      }
      const content = fileIo.readTextSync(uri);
      if (content.length === 0) {
        this.showToast('\u6587\u4EF6\u5185\u5BB9\u4E3A\u7A7A');
        return;
      }
      let title = '\u6536\u5230\u7684\u7B14\u8BB0';
      const h1Match = content.match(/^#\s+(.+)$/m);
      if (h1Match && h1Match[1]) {
        title = h1Match[1].trim();
      }
      const result = await fileService.createNote('/', title, content);
      await this.loadFileTree();
      this.activeFileId = result.id;
      this.workspace.openNote(result.id, result.title);
      this.currentView = 'editor';
      this.showToast('\u7B14\u8BB0\u5DF2\u5BFC\u5165');
    } catch (e) {
      console.error('importSharedFile error:', JSON.stringify(e));
      this.showToast('\u5BFC\u5165\u5931\u8D25');
    }
  }

  private updateScreenSize(): void {
    try {
      const info = display.getDefaultDisplaySync();
      const w = info.width / info.densityPixels;
      const h = info.height / info.densityPixels;
      this.responsive.updateSize(w, h);
      this.workspace.leftSidebarVisible = !this.responsive.isPhone;
      this.workspace.rightSidebarVisible =
        this.responsive.isPC || (this.responsive.isTablet && this.responsive.isLandscape);
      this.workspace.ribbonCollapsed = this.responsive.isPhone;
    } catch (e) {
      console.error('Screen size error:', JSON.stringify(e));
    }
  }

  private handleRibbonAction(action: string): void {
    switch (action) {
      case 'switchToFileExplorer':
        this.workspace.leftSidebarVisible = !this.workspace.leftSidebarVisible;
        break;
      case 'switchToSearch':
        this.getUIContext().getRouter().pushUrl({ url: 'pages/SearchPage' });
        break;
      case 'switchToGraph':
        this.currentView = 'graph';
        break;
      case 'openDailyNote':
        this.openDailyNote();
        break;
    }
  }

  private handleFileSelect(node: FileNode): void {
    if (node.type === NodeType.FILE) {
      this.activeFileId = node.id;
      const tab = this.workspace.openNote(node.id, node.name);
      if (this.collabService) {
        tab.viewModel.setCollaborationService(this.collabService);
      }
      AppStorage.setOrCreate('currentNoteId', node.id);
      this.currentView = 'editor';
      if (this.responsive.isPhone) {
        this.showMobileSidebar = false;
      }
    }
  }

  private activeTab(): TabState | undefined {
    const pane = this.workspace.panes.find(
      (p) => p.id === this.workspace.activePaneId
    );
    if (!pane) return undefined;
    return pane.tabs.find((t) => t.id === pane.activeTabId);
  }

  private tabBarItems(): TabItem[] {
    const pane = this.workspace.panes.find(
      (p) => p.id === this.workspace.activePaneId
    );
    if (!pane) return [];
    const items: TabItem[] = [];
    for (let i = 0; i < pane.tabs.length; i++) {
      const t = pane.tabs[i];
      items.push({
        id: t.id,
        title: t.title,
        isModified: t.isModified,
        isActive: t.isActive,
        isPinned: false
      });
    }
    return items;
  }

  private tabBarActiveId(): string {
    const pane = this.workspace.panes.find(
      (p) => p.id === this.workspace.activePaneId
    );
    return pane ? pane.activeTabId : '';
  }

  private async createNewNote(): Promise<void> {
    try {
      const result = await fileService.createNote('/', '\u672A\u547D\u540D',
        '# \u672A\u547D\u540D\n\n\u5F00\u59CB\u5199\u4F5C...\n');
      await this.loadFileTree();
      this.activeFileId = result.id;
      this.workspace.openNote(result.id, result.title);
      this.currentView = 'editor';
    } catch (e) {
      console.error('Failed to create note:', JSON.stringify(e));
    }
  }

  private async createFromTemplate(): Promise<void> {
    try {
      const tpl = '# \u6A21\u677F\u7B14\u8BB0\n\n## \u6982\u8FF0\n\n## \u8BE6\u7EC6\u5185\u5BB9\n\n## \u603B\u7ED3\n\n';
      const result = await fileService.createNote('/', '\u6A21\u677F\u7B14\u8BB0', tpl);
      await this.loadFileTree();
      this.activeFileId = result.id;
      this.workspace.openNote(result.id, result.title);
      this.currentView = 'editor';
    } catch (e) {
      console.error('Failed to create from template:', JSON.stringify(e));
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
      console.error('Daily note error:', JSON.stringify(e));
    }
  }

  private async startCollaboration(): Promise<void> {
    const tab = this.activeTab();
    if (!tab || !this.collabService) return;
    try {
      await tab.viewModel.startCollaboration();
      this.collaborationSession = this.collabService.getCurrentSession();
      this.showToast('\u534F\u540C\u4F1A\u8BDD\u5DF2\u521B\u5EFA');
    } catch (e) {
      this.showToast('\u521B\u5EFA\u534F\u540C\u4F1A\u8BDD\u5931\u8D25');
      console.error('startCollaboration error:', JSON.stringify(e));
    }
  }

  private async joinCollaboration(sessionId: string): Promise<void> {
    const tab = this.activeTab();
    if (!tab || !this.collabService) return;
    try {
      await tab.viewModel.joinCollaboration(sessionId);
      this.collaborationSession = this.collabService.getCurrentSession();
      this.showToast('\u5DF2\u52A0\u5165\u534F\u540C\u4F1A\u8BDD');
    } catch (e) {
      this.showToast('\u52A0\u5165\u534F\u540C\u4F1A\u8BDD\u5931\u8D25');
      console.error('joinCollaboration error:', JSON.stringify(e));
    }
  }

  private async leaveCollaboration(): Promise<void> {
    const tab = this.activeTab();
    if (!tab || !this.collabService) return;
    try {
      await tab.viewModel.leaveCollaboration();
      this.collaborationSession = null;
      this.showToast('\u5DF2\u9000\u51FA\u534F\u540C\u4F1A\u8BDD');
    } catch (e) {
      console.error('leaveCollaboration error:', JSON.stringify(e));
    }
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({
        message: message,
        duration: 2000
      });
    } catch (e) {
      console.error('Toast error:', JSON.stringify(e));
    }
  }

  private breadcrumbItems(): import('../components/breadcrumb/Breadcrumb').BreadcrumbItem[] {
    const tab = this.activeTab();
    if (!tab || !tab.viewModel.metadata) return [];
    const parts = tab.viewModel.metadata.path.split('/')
      .filter((p: string) => p.length > 0);
    const items: import('../components/breadcrumb/Breadcrumb').BreadcrumbItem[] = [];
    for (let idx = 0; idx < parts.length; idx++) {
      items.push({
        name: parts[idx].replace('.md', ''),
        path: '/' + parts.slice(0, idx + 1).join('/'),
        isFile: idx === parts.length - 1
      });
    }
    return items;
  }

  build() {
    Stack() {
      Row({ space: 0 }) {
        if (this.responsive.showRibbon) {
          Ribbon({
            isCollapsed: this.workspace.ribbonCollapsed,
            activeTool: this.currentView === 'graph'
              ? 'switchToGraph' : 'switchToFileExplorer',
            onToolAction: (action: string) => this.handleRibbonAction(action)
          })
          .height('100%')
        }

        if (this.workspace.leftSidebarVisible && !this.responsive.isPhone) {
          FileTree({
            data: this.fileTreeData,
            activeFileId: $activeFileId,
            expandedNodes: $expandedNodes,
            isPC: this.responsive.isPC,
            onFileSelect: (node: FileNode) => this.handleFileSelect(node),
            onCreateNew: () => this.createNewNote(),
            onCreateFromTemplate: () => this.createFromTemplate()
          })
          .width(this.responsive.isPC
            ? SidebarWidth.PC_LEFT : SidebarWidth.TABLET_LEFT)
          .height('100%')
          .border({ width: { right: 1 }, color: this.colors().divider })
        }

        Column({ space: 0 }) {
          if (this.responsive.isPhone) {
            Row() {
              Button({ type: ButtonType.Circle }) {
                Text('\u2630')
                  .fontSize(18)
                  .fontColor(this.colors().iconPrimary)
              }
              .width(36).height(36)
              .backgroundColor(Color.Transparent)
              .onClick(() => { this.showMobileSidebar = true; })

              Text(this.activeTab() ? this.activeTab()!.title : 'Lunius')
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.colors().textPrimary)
                .layoutWeight(1)
                .textAlign(TextAlign.Center)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .maxLines(1)

              Button({ type: ButtonType.Circle }) {
                Text('\u2318')
                  .fontSize(18)
                  .fontColor(this.colors().iconPrimary)
              }
              .width(36).height(36)
              .backgroundColor(Color.Transparent)
              .onClick(() => { this.showCommandPalette = true; })
            }
            .width('100%').height(48)
            .padding({ left: Spacing.SM, right: Spacing.SM })
            .backgroundColor(this.colors().bgSecondary)
            .border({ width: { bottom: 1 }, color: this.colors().divider })
          } else {
            Row() {
              TabBar({
                tabs: this.tabBarItems(),
                activeTabId: this.tabBarActiveId(),
                onTabChange: (tabId: string) => this.workspace.activateTab(tabId),
                onTabClose: (tabId: string) => this.workspace.closeTab(tabId),
                onTabPin: (tabId: string) => {
                  TabManager.getInstance().togglePin(tabId);
                }
              })
              .layoutWeight(1)

              Button({ type: ButtonType.Circle }) {
                Text('\u229E')
                  .fontSize(14)
                  .fontColor(
                    this.activeTab() && this.activeTab()!.viewModel.isCollaborating
                      ? '#2ECC71' : this.colors().iconSecondary
                  )
              }
              .width(28).height(28)
              .backgroundColor(this.colors().bgHover)
              .margin({ right: 4 })
              .onClick(() => {
                this.showCollaborationPanel = !this.showCollaborationPanel;
              })

              Button({ type: ButtonType.Circle }) {
                Text('\u2318')
                  .fontSize(14)
                  .fontColor(this.colors().iconSecondary)
              }
              .width(28).height(28)
              .backgroundColor(this.colors().bgHover)
              .margin({ right: Spacing.SM })
              .onClick(() => { this.showCommandPalette = true; })
            }
            .width('100%')
          }

          if (this.currentView === 'editor' && this.activeTab()) {
            MarkdownEditor({
              vm: this.activeTab()!.viewModel,
              isSplitView: this.workspace.isSplitView,
              onNavigateBack: () => this.workspace.navigateBack(),
              onNavigateForward: () => this.workspace.navigateForward()
            })
            .width('100%').layoutWeight(1)
          } else if (this.currentView === 'graph') {
            GraphView()
              .width('100%').layoutWeight(1)
          } else {
            Column({ space: Spacing.MD }) {
              Text('\uD83D\uDCDD').fontSize(48)
              Text('\u6B22\u8FCE\u4F7F\u7528 Lunius')
                .fontSize(22).fontWeight(FontWeight.Bold)
                .fontColor(this.colors().textPrimary)
              Text('\u70B9\u51FB\u5DE6\u4FA7 "+" \u521B\u5EFA\u65B0\u7B14\u8BB0\uFF0C\u6216\u9009\u62E9\u6587\u4EF6\u5F00\u59CB\u7F16\u8F91')
                .fontSize(14).fontColor(this.colors().textSecondary)
              Button('\u521B\u5EFA\u65B0\u7B14\u8BB0')
                .backgroundColor(this.colors().accent)
                .borderRadius(8)
                .margin({ top: Spacing.SM })
                .onClick(() => this.createNewNote())
            }
            .width('100%').layoutWeight(1)
            .justifyContent(FlexAlign.Center)
            .backgroundColor(this.colors().editorBg)
          }
        }
        .width('100%').height('100%').layoutWeight(1)
        .backgroundColor(this.colors().editorBg)

        if (this.workspace.rightSidebarVisible && !this.responsive.isPhone
            && this.activeTab()) {
          RightSidebar({
            responsive: this.responsive,
            vm: this.activeTab()!.viewModel,
            isVisible: true,
            panelWidth: this.responsive.isPC
              ? SidebarWidth.PC_RIGHT : SidebarWidth.TABLET_RIGHT,
            onClose: () => { this.workspace.rightSidebarVisible = false; }
          })
          .height('100%')
        }
      }
      .width('100%').height('100%')
      .backgroundColor(this.colors().bgPrimary)

      if (this.isLoading) {
        Column() {
          Text('\u23F3').fontSize(32)
          Text('\u52A0\u8F7D\u4E2D...')
            .fontSize(14)
            .fontColor(this.colors().textSecondary)
            .margin({ top: Spacing.SM })
        }
        .width('100%').height('100%')
        .backgroundColor(this.colors().bgPrimary)
        .justifyContent(FlexAlign.Center)
      }

      if (this.showCollaborationPanel) {
        Stack({ alignContent: Alignment.TopEnd }) {
          Column().width('100%').height('100%')
            .backgroundColor('rgba(0,0,0,0.3)')
            .onClick(() => { this.showCollaborationPanel = false; })
            .zIndex(99)

          CollaborationPanel({
            session: this.collaborationSession,
            remoteCursors: [],
            isVisible: true,
            onStartSession: () => this.startCollaboration(),
            onJoinSession: (sessionId: string) => this.joinCollaboration(sessionId),
            onLeaveSession: () => this.leaveCollaboration(),
            onInviteDevice: (deviceId: string) => {
              this.showToast('\u9080\u8BF7\u8BBE\u5907: ' + deviceId);
            },
            onClose: () => { this.showCollaborationPanel = false; }
          })
          .margin({ top: 52, right: Spacing.MD })
          .zIndex(100)
        }
        .width('100%').height('100%')
        .position({ x: 0, y: 0 })
        .zIndex(100)
      }

      if (this.showCommandPalette) {
        CommandPalette({
          isVisible: true,
          onClose: () => { this.showCommandPalette = false; },
          onCommand: (commandId: string) => this.handleCommand(commandId)
        })
      }

      if (this.showQuickSwitcher) {
        QuickSwitcher({
          noteNames: this.fileTreeData
            .flatMap((n) => this.collectFileNames(n)),
          visible: true,
          onSelect: (noteId: string) => {
            this.handleQuickOpen(noteId);
            this.showQuickSwitcher = false;
          },
          onClose: () => { this.showQuickSwitcher = false; }
        })
      }

      if (this.showMobileSidebar) {
        Row() {
          Column() {
            Column() {
              Row() {
                Text('\u6587\u4EF6\u5217\u8868')
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.colors().textPrimary)
                Button({ type: ButtonType.Circle }) {
                  Text('\u2715')
                    .fontSize(14)
                    .fontColor(this.colors().textMuted)
                }
                .width(32).height(32)
                .backgroundColor(Color.Transparent)
                .onClick(() => { this.showMobileSidebar = false; })
              }
              .width('100%').height(48)
              .padding({ left: Spacing.LG, right: Spacing.LG })
              .justifyContent(FlexAlign.SpaceBetween)
              .backgroundColor(this.colors().sidebarBg)
              .border({ width: { bottom: 1 }, color: this.colors().divider })

              FileTree({
                data: this.fileTreeData,
                activeFileId: $activeFileId,
                expandedNodes: $expandedNodes,
                isPC: false,
                onFileSelect: (node: FileNode) => this.handleFileSelect(node),
                onCreateNew: () => this.createNewNote(),
                onCreateFromTemplate: () => this.createFromTemplate()
              })
              .layoutWeight(1)
            }
            .width('100%').height('100%')
            .backgroundColor(this.colors().sidebarBg)
          }
          .width('80%').height('100%')
          .alignItems(HorizontalAlign.Start)

          Column()
            .width('20%').height('100%')
            .backgroundColor('rgba(0,0,0,0.4)')
            .onClick(() => { this.showMobileSidebar = false; })
        }
        .width('100%').height('100%').zIndex(100)
        .animation({ duration: 250, curve: Curve.EaseOut })
      }
    }
    .width('100%').height('100%')
    .backgroundColor(this.colors().bgPrimary)
    .onKeyEvent((event: KeyEvent): boolean => {
      const KEY_O = 2047;
      const KEY_P = 2056;
      if (event.type === KeyType.Down && event.keyCode === KEY_O) {
        this.showQuickSwitcher = true;
        return true;
      } else if (event.type === KeyType.Down && event.keyCode === KEY_P) {
        this.showCommandPalette = true;
        return true;
      } else if (event.type === KeyType.Down && event.keyCode === 2070) {
        if (this.showCommandPalette) { this.showCommandPalette = false; }
        if (this.showQuickSwitcher) { this.showQuickSwitcher = false; }
        if (this.showCollaborationPanel) { this.showCollaborationPanel = false; }
        return true;
      }
      return false;
    })
  }

  private collectFileNames(node: FileNode): string[] {
    const names: string[] = [];
    if (node.type === NodeType.FILE) {
      names.push(node.id);
    }
    if (node.children) {
      for (const child of node.children) {
        names.push(...this.collectFileNames(child));
      }
    }
    return names;
  }

  private handleQuickOpen(noteId: string): void {
    this.activeFileId = noteId;
    const tab = this.workspace.openNote(noteId, noteId);
    if (this.collabService) {
      tab.viewModel.setCollaborationService(this.collabService);
    }
    this.currentView = 'editor';
  }

  private handleCommand(commandId: string): void {
    const tab = this.activeTab();
    if (!tab) return;
    try {
      if (commandId === 'exportHtml') {
        ExportHelper.exportAsHtml(tab.noteId, tab.viewModel.content, tab.viewModel.title)
          .then((path: string) => this.showToast('HTML \u5DF2\u4FDD\u5B58: ' + path));
      } else if (commandId === 'exportMd') {
        ExportHelper.exportMarkdown(tab.noteId, tab.viewModel.content, tab.viewModel.title)
          .then((path: string) => this.showToast('MD \u5DF2\u4FDD\u5B58: ' + path));
      } else if (commandId === 'exportPdf') {
        ExportHelper.exportAsPdf(tab.noteId, tab.viewModel.content, tab.viewModel.title)
          .then((path: string) => this.showToast('PDF: ' + path));
      } else if (commandId === 'split') {
        this.workspace.splitView('vertical');
      } else if (commandId === 'theme') {
        this.themeMode = this.themeMode === ThemeMode.DARK
          ? ThemeMode.LIGHT : ThemeMode.DARK;
      } else if (commandId === 'graph') {
        this.currentView = 'graph';
      }
    } catch (e) {
      this.showToast('\u5BFC\u51FA\u5931\u8D25');
    }
  }
}
