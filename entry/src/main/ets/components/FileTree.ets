import { LuniusColors, ThemeMode, getColors, Spacing, Radius } from '../utils/Theme';
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
      return '\uD83D\uDC8E';
    }
    if (this.node.type === NodeType.FOLDER) {
      return this.node.isExpanded ? '\uD83D\uDCC2' : '\uD83D\uDCC1';
    }
    return '\uD83D\uDCC4';
  }

  private nodeColor(): string {
    if (this.node.type === NodeType.FOLDER || this.node.type === NodeType.VAULT) {
      return this.colors().folderIcon;
    }
    return this.colors().fileIcon;
  }

  build() {
    Column() {
      Row() {
        Row()
          .width(this.level * this.indentSize)
          .height('100%')

        if (this.node.type !== NodeType.FILE && this.node.children &&
            this.node.children.length > 0) {
          Text(this.node.isExpanded ? '\u25BC' : '\u25B6')
            .fontSize(10)
            .fontColor(this.colors().textMuted)
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

        Text(this.nodeIcon())
          .fontSize(15)
          .margin({ right: Spacing.SM })

        Text(this.node.name)
          .fontSize(13)
          .fontColor(this.node.isActive ? this.colors().accent : this.colors().textPrimary)
          .fontWeight(this.node.isActive ? FontWeight.Medium : FontWeight.Regular)
          .layoutWeight(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .maxLines(1)

        if (this.node.type === NodeType.FILE && this.node.wordCount &&
            this.node.wordCount > 0) {
          Text(String(this.node.wordCount))
            .fontSize(10)
            .fontColor(this.colors().textMuted)
            .margin({ left: Spacing.XS })
        }
      }
      .width('100%')
      .height(36)
      .padding({ left: Spacing.SM, right: Spacing.MD })
      .backgroundColor(this.isHovered ? this.colors().bgHover :
        this.node.isActive ? this.colors().bgActive : Color.Transparent)
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

      if (this.showContextMenu && this.isPC) {
        Column({ space: 0 }) {
          ForEach(
            [
              { label: '\u25A1 \u5728\u65B0\u7A97\u53E3\u6253\u5F00', action: 'open' } as ContextMenuAction,
              { label: '\u270F \u91CD\u547D\u540D', action: 'rename' } as ContextMenuAction,
              { label: '\uD83D\uDDD1 \u5220\u9664', action: 'delete' } as ContextMenuAction
            ] as ContextMenuAction[],
            (item: ContextMenuAction, _idx: number) => {
              Text(item.label)
                .fontSize(12)
                .fontColor(item.action === 'delete'
                  ? this.colors().errorColor : this.colors().textPrimary)
                .width('100%')
                .height(32)
                .padding({ left: Spacing.MD, right: Spacing.MD })
                .backgroundColor(this.colors().bgSecondary)
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
        .backgroundColor(this.colors().bgSecondary)
        .borderRadius(Radius.MD)
        .border({ width: 1, color: this.colors().divider })
        .shadow({ radius: 12, color: 'rgba(0,0,0,0.3)', offsetX: 2, offsetY: 4 })
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

  build() {
    Column() {
      Row({ space: Spacing.SM }) {
        TextInput({ placeholder: '\u641C\u7D22\u6587\u4EF6...', text: $$this.searchQuery })
          .placeholderColor(this.colors().textMuted)
          .fontColor(this.colors().textPrimary)
          .fontSize(13)
          .height(32)
          .backgroundColor(this.colors().bgTertiary)
          .borderRadius(Radius.SM)
          .layoutWeight(1)
          .padding({ left: Spacing.SM, right: Spacing.SM })

        Button({ type: ButtonType.Circle }) {
          Text('+')
            .fontSize(18)
            .fontColor(this.colors().accent)
        }
        .width(28)
        .height(28)
        .backgroundColor(this.colors().bgHover)
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
      .width('100%')
      .height(44)
      .padding({ left: Spacing.MD, right: Spacing.MD })
      .backgroundColor(this.colors().sidebarBg)
      .border({ width: { bottom: 1 }, color: this.colors().divider })

      if (this.filteredData().length === 0 && this.searchQuery !== '') {
        Column({ space: Spacing.SM }) {
          Text('\uD83D\uDD0D')
            .fontSize(28)
          Text('\u672A\u627E\u5230\u5339\u914D\u6587\u4EF6')
            .fontSize(13)
            .fontColor(this.colors().textMuted)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
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
        .backgroundColor(this.colors().sidebarBg)
        .scrollBar(BarState.Auto)
      }

      Row() {
        Text(String(this.countFiles(this.data)) + ' \u4E2A\u6587\u4EF6')
          .fontSize(11)
          .fontColor(this.colors().textMuted)
      }
      .width('100%')
      .height(28)
      .padding({ left: Spacing.MD, right: Spacing.MD })
      .backgroundColor(this.colors().sidebarBg)
      .border({ width: { top: 1 }, color: this.colors().divider })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.colors().sidebarBg)
  }
}
