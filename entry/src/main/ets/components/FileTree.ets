// components/FileTree.ets
// 文件浏览器树形组件 - 支持 PC 多窗口

import { ObsidianColors, ThemeMode, getColors } from '../utils/Theme';
import { FileNode, NodeType } from '../models/FileNode';

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

  private get colors(): ObsidianColors {
    return getColors(this.themeMode);
  }

  private get icon(): string {
    if (this.node.type === NodeType.VAULT) return '💎';
    if (this.node.type === NodeType.FOLDER) {
      return this.node.isExpanded ? '📂' : '📁';
    }
    return '📄';
  }

  private get iconColor(): string {
    if (this.node.type === NodeType.FOLDER || this.node.type === NodeType.VAULT) {
      return this.colors.folderIcon;
    }
    return this.colors.fileIcon;
  }

  private async openInNewWindow(): Promise<void> {
    if (this.onOpenInNewWindow) {
      this.onOpenInNewWindow(this.node);
    }
    this.showContextMenu = false;
  }

  build() {
    Column() {
      Row() {
        Row()
          .width(this.level * this.indentSize)
          .height('100%')

        if (this.node.type !== NodeType.FILE && this.node.children && this.node.children.length > 0) {
          Text(this.node.isExpanded ? '▼' : '▶')
            .fontSize(10)
            .fontColor(this.colors.textMuted)
            .width(16)
            .textAlign(TextAlign.Center)
            .onClick(() => {
              if (this.onToggle) {
                this.onToggle(this.node);
              }
            })
        } else {
          Row().width(16)
        }

        Text(this.icon)
          .fontSize(16)
          .fontColor(this.iconColor)
          .margin({ right: 6 })

        Text(this.node.name)
          .fontSize(13)
          .fontColor(this.node.isActive ? this.colors.accent : this.colors.textPrimary)
          .fontWeight(this.node.isActive ? FontWeight.Medium : FontWeight.Regular)
          .layoutWeight(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .maxLines(1)

        if (this.node.type === NodeType.FILE && this.node.wordCount) {
          Text(`${this.node.wordCount}`)
            .fontSize(10)
            .fontColor(this.colors.textMuted)
            .margin({ left: 4 })
        }
      }
      .width('100%')
      .height(36)
      .padding({ left: 8, right: 12 })
      .backgroundColor(this.isHovered ? this.colors.bgHover : 
        (this.node.isActive ? this.colors.bgActive : Color.Transparent))
      .borderRadius(4)
      .onHover((isHover: boolean) => {
        this.isHovered = isHover;
      })
      .onClick(() => {
        if (this.onSelect) {
          this.onSelect(this.node);
        }
      })
      .onLongPress(() => {
        if (this.isPC && this.node.type === NodeType.FILE) {
          this.showContextMenu = true;
        }
      })

      // PC 右键/长按上下文菜单
      if (this.showContextMenu && this.isPC) {
        Column({ space: 0 }) {
          ForEach(['在新窗口打开', '重命名', '移动', '删除'], (action: string, idx: number) => {
            Text(action)
              .fontSize(12)
              .fontColor(idx === 0 ? this.colors.accent : this.colors.textPrimary)
              .width('100%')
              .height(32)
              .padding({ left: 12, right: 12 })
              .backgroundColor(this.colors.bgSecondary)
              .border({ width: { bottom: 1 }, color: this.colors.divider })
              .onClick(() => {
                if (idx === 0) {
                  this.openInNewWindow();
                }
                this.showContextMenu = false;
              })
          }, (action: string) => action)
        }
        .width(140)
        .backgroundColor(this.colors.bgSecondary)
        .borderRadius(6)
        .shadow({ radius: 8, color: 'rgba(0,0,0,0.2)', offsetX: 2, offsetY: 2 })
        .position({ x: 40, y: 30 })
        .zIndex(10)
      }

      if (this.node.isExpanded && this.node.children) {
        ForEach(this.node.children, (child: FileNode) => {
          FileTreeNode({
            node: child,
            level: this.level + 1,
            isPC: this.isPC,
            onSelect: this.onSelect,
            onToggle: this.onToggle,
            onOpenInNewWindow: this.onOpenInNewWindow
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
  onCreateNew?: () => void;

  private get colors(): ObsidianColors {
    return getColors(this.themeMode);
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

  build() {
    Column() {
      Row({ space: 8 }) {
        TextInput({ placeholder: '搜索文件...', text: $$this.searchQuery })
          .placeholderColor(this.colors.textMuted)
          .fontColor(this.colors.textPrimary)
          .fontSize(13)
          .height(32)
          .backgroundColor(this.colors.bgTertiary)
          .borderRadius(4)
          .layoutWeight(1)
          .padding({ left: 8, right: 8 })

        Button({ type: ButtonType.Circle }) {
          Text('+')
            .fontSize(18)
            .fontColor(this.colors.accent)
        }
        .width(28)
        .height(28)
        .backgroundColor(this.colors.bgHover)
        .onClick(() => {
          if (this.onCreateNew) {
            this.onCreateNew();
          }
        })
      }
      .width('100%')
      .height(48)
      .padding({ left: 12, right: 12 })
      .backgroundColor(this.colors.sidebarBg)

      List({ space: 2 }) {
        ForEach(this.data, (root: FileNode) => {
          ListItem() {
            FileTreeNode({
              node: root,
              level: 0,
              isPC: this.isPC,
              onSelect: (node: FileNode) => this.handleSelect(node),
              onToggle: (node: FileNode) => this.handleToggle(node),
              onOpenInNewWindow: this.onOpenInNewWindow
            })
          }
        }, (root: FileNode) => root.id)
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ top: 4, bottom: 4 })
      .backgroundColor(this.colors.sidebarBg)
      .scrollBar(BarState.Auto)

      Row() {
        Text(`${this.countFiles(this.data)} 个文件`)
          .fontSize(11)
          .fontColor(this.colors.textMuted)
      }
      .width('100%')
      .height(28)
      .padding({ left: 12, right: 12 })
      .backgroundColor(this.colors.sidebarBg)
      .border({ width: { top: 1 }, color: this.colors.divider })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.colors.sidebarBg)
  }

  private countFiles(nodes: FileNode[]): number {
    let count = 0;
    for (const node of nodes) {
      if (node.type === NodeType.FILE) count++;
      if (node.children) {
        count += this.countFiles(node.children);
      }
    }
    return count;
  }
}
