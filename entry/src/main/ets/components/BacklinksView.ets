// components/BacklinksView.ets
// 反向链接与标签面板

import { ObsidianColors, ThemeMode, getColors } from '../utils/Theme';
import { Backlink } from '../models/FileNode';

@Component
export struct BacklinksView {
  @StorageLink('themeMode') themeMode: ThemeMode = ThemeMode.DARK;
  @Prop backlinks: Backlink[] = [];
  @Prop tags: string[] = [];
  @State activeTab: number = 0;

  private colors(): ObsidianColors {
    return getColors(this.themeMode);
  }

  @Builder
  TabButton(index: number, label: string, count: number) {
    Column() {
      Row({ space: 4 }) {
        Text(label)
          .fontSize(12)
          .fontWeight(this.activeTab === index ? FontWeight.Medium : FontWeight.Regular)
          .fontColor(this.activeTab === index ? this.colors().accent : this.colors().textSecondary)

        Text(`${count}`)
          .fontSize(10)
          .fontColor(this.activeTab === index ? this.colors().accent : this.colors().textMuted)
          .backgroundColor(this.activeTab === index ? this.colors().tagBg : this.colors().bgTertiary)
          .padding({ left: 4, right: 4, top: 1, bottom: 1 })
          .borderRadius(8)
      }
    }
    .height(36)
    .padding({ left: 12, right: 12 })
    .border({
      width: { bottom: 2 },
      color: this.activeTab === index ? this.colors().accent : Color.Transparent
    })
    .onClick(() => {
      this.activeTab = index;
    })
  }

  build() {
    Column() {
      // 标签切换
      Row() {
        this.TabButton(0, '反向链接', this.backlinks.length)
        this.TabButton(1, '标签', this.tags.length)
      }
      .width('100%')
      .height(40)
      .padding({ left: 8, right: 8 })
      .backgroundColor(this.colors().sidebarBg)
      .border({ width: { bottom: 1 }, color: this.colors().divider })

      // 内容区
      if (this.activeTab === 0) {
        this.BacklinksContent()
      } else {
        this.TagsContent()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.colors().sidebarBg)
  }

  @Builder
  BacklinksContent() {
    List({ space: 8 }) {
      ForEach(this.backlinks, (link: Backlink, index: number) => {
        ListItem() {
          Column() {
            Row() {
              Text('🔗')
                .fontSize(12)
                .margin({ right: 6 })
              Text(link.source)
                .fontSize(12)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.colors().linkColor)
                .layoutWeight(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .maxLines(1)
            }
            .width('100%')

            Text(link.context)
              .fontSize(11)
              .fontColor(this.colors().textSecondary)
              .margin({ top: 4, left: 18 })
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .lineHeight(16)
          }
          .width('100%')
          .padding(12)
          .backgroundColor(this.colors().bgSecondary)
          .borderRadius(6)
          .border({ width: { left: 3 }, color: this.colors().accent })
        }
      }, (link: Backlink, index: number) => index.toString())
    }
    .width('100%')
    .layoutWeight(1)
    .padding(8)
  }

  @Builder
  TagsContent() {
    List({ space: 4 }) {
      ForEach(this.tags, (tag: string) => {
        ListItem() {
          Text(`#${tag}`)
            .fontSize(12)
            .fontColor(this.colors().tagText)
            .backgroundColor(this.colors().tagBg)
            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            .borderRadius(12)
        }
      }, (tag: string) => tag)
    }
    .width('100%')
    .layoutWeight(1)
    .padding(12)
  }
}
