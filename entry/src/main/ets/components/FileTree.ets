// components/FileTree.ets
// 文件树 — Vault 导航树
// 设计：几何图标、hover/active 态、搜索过滤、右键菜单

import { LuniusColors, ThemeMode, getColors, Spacing, Radius, Icons } from '../utils/Theme';
import { FileNode, NodeType } from '../models/FileNode';

interface ContextMenuAction {
  label: string;
  action: string;
}

@Component
struct FileTreeNode {
  @StorageLink('themeMode') themeMode: ThemeMode = ThemeMode.DARK;
  @ObjectLink node: FileNode;
  @Prop level: number = 0;
  @Prop indentSize: number = 20;
  @Prop isPC: boolean = false;
  @State isHovered: boolean = false;
  @State showContextMenu: boolean = false;
  onSelect?: (node: FileNode) => void;
  onToggle?: (node: FileNode) => void;
  onOpenInNewWindow?: (node: FileNode) => void;
  onRename?: (node: FileNode) => void;
  onDelete?: (node: FileNode) => void;

  private colors(): LuniusColors {
    return getColors(this.themeMode);
  }

  private nodeIcon(): string {
    if (this.node.type === NodeType.VAULT) {
      return Icons.VAULT;
    }
    if (this.node.type === NodeType.FOLDER) {
      return this.node.isExpanded ? Icons.FOLDER_OPEN : Icons.FOLDER_CLOSED;
    }
    return Icons.FILE;
  }

  private nodeColor(): string {
    if (this.node.type === NodeType.FOLDER || this.node.type === NodeType.VAULT) {
      return this.colors().folderIcon;
    }
    return this.colors().fileIcon;
  }

  @Builder
  ContextMenu() {
    if (this.showContextMenu && this.isPC) {
      Column({ space: 0 }) {
        ForEach(
          [
            { label: '\u5728\u65B0\u7A97\u53E3\u6253\u5F00', action: 'open' } as ContextMenuAction,
            { label: '\u91CD\u547D\u540D', action: 'rename' } as ContextMenuAction,
            { label: '\u5220\u9664', action: 'delete' } as ContextMenuAction
          ] as ContextMenuAction[],
          (item: ContextMenuAction, _idx: number) => {
            Text(item.label)
              .fontSize(12)
              .fontColor(item.action === 'delete'
                ? this.colors().error : this.colors().textPrimary)
              .width('100%')
              .height(32)
              .padding({ left: Spacing.MD, right: Spacing.MD })
              .backgroundColor(Color.Transparent)
              .onClick(() => {
                if (item.action === 'open' && this.onOpenInNewWindow) {
                  this.onOpenInNewWindow(this.node);
                } else if (item.action === 'rename' && this.onRename) {
                  this.onRename(this.node);
                } else if (item.action === 'delete' && this.onDelete) {
                  this.onDelete(this.node);
                }
                this.showContextMenu = false;
              })
          }, (item: ContextMenuAction) => item.action
        )
      }
      .width(150)
      .backgroundColor(this.colors().surface2)
      .borderRadius(Radius.MD)
      .border({ width: 1, color: this.colors().border })
      .shadow({ radius: 12, color: 'rgba(0,0,0,0.2)', offsetX: 2, offsetY: 4 })
      .position({ x: 40, y: 30 })
      .zIndex(10)
    }
  }

  build() {
    Column() {
      Row() {
        // 缩进
        Row()
          .width(this.level * this.indentSize)
          .height('100%')

        // 展开/折叠箭头
        if (this.node.type !== NodeType.FILE && this.node.children &&
            this.node.children.length > 0) {
          Text(this.node.isExpanded ? Icons.CHEVRON_DOWN : Icons.CHEVRON_RIGHT)
            .fontSize(9)
            .fontColor(this.colors().textTertiary)
            .width(18)
            .textAlign(TextAlign.Center)
            .onClick(() => {
              if (this.onToggle) {
                this.onToggle(this.node);
              }
            })
        } else {
          Row().width(18)
        }

        // 图标
        Text(this.nodeIcon())
          .fontSize(13)
          .fontColor(this.nodeColor())
          .margin({ right: Spacing.SM })

        // 文件名
        Text(this.node.name)
          .fontSize(13)
          .fontColor(this.node.isActive ? this.colors().accent : this.colors().textPrimary)
          .fontWeight(this.node.isActive ? FontWeight.Medium : FontWeight.Regular)
          .layoutWeight(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .maxLines(1)

        // 字数徽标
        if (this.node.type === NodeType.FILE && this.node.wordCount &&
            this.node.wordCount > 0) {
          Text(String(this.node.wordCount))
            .fontSize(10)
            .fontColor(this.colors().textTertiary)
            .backgroundColor(this.colors().surface2)
            .padding({ left: Spacing.XS, right: Spacing.XS, top: 1, bottom: 1 })
            .borderRadius(Radius.XS)
            .margin({ left: Spacing.XS })
        }
      }
      .width('100%')
      .height(Spacing.FILE_TREE_ITEM)
      .padding({ left: Spacing.SM, right: Spacing.MD })
      .backgroundColor(this.isHovered ? this.colors().surfaceHover :
        this.node.isActive ? this.colors().surfaceActive : Color.Transparent)
      .borderRadius(Radius.SM)
      .onHover((isHover: boolean) => {
        this.isHovered = isHover;
      })
      .onClick(() => {
        this.showContextMenu = false;
        if (this.onSelect) {
          this.onSelect(this.node);
        }
      })
      .gesture(
        LongPressGesture()
          .onAction(() => {
            if (this.isPC && this.node.type === NodeType.FILE) {
              this.showContextMenu = true;
            }
          })
      )

      this.ContextMenu()

      if (this.node.isExpanded && this.node.children) {
        ForEach(this.node.children, (child: FileNode) => {
          FileTreeNode({
            node: child,
            level: this.level + 1,
            isPC: this.isPC,
            onSelect: this.onSelect,
            onToggle: this.onToggle,
            onOpenInNewWindow: this.onOpenInNewWindow,
            onRename: this.onRename,
            onDelete: this.onDelete
          })
        }, (child: FileNode) => child.id)
      }
    }
    .width('100%')
  }
}

@Component
export struct FileTree {
  @StorageLink('themeMode') themeMode: ThemeMode = ThemeMode.DARK;
  @State searchQuery: string = '';
  @Link activeFileId: string;
  @Link expandedNodes: Set<string>;
  @Prop data: FileNode[] = [];
  @Prop isPC: boolean = false;
  onFileSelect?: (node: FileNode) => void;
  onOpenInNewWindow?: (node: FileNode) => void;
  onRenameFile?: (node: FileNode) => void;
  onDeleteFile?: (node: FileNode) => void;
  onCreateNew?: () => void;
  onCreateFromTemplate?: () => void;

  private colors(): LuniusColors {
    return getColors(this.themeMode);
  }

  private matchesSearch(node: FileNode, query: string): boolean {
    if (query === '') {
      return true;
    }
    const lowerQuery = query.toLowerCase();
    if (node.name.toLowerCase().includes(lowerQuery)) {
      return true;
    }
    if (node.children) {
      for (const child of node.children) {
        if (this.matchesSearch(child, query)) {
          return true;
        }
      }
    }
    return false;
  }

  private filteredData(): FileNode[] {
    if (this.searchQuery.trim() === '') {
      return this.data;
    }
    const result: FileNode[] = [];
    for (const root of this.data) {
      if (this.matchesSearch(root, this.searchQuery.trim())) {
        result.push(root);
      }
    }
    return result;
  }

  private handleToggle(node: FileNode): void {
    const newSet = new Set(this.expandedNodes);
    if (newSet.has(node.id)) {
      newSet.delete(node.id);
    } else {
      newSet.add(node.id);
    }
    this.expandedNodes = newSet;
    node.isExpanded = !node.isExpanded;
  }

  private handleSelect(node: FileNode): void {
    if (node.type === NodeType.FOLDER || node.type === NodeType.VAULT) {
      this.handleToggle(node);
    } else {
      this.activeFileId = node.id;
      if (this.onFileSelect) {
        this.onFileSelect(node);
      }
    }
  }

  private countFiles(nodes: FileNode[]): number {
    let count = 0;
    for (const node of nodes) {
      if (node.type === NodeType.FILE) {
        count++;
      }
      if (node.children) {
        count += this.countFiles(node.children);
      }
    }
    return count;
  }

  @Builder
  EmptyState() {
    Column({ space: Spacing.SM }) {
      Text(Icons.SEARCH)
        .fontSize(28)
        .fontColor(this.colors().textTertiary)
      Text('\u672A\u627E\u5230\u5339\u914D\u6587\u4EF6')
        .fontSize(13)
        .fontColor(this.colors().textTertiary)
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  NewFileButton() {
    Column() {
      Text(Icons.PLUS)
        .fontSize(16)
        .fontColor(this.colors().accent)
    }
    .width(28)
    .height(28)
    .justifyContent(FlexAlign.Center)
    .borderRadius(Radius.SM)
    .backgroundColor(this.colors().surface2)
    .onClick(() => {
      if (this.onCreateNew) {
        this.onCreateNew();
      }
    })
    .gesture(
      LongPressGesture()
        .onAction(() => {
          if (this.onCreateFromTemplate) {
            this.onCreateFromTemplate();
          }
        })
    )
  }

  build() {
    Column() {
      // 搜索栏
      Row({ space: Spacing.SM }) {
        TextInput({ placeholder: '\u641C\u7D22\u6587\u4EF6...', text: $$this.searchQuery })
          .placeholderColor(this.colors().textTertiary)
          .fontColor(this.colors().textPrimary)
          .fontSize(13)
          .height(32)
          .backgroundColor(this.colors().surface2)
          .borderRadius(Radius.SM)
          .layoutWeight(1)
          .padding({ left: Spacing.SM, right: Spacing.SM })

        this.NewFileButton()
      }
      .width('100%')
      .height(44)
      .padding({ left: Spacing.MD, right: Spacing.MD })
      .backgroundColor(this.colors().surface1)
      .border({ width: { bottom: 1 }, color: this.colors().border })

      // 文件列表
      if (this.filteredData().length === 0 && this.searchQuery !== '') {
        this.EmptyState()
      } else {
        List({ space: 2 }) {
          ForEach(this.filteredData(), (root: FileNode) => {
            ListItem() {
              FileTreeNode({
                node: root,
                level: 0,
                isPC: this.isPC,
                onSelect: (node: FileNode) => this.handleSelect(node),
                onToggle: (node: FileNode) => this.handleToggle(node),
                onOpenInNewWindow: this.onOpenInNewWindow,
                onRename: this.onRenameFile,
                onDelete: this.onDeleteFile
              })
            }
          }, (root: FileNode) => root.id)
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ top: Spacing.XS, bottom: Spacing.XS })
        .backgroundColor(this.colors().surface1)
        .scrollBar(BarState.Auto)
      }

      // 底部统计
      Row() {
        Text(String(this.countFiles(this.data)) + ' \u4E2A\u6587\u4EF6')
          .fontSize(11)
          .fontColor(this.colors().textTertiary)
      }
      .width('100%')
      .height(28)
      .padding({ left: Spacing.MD, right: Spacing.MD })
      .backgroundColor(this.colors().surface1)
      .border({ width: { top: 1 }, color: this.colors().border })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.colors().surface1)
  }
}
