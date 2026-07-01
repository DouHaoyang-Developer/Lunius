// components/BookmarkView.ets
// Bookmarks panel — saved notes, headings, and blocks with type badges

import { LuniusColors, ThemeMode, getColors, Spacing } from '../utils/Theme';
import { Bookmark, BookmarkManager } from '../utils/BookmarkManager';

@Component
export struct BookmarkView {
  @StorageLink('themeMode') themeMode: ThemeMode = ThemeMode.DARK;
  @State bookmarks: Bookmark[] = [];
  @State isLoading: boolean = true;
  onOpenNote?: (noteId: string) => void;
  onRemoveBookmark?: (id: string) => void;

  private manager: BookmarkManager = BookmarkManager.getInstance();

  aboutToAppear(): void {
    this.loadBookmarks();
  }

  private colors(): LuniusColors {
    return getColors(this.themeMode);
  }

  async loadBookmarks(): Promise<void> {
    this.isLoading = true;
    try {
      await this.manager.init();
      this.bookmarks = this.manager.getBookmarks();
    } catch (e) {
      console.error('BookmarkView load error: ' + JSON.stringify(e));
    } finally {
      this.isLoading = false;
    }
  }

  async handleRemove(id: string): Promise<void> {
    await this.manager.removeBookmark(id);
    this.bookmarks = this.manager.getBookmarks();
    if (this.onRemoveBookmark) {
      this.onRemoveBookmark(id);
    }
  }

  private typeIcon(type: string): string {
    if (type === 'heading') return '\u00A7';
    if (type === 'block') return '\u25A0';
    return '\uD83D\uDCCC';
  }

  private typeLabel(type: string): string {
    if (type === 'heading') return '\u6807\u9898';
    if (type === 'block') return '\u5757';
    return '\u7B14\u8BB0';
  }

  private formatDate(ts: number): string {
    const d = new Date(ts);
    const month = String(d.getMonth() + 1);
    const day = String(d.getDate());
    const hours = String(d.getHours());
    const mins = String(d.getMinutes());
    const pad = mins.length === 1 ? '0' + mins : mins;
    return month + '/' + day + ' ' + hours + ':' + pad;
  }

  @Builder
  BookmarkItem(bm: Bookmark) {
    Row({ space: Spacing.SM }) {
      Column() {
        Text(this.typeIcon(bm.type))
          .fontSize(14)
          .fontColor(this.colors().accent)
      }
      .width(28)
      .height(28)
      .backgroundColor(this.colors().bgTertiary)
      .borderRadius(6)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)

      Column({ space: 1 }) {
        Text(bm.title)
          .fontSize(13)
          .fontColor(this.colors().textPrimary)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .maxLines(1)
          .lineHeight(18)

        Row({ space: Spacing.SM }) {
          Text(this.typeLabel(bm.type))
            .fontSize(10)
            .fontColor(this.colors().tagText)
            .backgroundColor(this.colors().tagBg)
            .padding({ left: Spacing.XS, right: Spacing.XS, top: 1, bottom: 1 })
            .borderRadius(3)

          Text(this.formatDate(bm.createdAt))
            .fontSize(10)
            .fontColor(this.colors().textMuted)

          if (bm.anchor !== '') {
            Text(bm.anchor)
              .fontSize(10)
              .fontColor(this.colors().textMuted)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .maxLines(1)
              .constraintSize({ maxWidth: 80 })
          }
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Button({ type: ButtonType.Circle }) {
        Text('\u2715')
          .fontSize(10)
          .fontColor(this.colors().textMuted)
      }
      .width(22)
      .height(22)
      .backgroundColor(Color.Transparent)
      .onClick(() => {
        this.handleRemove(bm.id);
      })
    }
    .width('100%')
    .height(48)
    .padding({ left: Spacing.MD, right: Spacing.SM })
    .backgroundColor(this.colors().bgSecondary)
    .borderRadius(6)
    .border({ width: { left: 2 }, color: Color.Transparent })
    .onClick(() => {
      if (this.onOpenNote) {
        this.onOpenNote(bm.noteId);
      }
    })
  }

  build() {
    Column() {
      Row() {
        Text('\u4E66\u7B7E')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.colors().textSecondary)

        Row({ space: Spacing.XS }) {
          Text(String(this.bookmarks.length))
            .fontSize(11)
            .fontColor(this.colors().textMuted)
            .backgroundColor(this.colors().bgTertiary)
            .padding({ left: Spacing.XS, right: Spacing.XS, top: 1, bottom: 1 })
            .borderRadius(8)
        }
      }
      .width('100%')
      .height(36)
      .padding({ left: Spacing.LG, right: Spacing.LG })
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(VerticalAlign.Center)
      .backgroundColor(this.colors().sidebarBg)
      .border({ width: { bottom: 1 }, color: this.colors().divider })

      if (this.isLoading) {
        Column({ space: Spacing.SM }) {
          LoadingProgress()
            .width(24)
            .height(24)
            .color(this.colors().accent)
          Text('\u52A0\u8F7D\u4E2D...')
            .fontSize(12)
            .fontColor(this.colors().textMuted)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.bookmarks.length === 0) {
        Column({ space: Spacing.SM }) {
          Text('\uD83D\uDCCC')
            .fontSize(24)
          Text('\u6682\u65E0\u4E66\u7B7E')
            .fontSize(12)
            .fontColor(this.colors().textMuted)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: Spacing.SM }) {
          ForEach(this.bookmarks, (bm: Bookmark, index: number) => {
            ListItem() {
              this.BookmarkItem(bm)
            }
          }, (bm: Bookmark) => bm.id)
        }
        .width('100%')
        .layoutWeight(1)
        .padding(Spacing.SM)
        .backgroundColor(this.colors().sidebarBg)
        .scrollBar(BarState.Auto)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.colors().sidebarBg)
  }
}
