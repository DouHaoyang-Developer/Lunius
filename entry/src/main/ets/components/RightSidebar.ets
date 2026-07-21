// components/RightSidebar.ets
// 右侧边栏 — 大纲/反向链接/书签
// 设计：与左侧栏一致的标签条 + 内容区

import { LuniusColors, ThemeMode, getColors, Spacing, Radius, Icons, SidebarTab, RightSidebarTabs } from '../utils/Theme';
import { OutlineView } from './OutlineView';
import { BacklinksView } from './BacklinksView';
import { BookmarkView } from './BookmarkView';
import { OutlineNode, Backlink } from '../models/FileNode';
import { NoteViewModel } from '../viewmodels/NoteViewModel';

@Component
export struct RightSidebar {
  @StorageLink('themeMode') themeMode: ThemeMode = ThemeMode.DARK;
  @Prop activeTab: string = 'outline';
  @ObjectLink vm: NoteViewModel;
  @Prop isVisible: boolean = true;
  @Prop isOverlay: boolean = false;
  onTabChange?: (tabId: string) => void;
  onJump?: (line: number) => void;
  onBacklinkClick?: (source: string) => void;
  onOpenNote?: (noteId: string) => void;
  onClose?: () => void;

  private colors(): LuniusColors {
    return getColors(this.themeMode);
  }

  private tabs: SidebarTab[] = RightSidebarTabs;

  private getOutline(): OutlineNode[] {
    if (!this.vm.content) return [];
    const lines = this.vm.content.split('\n');
    const outline: OutlineNode[] = [];
    for (let i = 0; i < lines.length; i++) {
      const match = lines[i].match(/^(#{1,6})\s+(.*)/);
      if (match) {
        outline.push({ level: match[1].length, title: match[2], line: i });
      }
    }
    return outline;
  }

  private getBacklinks(): Backlink[] {
    if (!this.vm.metadata) return [];
    const result: Backlink[] = [];
    const bl = this.vm.metadata.backlinks;
    for (let i = 0; i < bl.length; i++) {
      const item: Backlink = { source: bl[i], context: '', line: 0 };
      result.push(item);
    }
    return result;
  }

  @Builder
  TabItem(tab: SidebarTab) {
    Column() {
      Text(tab.icon)
        .fontSize(16)
        .fontColor(this.activeTab === tab.id
          ? this.colors().accent
          : this.colors().textTertiary)

      Row()
        .width(18)
        .height(2)
        .backgroundColor(this.activeTab === tab.id
          ? this.colors().accent : Color.Transparent)
        .borderRadius(Radius.FULL)
        .margin({ top: 3 })
    }
    .width(44)
    .height(Spacing.SIDEBAR_TAB_HEIGHT)
    .justifyContent(FlexAlign.Center)
    .borderRadius(Radius.SM)
    .onClick(() => {
      if (this.onTabChange) {
        this.onTabChange(tab.id);
      }
    })
  }

  @Builder
  CloseButton() {
    Column() {
      Text(Icons.CLOSE)
        .fontSize(13)
        .fontColor(this.colors().textTertiary)
    }
    .width(28)
    .height(28)
    .justifyContent(FlexAlign.Center)
    .borderRadius(Radius.SM)
    .onClick(() => {
      if (this.onClose) this.onClose();
    })
  }

  @Builder
  CollapseButton() {
    Column() {
      Text(Icons.SIDEBAR_RIGHT)
        .fontSize(13)
        .fontColor(this.colors().textTertiary)
    }
    .width(28)
    .height(28)
    .justifyContent(FlexAlign.Center)
    .borderRadius(Radius.SM)
    .onClick(() => {
      if (this.onClose) this.onClose();
    })
  }

  build() {
    Column() {
      // 标签条
      Row() {
        ForEach(this.tabs, (tab: SidebarTab) => {
          this.TabItem(tab)
        }, (tab: SidebarTab) => tab.id)

        Blank()

        if (this.isOverlay) {
          this.CloseButton()
        } else {
          this.CollapseButton()
        }
      }
      .width('100%')
      .height(Spacing.SIDEBAR_TAB_HEIGHT)
      .padding({ left: Spacing.SM, right: Spacing.SM })
      .justifyContent(FlexAlign.Start)
      .backgroundColor(this.colors().surface1)
      .border({ width: { bottom: 1 }, color: this.colors().border })

      // 内容区
      if (this.activeTab === 'outline') {
        OutlineView({
          data: this.getOutline(),
          onJump: (line: number) => {
            if (this.onJump) this.onJump(line);
          }
        })
      } else if (this.activeTab === 'backlinks') {
        BacklinksView({
          backlinks: this.getBacklinks(),
          onBacklinkClick: (source: string) => {
            if (this.onBacklinkClick) this.onBacklinkClick(source);
          }
        })
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
    .backgroundColor(this.isOverlay ? this.colors().frostedBgThick : this.colors().surface1)
    .backgroundBlurStyle(
      this.isOverlay ? BlurStyle.BACKGROUND_THICK : BlurStyle.BACKGROUND_REGULAR,
      { colorMode: ThemeColorMode.SYSTEM }
    )
    .border({ width: { left: 1 }, color: this.colors().border })
  }
}
