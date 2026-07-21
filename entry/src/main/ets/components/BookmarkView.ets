// components/BookmarkView.ets
// 书签面板 — 已保存的笔记、标题和块
// 设计：类型徽标+标题，hover 态，空状态

import { LuniusColors, ThemeMode, getColors, Spacing, Radius, Icons } from '../utils/Theme';
import { Bookmark, BookmarkManager } from '../utils/BookmarkManager';

@Component
export struct BookmarkView {
  @StorageLink('themeMode') themeMode: ThemeMode = ThemeMode.DARK;
  @State bookmarks: Bookmark[] = [];
  @State isLoading: boolean = true;
  @State hoverIndex: number = -1;
  onOpenNote?: (noteId: string) => void;
  onRemoveBookmark?: (id: string) => void;

  private manager: BookmarkManager = BookmarkManager.getInstance();

  aboutToAppear(): void {
    this.loadBookmarks();
  }

  private colors(): LuniusColors {
    return getColors(this.themeMode);
  }

  private typeIcon(type: string): string {
    if (type === 'heading') return 'H';
    if (type === 'block') return '\u00A7';
    return '\u25C6';
  }

  private typeLabel(type: string): string {
    if (type === 'heading') return '\u6807\u9898';
    if (type === 'block') return '\u5757';
    return '\u7B14\u8BB0';
  }

  async loadBookmarks(): Promise<void> {
    this.isLoading = true;
    try {
      await this.manager.init();
      this.bookmarks = this.manager.getBookmarks();
    } catch (e) {
      this.bookmarks = [];
    }
    this.isLoading = false;
  }

  @Builder
  BookmarkItem(bm: Bookmark, index: number) {
    Row({ space: Spacing.SM }) {
      // 类型徽标
      Column() {
        Text(this.typeIcon(bm.type))
          .fontSize(10)
          .fontColor(this.colors().accent)
      }
      .width(24).height(24)
      .backgroundColor(this.colors().accentSubtle)
      .borderRadius(Radius.XS)
      .justifyContent(FlexAlign.Center)

      // 标题
      Column({ space: 2 }) {
        Text(bm.title)
          .fontSize(12)
          .fontColor(this.colors().textPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.typeLabel(bm.type))
          .fontSize(10)
          .fontColor(this.colors().textTertiary)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .height(44)
    .padding({ left: Spacing.SM, right: Spacing.SM })
    .backgroundColor(this.hoverIndex === index
      ? this.colors().surfaceHover : Color.Transparent)
    .borderRadius(Radius.SM)
    .onClick(() => {
      if (this.onOpenNote) this.onOpenNote(bm.noteId);
    })
    .onHover((isHover: boolean) => {
      this.hoverIndex = isHover ? index : -1;
    })
  }

  @Builder
  EmptyState() {
    Column({ space: Spacing.SM }) {
      Text(Icons.BOOKMARK)
        .fontSize(28)
        .fontColor(this.colors().textTertiary)
      Text('\u6682\u65E0\u4E66\u7B7E')
        .fontSize(12)
        .fontColor(this.colors().textTertiary)
      Text('\u5728\u7B14\u8BB0\u4E2D\u6309 Ctrl+M \u6DFB\u52A0\u4E66\u7B7E')
        .fontSize(10)
        .fontColor(this.colors().textTertiary)
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Column() {
      if (this.isLoading) {
        Column({ space: Spacing.SM }) {
          Text(Icons.LOADING)
            .fontSize(20)
            .fontColor(this.colors().textTertiary)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.bookmarks.length === 0) {
        this.EmptyState()
      } else {
        // 顶部计数
        Row() {
          Text(String(this.bookmarks.length) + ' \u4E2A\u4E66\u7B7E')
            .fontSize(11)
            .fontColor(this.colors().textTertiary)
        }
        .width('100%')
        .height(32)
        .padding({ left: Spacing.MD })
        .backgroundColor(this.colors().surface1)
        .border({ width: { bottom: 1 }, color: this.colors().border })

        List({ space: 1 }) {
          ForEach(this.bookmarks, (bm: Bookmark, index: number) => {
            ListItem() {
              this.BookmarkItem(bm, index)
            }
          }, (bm: Bookmark) => bm.id)
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ top: Spacing.XS, bottom: Spacing.XS })
        .scrollBar(BarState.Auto)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.colors().surface1)
  }
}
