// components/BacklinksView.ets
// Backlinks panel — Lunius-style linked mentions with context preview

import { LuniusColors, ThemeMode, getColors, Spacing } from '../utils/Theme';
import { Backlink } from '../models/FileNode';

@Component
export struct BacklinksView {
  @StorageLink('themeMode') themeMode: ThemeMode = ThemeMode.DARK;
  @Prop backlinks: Backlink[] = [];
  onBacklinkClick?: (source: string) => void;

  private colors(): LuniusColors {
    return getColors(this.themeMode);
  }

  private highlightContext(context: string, accent: string, muted: string): string {
    return context;
  }

  @Builder
  BacklinkItem(link: Backlink) {
    Column() {
      Row() {
        Text('\uD83D\uDD17')
          .fontSize(12)
          .fontColor(this.colors().textMuted)
          .margin({ right: Spacing.SM })

        Text(link.source)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.colors().linkColor)
          .layoutWeight(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .maxLines(1)

        Text('L' + String(link.line))
          .fontSize(10)
          .fontColor(this.colors().textMuted)
          .backgroundColor(this.colors().bgTertiary)
          .padding({ left: Spacing.XS, right: Spacing.XS, top: 1, bottom: 1 })
          .borderRadius(3)
          .margin({ left: Spacing.XS })
      }
      .width('100%')

      Text(link.context)
        .fontSize(11)
        .fontColor(this.colors().textSecondary)
        .margin({ top: Spacing.SM, left: 26, right: 0 })
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .lineHeight(17)
    }
    .width('100%')
    .padding(Spacing.MD)
    .backgroundColor(this.colors().bgSecondary)
    .borderRadius(6)
    .border({ width: { left: 2 }, color: this.colors().accent })
    .onClick(() => {
      if (this.onBacklinkClick) {
        this.onBacklinkClick(link.source);
      }
    })
  }

  build() {
    Column() {
      Row() {
        Text('\u53CD\u5411\u94FE\u63A5')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.colors().textSecondary)

        Row({ space: Spacing.XS }) {
          Text(String(this.backlinks.length))
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

      if (this.backlinks.length === 0) {
        Column({ space: Spacing.SM }) {
          Text('\uD83D\uDD17')
            .fontSize(22)
          Text('\u6682\u65E0\u53CD\u5411\u94FE\u63A5')
            .fontSize(12)
            .fontColor(this.colors().textMuted)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: Spacing.SM }) {
          ForEach(this.backlinks, (link: Backlink, index: number) => {
            ListItem() {
              this.BacklinkItem(link)
            }
          }, (link: Backlink, index: number) => String(index))
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
