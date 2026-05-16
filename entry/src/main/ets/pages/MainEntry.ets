// pages/MainEntry.ets
// Obsidian ArkTS v3 - 完整工作区，真实文件系统后端

import { display } from '@kit.ArkUI';
import { router } from '@kit.ArkUI';
import { ObsidianColors, ThemeMode, getColors, SidebarWidth } from '../utils/Theme';
import { ResponsiveState } from '../utils/ResponsiveLayout';
import { WorkspaceViewModel, TabState } from '../viewmodels/WorkspaceViewModel';
import { NoteViewModel } from '../viewmodels/NoteViewModel';
import { Ribbon } from '../components/Ribbon';
import { FileTree } from '../components/FileTree';
import { TabBar } from '../components/TabBar';
import { MarkdownEditor } from '../components/MarkdownEditor';
import { RightSidebar } from '../components/RightSidebar';
import { GraphView } from '../components/GraphView';
import { CommandPalette } from '../components/commandpalette/CommandPalette';
import { FileNode, NodeType } from '../models/FileNode';
import { fileService } from '../services/IFileService';
import { FileService } from '../utils/FileService';

interface TabBarItem {
  id: string;
  title: string;
  isModified?: boolean;
  isActive?: boolean;
}

interface ToolMenuItem {
  icon: string;
  label: string;
  action: () => void;
}

@Entry
@Component
struct ObsidianApp {
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

  private localFileService: FileService = FileService.getInstance();

  private get colors(): ObsidianColors {
    return getColors(this.themeMode);
  }

  async aboutToAppear(): Promise<void> {
    this.updateScreenSize();
    try {
      display.on('change', () => this.updateScreenSize());
    } catch (e) {
      console.error('Display listener error:', e);
    }

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

    this.isLoading = false;
  }

  private async loadFileTree(): Promise<void> {
    try {
      this.fileTreeData = await fileService.getFileTree();
      // 自动展开根节点
      if (this.fileTreeData.length > 0) {
        this.expandedNodes.add(this.fileTreeData[0].id);
      }
    } catch (e) {
      console.error('Failed to load file tree: ' + JSON.stringify(e));
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
      this.workspace.openNote(node.id, node.name);
      this.currentView = 'editor';
      if (this.responsive.isPhone) {
        this.showMobileSidebar = false;
      }
    }
  }

  private async handleCreateNewNote(): Promise<void> {
    try {
      const result = await fileService.createNote('/', '未命名', '# 未命名\n\n开始写作...\n');
      // 刷新文件树
      await this.loadFileTree();
      // 自动打开新笔记
      this.activeFileId = result.id;
      this.workspace.openNote(result.id, result.title);
      this.currentView = 'editor';
    } catch (e) {
      console.error('Failed to create new note: ' + JSON.stringify(e));
    }
  }

  private handleRibbonAction(action: string): void {
    switch (action) {
      case 'switchToSearch':
        router.pushUrl({ url: 'pages/SearchPage' });
        break;
      case 'switchToGraph':
        this.currentView = 'graph';
        break;
      case 'openSettings':
        router.pushUrl({ url: 'pages/SettingsPage' });
        break;
    }
  }

  // 获取当前激活的 Tab
  private get activeTab(): TabState | undefined {
    const pane = this.workspace.panes.find(p => p.id === this.workspace.activePaneId);
    if (!pane) return undefined;
    return pane.tabs.find(t => t.id === pane.activeTabId);
  }

  // 从 WorkspaceViewModel 构建 TabBar 所需的 TabItem 数组
  private get tabBarItems(): TabBarItem[] {
    const pane = this.workspace.panes.find(p => p.id === this.workspace.activePaneId);
    if (!pane) return [];
    const items: TabBarItem[] = [];
    for (let i = 0; i < pane.tabs.length; i++) {
      const t = pane.tabs[i];
      const item: TabBarItem = {
        id: t.id,
        title: t.title,
        isModified: t.isModified,
        isActive: t.isActive
      };
      items.push(item);
    }
    return items;
  }

  private get tabBarActiveId(): string {
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
            onCreateNew: () => this.handleCreateNewNote()
          })
          .width(this.responsive.isPC ? SidebarWidth.PC_LEFT : SidebarWidth.TABLET_LEFT)
          .height('100%')
          .border({ width: { right: 1 }, color: this.colors.divider })
        }

        // 主编辑区
        Column({ space: 0 }) {
          // 顶部栏
          if (this.responsive.isPhone) {
            Row() {
              Button({ type: ButtonType.Circle }) {
                Text('☰').fontSize(18).fontColor(this.colors.iconPrimary)
              }
              .width(36).height(36).backgroundColor(Color.Transparent)
              .onClick(() => this.showMobileSidebar = true)

              Text(this.activeTab?.title ?? 'Obsidian')
                .fontSize(14).fontWeight(FontWeight.Medium)
                .fontColor(this.colors.textPrimary)
                .layoutWeight(1).textAlign(TextAlign.Center)
                .textOverflow({ overflow: TextOverflow.Ellipsis }).maxLines(1)

              Button({ type: ButtonType.Circle }) {
                Text('⌘').fontSize(18).fontColor(this.colors.iconPrimary)
              }
              .width(36).height(36).backgroundColor(Color.Transparent)
              .onClick(() => this.showCommandPalette = true)
            }
            .width('100%').height(48).padding({ left: 8, right: 8 })
            .backgroundColor(this.colors.bgSecondary)
            .border({ width: { bottom: 1 }, color: this.colors.divider })
          } else {
            // PC/平板：TabBar + 命令面板快捷键提示
            Row() {
              TabBar({
                tabs: this.tabBarItems,
                activeTabId: this.tabBarActiveId,
                onTabChange: (tabId: string) => {
                  this.workspace.activateTab(tabId);
                },
                onTabClose: (tabId: string) => {
                  this.workspace.closeTab(tabId);
                }
              })
              .layoutWeight(1)

              Button({ type: ButtonType.Circle }) {
                Text('⌘').fontSize(14).fontColor(this.colors.iconSecondary)
              }
              .width(28).height(28).backgroundColor(this.colors.bgHover)
              .margin({ right: 8 })
              .onClick(() => this.showCommandPalette = true)
            }
            .width('100%')
          }

          // 内容区：编辑器或图谱
          if (this.currentView === 'editor' && this.activeTab) {
            MarkdownEditor({
              vm: this.activeTab.viewModel,
              isSplitView: this.workspace.isSplitView
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
                .fontColor(this.colors.textPrimary)
              Text('点击左侧 "+" 创建新笔记，或选择文件开始编辑')
                .fontSize(14).fontColor(this.colors.textSecondary)
              Button('创建新笔记')
                .backgroundColor(this.colors.accent)
                .borderRadius(8)
                .margin({ top: 8 })
                .onClick(() => this.handleCreateNewNote())
            }
            .width('100%').layoutWeight(1)
            .justifyContent(FlexAlign.Center)
            .backgroundColor(this.colors.editorBg)
          }
        }
        .width('100%').height('100%').layoutWeight(1)
        .backgroundColor(this.colors.editorBg)

        // 右侧边栏
        if (this.workspace.rightSidebarVisible && !this.responsive.isPhone && this.activeTab) {
          RightSidebar({
            responsive: this.responsive,
            vm: this.activeTab.viewModel,
            isVisible: true,
            panelWidth: this.responsive.isPC ? SidebarWidth.PC_RIGHT : SidebarWidth.TABLET_RIGHT,
            onClose: () => { this.workspace.rightSidebarVisible = false; }
          })
          .height('100%')
        }
      }
      .width('100%').height('100%').backgroundColor(this.colors.bgPrimary)

      // 加载中遮罩
      if (this.isLoading) {
        Column() {
          Text('⏳').fontSize(32)
          Text('加载中...').fontSize(14).fontColor(this.colors.textSecondary).margin({ top: 8 })
        }
        .width('100%').height('100%')
        .backgroundColor(this.colors.bgPrimary)
        .justifyContent(FlexAlign.Center)
      }

      // 命令面板
      if (this.showCommandPalette) {
        CommandPalette({
          isVisible: true,
          onClose: () => this.showCommandPalette = false
        })
      }

      // 手机侧边栏遮罩
      if (this.showMobileSidebar) {
        Row() {
          Column() {
            Column() {
              Row() {
                Text('文件列表').fontSize(16).fontWeight(FontWeight.Medium).fontColor(this.colors.textPrimary)
                Button({ type: ButtonType.Circle }) {
                  Text('✕').fontSize(14).fontColor(this.colors.textMuted)
                }
                .width(32).height(32).backgroundColor(Color.Transparent)
                .onClick(() => this.showMobileSidebar = false)
              }
              .width('100%').height(48).padding({ left: 16, right: 16 })
              .justifyContent(FlexAlign.SpaceBetween)
              .backgroundColor(this.colors.sidebarBg)
              .border({ width: { bottom: 1 }, color: this.colors.divider })

              FileTree({
                data: this.fileTreeData,
                activeFileId: this.activeFileId,
                expandedNodes: this.expandedNodes,
                isPC: false,
                onFileSelect: (node: FileNode) => this.handleFileSelect(node),
                onCreateNew: () => this.handleCreateNewNote()
              })
              .layoutWeight(1)
            }
            .width('100%').height('100%').backgroundColor(this.colors.sidebarBg)
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
    .width('100%').height('100%').backgroundColor(this.colors.bgPrimary)
  }

  build() {
    Tabs({ barPosition: BarPosition.End, index: 0 }) {
      TabContent() { this.WorkspaceContent() }
      .tabBar(this.TabBarBuilder('笔记', '✏️', 0))

      TabContent() {
        Column() {
          Text('全局搜索').fontSize(20).fontWeight(FontWeight.Bold)
            .fontColor(this.colors.textPrimary).margin(24)
          Button('打开独立搜索页')
            .backgroundColor(this.colors.accent)
            .onClick(() => {
              router.pushUrl({ url: 'pages/SearchPage' });
            })
        }
        .width('100%').height('100%').backgroundColor(this.colors.bgPrimary)
      }
      .tabBar(this.TabBarBuilder('搜索', '🔍', 1))

      TabContent() {
        Column({ space: 16 }) {
          Text('工具').fontSize(20).fontWeight(FontWeight.Bold)
            .fontColor(this.colors.textPrimary).margin({ top: 24, left: 24, right: 24 })

          Column({ space: 0 }) {
            ForEach([
              { icon: '⚙️', label: '设置', action: () => router.pushUrl({ url: 'pages/SettingsPage' }) },
              { icon: '🌓', label: '切换主题', action: () => {
                this.themeMode = this.themeMode === ThemeMode.DARK ? ThemeMode.LIGHT : ThemeMode.DARK;
              }},
              { icon: '⇄', label: '分屏模式', action: () => {
                this.workspace.splitView('vertical');
              }},
              { icon: '📝', label: '新建笔记', action: () => this.handleCreateNewNote() },
              { icon: 'ℹ️', label: '关于', action: () => {} }
            ], (item: ToolMenuItem, index: number) => {
              Row({ space: 12 }) {
                Text(item.icon).fontSize(20)
                Text(item.label).fontSize(15).fontColor(this.colors.textPrimary).layoutWeight(1)
                Text('›').fontSize(16).fontColor(this.colors.textMuted)
              }
              .width('100%').height(52).padding({ left: 24, right: 24 })
              .backgroundColor(this.colors.bgPrimary)
              .border({ width: { bottom: 1 }, color: this.colors.divider })
              .onClick(item.action)
            }, (item: ToolMenuItem) => item.label)
          }
          .width('100%').layoutWeight(1)
        }
        .width('100%').height('100%').backgroundColor(this.colors.bgPrimary)
      }
      .tabBar(this.TabBarBuilder('更多', '⋯', 2))
    }
    .width('100%').height('100%')
    .backgroundColor(this.colors.bgPrimary)
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
        .fontColor(this.colors.iconSecondary)
      Text(title).fontSize(10)
        .fontColor(this.colors.textMuted)
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Center)
  }
}
