// components/BookmarkView.ets
// 书签面板 — 显示和管理已收藏的笔记/标题/块

import { ObsidianColors, ThemeMode, getColors } from '../utils/Theme';
import { Bookmark, BookmarkManager } from '../utils/BookmarkManager';

@Component
export struct BookmarkView {
  @StorageLink('themeMode') themeMode: ThemeMode = ThemeMode.DARK;
  @State bookmarks: Bookmark[] = [];
  @State isLoading: boolean = true;
  onOpenNote?: (noteId: string) => void;

  private manager: BookmarkManager = BookmarkManager.getInstance();

  aboutToAppear(): void {
    this.loadBookmarks();
  }

  private colors(): ObsidianColors {
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

  async removeBookmark(id: string): Promise<void> {
    await this.manager.removeBookmark(id);
    this.bookmarks = this.manager.getBookmarks();
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Text('书签')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.colors().textSecondary)
        Text(`${this.bookmarks.length}`)
          .fontSize(11)
          .fontColor(this.colors().textMuted)
      }
      .width('100%')
      .height(40)
      .padding({ left: 16, right: 16 })
      .justifyContent(FlexAlign.SpaceBetween)
      .backgroundColor(this.colors().sidebarBg)
      .border({ width: { bottom: 1 }, color: this.colors().divider })

      if (this.isLoading) {
        Text('加载中...')
          .fontSize(12)
          .fontColor(this.colors().textMuted)
          .margin(16)
      } else if (this.bookmarks.length === 0) {
        Text('暂无书签')
          .fontSize(12)
          .fontColor(this.colors().textMuted)
          .margin(16)
      } else {
        List({ space: 4 }) {
          ForEach(this.bookmarks, (bm: Bookmark) => {
            ListItem() {
              Row({ space: 8 }) {
                Text(bm.type === 'heading' ? '§' : '📌')
                  .fontSize(13)
                Column({ space: 2 }) {
                  Text(bm.title)
                    .fontSize(13)
                    .fontColor(this.colors().textPrimary)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .maxLines(1)
                  Text(bm.anchor || bm.noteId)
                    .fontSize(10)
                    .fontColor(this.colors().textMuted)
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                Button({ type: ButtonType.Circle }) {
                  Text('✕')
                    .fontSize(10)
                    .fontColor(this.colors().textMuted)
                }
                .width(20)
                .height(20)
                .backgroundColor(Color.Transparent)
                .onClick(() => {
                  this.removeBookmark(bm.id);
                })
              }
              .width('100%')
              .height(36)
              .padding({ left: 16, right: 12 })
              .onClick(() => {
                if (this.onOpenNote) {
                  this.onOpenNote(bm.noteId);
                }
              })
            }
          }, (bm: Bookmark) => bm.id)
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.colors().sidebarBg)
  }
}
