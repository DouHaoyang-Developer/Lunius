import { LuniusColors, ThemeMode, getColors, Spacing, Radius, Icons, SidebarTab, LeftSidebarTabs } from '../utils/Theme';
import { FileTree } from './FileTree';
import { BookmarkView } from './BookmarkView';
import { FileNode, NodeType } from '../models/FileNode';

@Component
export struct LeftSidebar {
  @StorageLink('themeMode') themeMode: ThemeMode = ThemeMode.DARK;
  @Prop activeTab: string = 'fileExplorer';
  @Prop fileTreeData: FileNode[] = [];
  @Link activeFileId: string;
  @Link expandedNodes: Set<string>;
  @Prop isPC: boolean = true;
  @Prop isOverlay: boolean = false;
  onTabChange?: (tabId: string) => void;
  onFileSelect?: (node: FileNode) => void;
  onCreateNew?: () => void;
  onCreateFromTemplate?: () => void;
  onOpenNote?: (noteId: string) => void;
  onClose?: () => void;

  private colors(): LuniusColors {
    return getColors(this.themeMode);
  }

  private tabs: SidebarTab[] = LeftSidebarTabs;

  build() {
    Column() {
      Row() {
        ForEach(this.tabs, (tab: SidebarTab) => {
          Column() {
            Text(tab.icon)
              .fontSize(16)
              .fontColor(this.activeTab === tab.id
                ? this.colors().accent
                : this.colors().iconSecondary)

            Row()
              .width(16)
              .height(2)
              .backgroundColor(this.activeTab === tab.id
                ? this.colors().accent : Color.Transparent)
              .borderRadius(1)
              .margin({ top: 2 })
          }
          .width(44)
          .height(Spacing.SIDEBAR_TAB_HEIGHT)
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            if (this.onTabChange) {
              this.onTabChange(tab.id);
            }
          })
        }, (tab: SidebarTab) => tab.id)

        Blank()

        if (this.isOverlay) {
          Button({ type: ButtonType.Circle }) {
            Text(Icons.CLOSE)
              .fontSize(12)
              .fontColor(this.colors().textMuted)
          }
          .width(28)
          .height(28)
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            if (this.onClose) this.onClose();
          })
        } else {
          Button({ type: ButtonType.Circle }) {
            Text(Icons.SIDEBAR_LEFT)
              .fontSize(12)
              .fontColor(this.colors().iconSecondary)
          }
          .width(28)
          .height(28)
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            if (this.onClose) this.onClose();
          })
        }
      }
      .width('100%')
      .height(Spacing.SIDEBAR_TAB_HEIGHT)
      .padding({ left: Spacing.SM, right: Spacing.SM })
      .justifyContent(FlexAlign.Start)
      .backgroundColor(this.colors().sidebarBg)
      .border({ width: { bottom: 1 }, color: this.colors().divider })

      if (this.activeTab === 'fileExplorer') {
        FileTree({
          data: this.fileTreeData,
          activeFileId: $activeFileId,
          expandedNodes: $expandedNodes,
          isPC: this.isPC,
          onFileSelect: (node: FileNode) => {
            if (this.onFileSelect) this.onFileSelect(node);
          },
          onCreateNew: () => {
            if (this.onCreateNew) this.onCreateNew();
          },
          onCreateFromTemplate: () => {
            if (this.onCreateFromTemplate) this.onCreateFromTemplate();
          }
        })
      } else if (this.activeTab === 'search') {
        this.SearchPanel()
      } else if (this.activeTab === 'bookmarks') {
        BookmarkView({
          onOpenNote: (noteId: string) => {
            if (this.onOpenNote) this.onOpenNote(noteId);
          }
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.isOverlay ? this.colors().frostedBgThick : this.colors().frostedBg)
    .backgroundBlurStyle(
      this.isOverlay ? BlurStyle.BACKGROUND_THICK : BlurStyle.BACKGROUND_REGULAR,
      { colorMode: ThemeColorMode.SYSTEM }
    )
    .border({ width: { right: 1 }, color: this.colors().divider })
  }

  @Builder
  SearchPanel() {
    Column() {
      Row({ space: Spacing.SM }) {
        TextInput({ placeholder: '\u641C\u7D22\u7B14\u8BB0\u540D\u79F0\u3001\u522B\u540D\u3001\u5185\u5BB9...' })
          .placeholderColor(this.colors().textMuted)
          .fontColor(this.colors().textPrimary)
          .fontSize(13)
          .height(36)
          .backgroundColor(this.colors().bgTertiary)
          .borderRadius(Radius.SM)
          .layoutWeight(1)
          .padding({ left: Spacing.SM, right: Spacing.SM })
      }
      .width('100%')
      .padding({ left: Spacing.MD, right: Spacing.MD, top: Spacing.MD, bottom: Spacing.SM })

      Column({ space: Spacing.SM }) {
        Text('\u641C\u7D22\u63D0\u793A')
          .fontSize(11)
          .fontColor(this.colors().textMuted)
          .padding({ left: Spacing.LG, top: Spacing.LG })

        Text('\u2022 \u8F93\u5165\u5173\u952E\u8BCD\u641C\u7D22\u7B14\u8BB0')
          .fontSize(12)
          .fontColor(this.colors().textMuted)
          .padding({ left: Spacing.LG })

        Text('\u2022 \u4F7F\u7528 Ctrl+Shift+F \u5168\u5C40\u641C\u7D22')
          .fontSize(12)
          .fontColor(this.colors().textMuted)
          .padding({ left: Spacing.LG })
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Start)
    }
    .width('100%')
    .layoutWeight(1)
  }
}
