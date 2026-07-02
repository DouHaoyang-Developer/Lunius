import { display } from '@kit.ArkUI';
import { LuniusColors, ThemeMode, getColors, SidebarWidth, Spacing, Icons } from '../utils/Theme';
import { ResponsiveState } from '../utils/ResponsiveLayout';
import { WorkspaceViewModel, TabState } from '../viewmodels/WorkspaceViewModel';
import { NoteViewModel } from '../viewmodels/NoteViewModel';
import { Ribbon } from '../components/Ribbon';
import { LeftSidebar } from '../components/LeftSidebar';
import { TabBar, TabItem } from '../components/TabBar';
import { MarkdownEditor } from '../components/MarkdownEditor';
import { RightSidebar } from '../components/RightSidebar';
import { GraphView } from '../components/GraphView';
import { MobileNavBar } from '../components/MobileNavBar';
import { MobileToolbar } from '../components/MobileToolbar';
import { MobileTabSheet } from '../components/MobileTabSheet';
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
import { CollaborationSession } from '../models/CollaborationTypes';

@Entry
@Component
struct LuniusApp {
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
  @State showCollaborationPanel: boolean = false;
  @State showLeftOverlay: boolean = false;
  @State showRightOverlay: boolean = false;
  @State showMobileTabSheet: boolean = false;
  @State showMobileToolbar: boolean = false;
  @State collaborationSession: CollaborationSession | null = null;

  private collabService: CollaborationService | null = null;
  private leftEdgeX: number = 0;

  private colors(): LuniusColors {
    return getColors(this.themeMode);
  }

  async aboutToAppear(): Promise<void> {
    this.updateScreenSize();
    try {
      display.on('change', () => this.updateScreenSize());
    } catch (e) {
      console.error('Display listener error');
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
      console.error('CollaborationService init error');
    }
  }

  private async loadFileTree(): Promise<void> {
    try {
      this.fileTreeData = await fileService.getFileTree();
      if (this.fileTreeData.length > 0) {
        this.expandedNodes.add(this.fileTreeData[0].id);
      }
    } catch (e) {
      console.error('Failed to load file tree');
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
      console.error('importSharedFile error');
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
      console.error('Screen size error');
    }
  }

  private handleRibbonAction(action: string): void {
    switch (action) {
      case 'switchToFileExplorer':
        if (this.responsive.leftSidebarMode === 'overlay') {
          this.showLeftOverlay = true;
        } else {
          this.workspace.leftSidebarVisible = !this.workspace.leftSidebarVisible;
        }
        this.workspace.setLeftSidebarTab('fileExplorer');
        break;
      case 'switchToSearch':
        if (this.responsive.leftSidebarMode === 'overlay') {
          this.showLeftOverlay = true;
        }
        this.workspace.setLeftSidebarTab('search');
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
      this.showLeftOverlay = false;
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
        id: t.id, title: t.title,
        isModified: t.isModified, isActive: t.isActive, isPinned: false
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

  private tabCount(): number {
    const pane = this.workspace.panes.find(
      (p) => p.id === this.workspace.activePaneId
    );
    return pane ? pane.tabs.length : 0;
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
      console.error('Failed to create note');
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
      console.error('Failed to create from template');
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
      console.error('Daily note error');
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
      console.error('leaveCollaboration error');
    }
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({
        message: message, duration: 2000
      });
    } catch (e) {
      console.error('Toast error');
    }
  }

  private collectFileNames(node: FileNode): string[] {
    const names: string[] = [];
    if (node.type === NodeType.FILE) {
      names.push(node.id);
    }
    if (node.children) {
      for (let i = 0; i < node.children.length; i++) {
        const childNames = this.collectFileNames(node.children[i]);
        for (let j = 0; j < childNames.length; j++) {
          names.push(childNames[j]);
        }
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

  @Builder
  PCLayout() {
    Row({ space: 0 }) {
      Ribbon({
        isCollapsed: this.workspace.ribbonCollapsed,
        isTablet: false,
        activeTool: this.currentView === 'graph'
          ? 'switchToGraph' : 'switchToFileExplorer',
        onToolAction: (action: string) => this.handleRibbonAction(action)
      }).height('100%')

      if (this.workspace.leftSidebarVisible) {
        LeftSidebar({
          activeTab: this.workspace.leftSidebarActiveTab,
          fileTreeData: this.fileTreeData,
          activeFileId: $activeFileId,
          expandedNodes: $expandedNodes,
          isPC: true,
          isOverlay: false,
          onTabChange: (tabId: string) => this.workspace.setLeftSidebarTab(tabId),
          onFileSelect: (node: FileNode) => this.handleFileSelect(node),
          onCreateNew: () => this.createNewNote(),
          onCreateFromTemplate: () => this.createFromTemplate(),
          onOpenNote: (noteId: string) => this.handleQuickOpen(noteId),
          onClose: () => { this.workspace.leftSidebarVisible = false; }
        }).width(SidebarWidth.PC_LEFT).height('100%')
      }

      Column({ space: 0 }) {
        TabBar({
          tabs: this.tabBarItems(),
          activeTabId: this.tabBarActiveId(),
          compact: false,
          onTabChange: (tabId: string) => this.workspace.activateTab(tabId),
          onTabClose: (tabId: string) => this.workspace.closeTab(tabId),
          onTabPin: (tabId: string) => { TabManager.getInstance().togglePin(tabId); },
          onNewTab: () => this.createNewNote()
        })
        this.EditorArea()
      }.layoutWeight(1).height('100%').backgroundColor(this.colors().editorBg)

      if (this.workspace.rightSidebarVisible && this.activeTab()) {
        RightSidebar({
          activeTab: this.workspace.rightSidebarActiveTab,
          vm: this.activeTab()!.viewModel,
          isVisible: true,
          isOverlay: false,
          onTabChange: (tabId: string) => this.workspace.setRightSidebarTab(tabId),
          onJump: (_line: number) => {},
          onBacklinkClick: (source: string) => this.handleQuickOpen(source),
          onOpenNote: (noteId: string) => this.handleQuickOpen(noteId),
          onClose: () => { this.workspace.rightSidebarVisible = false; }
        }).width(SidebarWidth.PC_RIGHT).height('100%')
      }
    }.width('100%').height('100%').backgroundColor(this.colors().bgPrimary)
  }

  @Builder
  TabletLayout() {
    Stack() {
      Row({ space: 0 }) {
        if (this.responsive.isLandscape) {
          Ribbon({
            isCollapsed: true,
            isTablet: true,
            activeTool: this.currentView === 'graph'
              ? 'switchToGraph' : 'switchToFileExplorer',
            onToolAction: (action: string) => this.handleRibbonAction(action)
          }).height('100%')

          if (this.workspace.leftSidebarVisible) {
            LeftSidebar({
              activeTab: this.workspace.leftSidebarActiveTab,
              fileTreeData: this.fileTreeData,
              activeFileId: $activeFileId,
              expandedNodes: $expandedNodes,
              isPC: false,
              isOverlay: false,
              onTabChange: (tabId: string) => this.workspace.setLeftSidebarTab(tabId),
              onFileSelect: (node: FileNode) => this.handleFileSelect(node),
              onCreateNew: () => this.createNewNote(),
              onCreateFromTemplate: () => this.createFromTemplate(),
              onOpenNote: (noteId: string) => this.handleQuickOpen(noteId),
              onClose: () => { this.workspace.leftSidebarVisible = false; }
            }).width(SidebarWidth.TABLET_LEFT).height('100%')
          }
        }

        Column({ space: 0 }) {
          if (this.responsive.isLandscape) {
            TabBar({
              tabs: this.tabBarItems(),
              activeTabId: this.tabBarActiveId(),
              compact: true,
              onTabChange: (tabId: string) => this.workspace.activateTab(tabId),
              onTabClose: (tabId: string) => this.workspace.closeTab(tabId),
              onTabPin: (tabId: string) => { TabManager.getInstance().togglePin(tabId); },
              onNewTab: () => this.createNewNote()
            })
          }
          this.EditorArea()
        }.layoutWeight(1).height('100%').backgroundColor(this.colors().editorBg)

        if (this.responsive.isLandscape && this.workspace.rightSidebarVisible
            && this.activeTab()) {
          RightSidebar({
            activeTab: this.workspace.rightSidebarActiveTab,
            vm: this.activeTab()!.viewModel,
            isVisible: true,
            isOverlay: false,
            onTabChange: (tabId: string) => this.workspace.setRightSidebarTab(tabId),
            onJump: (_line: number) => {},
            onBacklinkClick: (source: string) => this.handleQuickOpen(source),
            onOpenNote: (noteId: string) => this.handleQuickOpen(noteId),
            onClose: () => { this.workspace.rightSidebarVisible = false; }
          }).width(SidebarWidth.TABLET_RIGHT).height('100%')
        }
      }.width('100%').height('100%').backgroundColor(this.colors().bgPrimary)

      if (this.showLeftOverlay) {
        this.LeftOverlayBuilder()
      }
      if (this.showRightOverlay) {
        this.RightOverlayBuilder()
      }
    }.width('100%').height('100%')
  }

  @Builder
  PhoneLayout() {
    Stack() {
      Column({ space: 0 }) {
        this.EditorArea()

        if (this.showMobileToolbar && this.activeTab()) {
          MobileToolbar({ onAction: (_actionId: string) => {} })
        }

        Row() {
          MobileNavBar({
            canGoBack: this.workspace.historyIndex > 0,
            canGoForward: this.workspace.historyIndex < this.workspace.history.length - 1,
            tabCount: this.tabCount(),
            safeAreaBottom: this.responsive.safeAreaBottom,
            onBack: () => this.workspace.navigateBack(),
            onForward: () => this.workspace.navigateForward(),
            onQuickSwitch: () => { this.showQuickSwitcher = true; },
            onShowTabs: () => { this.showMobileTabSheet = true; },
            onOpenMenu: () => { this.showLeftOverlay = true; }
          })
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .padding({ bottom: this.responsive.safeAreaBottom > 0
          ? this.responsive.safeAreaBottom : Spacing.SM })
      }.width('100%').height('100%').backgroundColor(this.colors().bgPrimary)

      this.LeftEdgeGesture()

      if (this.showLeftOverlay) {
        this.LeftOverlayBuilder()
      }
      if (this.showRightOverlay) {
        this.RightOverlayBuilder()
      }
      if (this.showMobileTabSheet) {
        this.MobileTabSheetOverlay()
      }
    }.width('100%').height('100%')
  }

  @Builder
  EditorArea() {
    if (this.currentView === 'editor' && this.activeTab()) {
      MarkdownEditor({
        vm: this.activeTab()!.viewModel,
        isSplitView: this.workspace.isSplitView,
        isMobileMode: this.responsive.isPhone,
        onNavigateBack: () => this.workspace.navigateBack(),
        onNavigateForward: () => this.workspace.navigateForward()
      }).width('100%').layoutWeight(1)
    } else if (this.currentView === 'graph') {
      GraphView().width('100%').layoutWeight(1)
    } else {
      Column({ space: Spacing.MD }) {
        Text('\uD83D\uDCDD').fontSize(48)
        Text('\u6B22\u8FCE\u4F7F\u7528 Lunius')
          .fontSize(22).fontWeight(FontWeight.Bold).fontColor(this.colors().textPrimary)
        Text('\u70B9\u51FB\u5DE6\u4FA7 "+" \u521B\u5EFA\u65B0\u7B14\u8BB0\uFF0C\u6216\u9009\u62E9\u6587\u4EF6\u5F00\u59CB\u7F16\u8F91')
          .fontSize(14).fontColor(this.colors().textSecondary)
        Button('\u521B\u5EFA\u65B0\u7B14\u8BB0')
          .backgroundColor(this.colors().accent).borderRadius(8)
          .margin({ top: Spacing.SM })
          .onClick(() => this.createNewNote())
      }.width('100%').layoutWeight(1)
      .justifyContent(FlexAlign.Center).backgroundColor(this.colors().editorBg)
    }
  }

  @Builder
  LeftOverlayBuilder() {
    Stack({ alignContent: Alignment.Start }) {
      Column().width('100%').height('100%')
        .backgroundColor(this.colors().overlayBg)
        .onClick(() => { this.showLeftOverlay = false; })

      LeftSidebar({
        activeTab: this.workspace.leftSidebarActiveTab,
        fileTreeData: this.fileTreeData,
        activeFileId: $activeFileId,
        expandedNodes: $expandedNodes,
        isPC: this.responsive.isPC,
        isOverlay: true,
        onTabChange: (tabId: string) => this.workspace.setLeftSidebarTab(tabId),
        onFileSelect: (node: FileNode) => this.handleFileSelect(node),
        onCreateNew: () => this.createNewNote(),
        onCreateFromTemplate: () => this.createFromTemplate(),
        onOpenNote: (noteId: string) => {
          this.handleQuickOpen(noteId);
          this.showLeftOverlay = false;
        },
        onClose: () => { this.showLeftOverlay = false; }
      })
      .width(this.responsive.isPhone ? '85%' : SidebarWidth.TABLET_LEFT)
      .height('100%')
      .backgroundBrightness({
        rate: this.colors().ambientGlowRate,
        lightUpDegree: this.colors().ambientGlowDegree
      })
    }.width('100%').height('100%').position({ x: 0, y: 0 }).zIndex(80)
  }

  @Builder
  RightOverlayBuilder() {
    Stack({ alignContent: Alignment.End }) {
      Column().width('100%').height('100%')
        .backgroundColor(this.colors().overlayBg)
        .onClick(() => { this.showRightOverlay = false; })

      if (this.activeTab()) {
        RightSidebar({
          activeTab: this.workspace.rightSidebarActiveTab,
          vm: this.activeTab()!.viewModel,
          isVisible: true,
          isOverlay: true,
          onTabChange: (tabId: string) => this.workspace.setRightSidebarTab(tabId),
          onJump: (_line: number) => {},
          onBacklinkClick: (source: string) => {
            this.handleQuickOpen(source);
            this.showRightOverlay = false;
          },
          onOpenNote: (noteId: string) => {
            this.handleQuickOpen(noteId);
            this.showRightOverlay = false;
          },
          onClose: () => { this.showRightOverlay = false; }
        })
        .width(this.responsive.isPhone ? '85%' : SidebarWidth.TABLET_RIGHT)
        .height('100%')
        .backgroundBrightness({
          rate: this.colors().ambientGlowRate,
          lightUpDegree: this.colors().ambientGlowDegree
        })
      }
    }.width('100%').height('100%').position({ x: 0, y: 0 }).zIndex(80)
  }

  @Builder
  MobileTabSheetOverlay() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column().width('100%').height('100%')
        .backgroundColor(this.colors().overlayBg)
        .onClick(() => { this.showMobileTabSheet = false; })

      MobileTabSheet({
        tabs: this.tabBarItems(),
        activeTabId: this.tabBarActiveId(),
        onSwitchTab: (tabId: string) => this.workspace.activateTab(tabId),
        onCloseTab: (tabId: string) => this.workspace.closeTab(tabId),
        onNewTab: () => this.createNewNote(),
        onClose: () => { this.showMobileTabSheet = false; }
      })
    }.width('100%').height('100%').position({ x: 0, y: 0 }).zIndex(80)
  }

  @Builder
  LeftEdgeGesture() {
    Column()
      .width(Spacing.EDGE_GESTURE)
      .height('100%')
      .position({ x: 0, y: 0 })
      .backgroundColor(Color.Transparent)
      .zIndex(50)
      .priorityGesture(
        PanGesture({ fingers: 1, direction: PanDirection.Right, distance: 60 })
          .onActionStart((_event: GestureEvent) => { this.leftEdgeX = 0; })
          .onActionUpdate((event: GestureEvent) => { this.leftEdgeX = event.offsetX; })
          .onActionEnd(() => {
            if (this.leftEdgeX > 60) {
              this.showLeftOverlay = true;
            }
            this.leftEdgeX = 0;
          })
      )
  }

  build() {
    Stack() {
      if (this.responsive.isPC) {
        this.PCLayout()
      } else if (this.responsive.isTablet) {
        this.TabletLayout()
      } else {
        this.PhoneLayout()
      }

      if (this.isLoading) {
        Column() {
          Text('\u23F3').fontSize(32)
          Text('\u52A0\u8F7D\u4E2D...').fontSize(14)
            .fontColor(this.colors().textSecondary).margin({ top: Spacing.SM })
        }.width('100%').height('100%')
        .backgroundColor(this.colors().bgPrimary).justifyContent(FlexAlign.Center).zIndex(90)
      }

      if (this.showCollaborationPanel) {
        Stack({ alignContent: Alignment.TopEnd }) {
          Column().width('100%').height('100%')
            .backgroundColor(this.colors().overlayBg)
            .onClick(() => { this.showCollaborationPanel = false; })
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
          }).margin({ top: 52, right: Spacing.MD })
        }.width('100%').height('100%').position({ x: 0, y: 0 }).zIndex(100)
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
          noteNames: this.collectAllFileNames(),
          visible: true,
          onSelect: (noteId: string) => {
            this.handleQuickOpen(noteId);
            this.showQuickSwitcher = false;
          },
          onClose: () => { this.showQuickSwitcher = false; }
        })
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
        this.showCommandPalette = false;
        this.showQuickSwitcher = false;
        this.showCollaborationPanel = false;
        this.showLeftOverlay = false;
        this.showRightOverlay = false;
        this.showMobileTabSheet = false;
        return true;
      }
      return false;
    })
  }

  private collectAllFileNames(): string[] {
    const names: string[] = [];
    for (let i = 0; i < this.fileTreeData.length; i++) {
      const childNames = this.collectFileNames(this.fileTreeData[i]);
      for (let j = 0; j < childNames.length; j++) {
        names.push(childNames[j]);
      }
    }
    return names;
  }
}
