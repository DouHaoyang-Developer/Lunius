// components/OutlineView.ets
// Document outline panel — Obsidian-style indented headings with level badges

import { LuniusColors, ThemeMode, getColors, Spacing } from '../utils/Theme';
import { OutlineNode } from '../models/FileNode';

@Component
export struct OutlineView {
  @StorageLink('themeMode') themeMode: ThemeMode = ThemeMode.DARK;
  @Prop data: OutlineNode[] = [];
  @State activeLine: number = -1;
  onJump?: (line: number) => void;

  private colors(): LuniusColors {
    return getColors(this.themeMode);
  }

  private indentPx(level: number): number {
    return (level - 1) * 14;
  }

  private headingSize(level: number): number {
    if (level === 1) return 13;
    if (level === 2) return 12;
    return 11;
  }

  private headingWeight(level: number): FontWeight {
    if (level <= 2) return FontWeight.Medium;
    return FontWeight.Regular;
  }

  private opacityForLevel(level: number): number {
    if (level === 1) return 1.0;
    if (level === 2) return 0.85;
    return 0.7;
  }

  build() {
    Column() {
      Row() {
        Text('\u5927\u7EB2')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.colors().textSecondary)

        Text(String(this.data.length) + ' \u8282')
          .fontSize(11)
          .fontColor(this.colors().textMuted)
      }
      .width('100%')
      .height(36)
      .padding({ left: Spacing.LG, right: Spacing.LG })
      .justifyContent(FlexAlign.SpaceBetween)
      .backgroundColor(this.colors().sidebarBg)
      .border({ width: { bottom: 1 }, color: this.colors().divider })

      if (this.data.length === 0) {
        Column({ space: Spacing.SM }) {
          Text('\uD83D\uDCCB')
            .fontSize(22)
          Text('\u6682\u65E0\u5927\u7EB2')
            .fontSize(12)
            .fontColor(this.colors().textMuted)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 0 }) {
          ForEach(this.data, (item: OutlineNode, index: number) => {
            ListItem() {
              Row() {
                Row()
                  .width(this.indentPx(item.level))
                  .height('100%')

                Text('H' + String(item.level))
                  .fontSize(9)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.activeLine === item.line
                    ? this.colors().accent
                    : this.colors().textMuted)
                  .width(20)
                  .textAlign(TextAlign.Center)
                  .padding({ top: 1, bottom: 1 })
                  .margin({ right: Spacing.XS })

                Text(item.title)
                  .fontSize(this.headingSize(item.level))
                  .fontWeight(this.headingWeight(item.level))
                  .fontColor(this.activeLine === item.line
                    ? this.colors().accent
                    : this.colors().textPrimary)
                  .opacity(this.activeLine === item.line
                    ? 1.0
                    : this.opacityForLevel(item.level))
                  .layoutWeight(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .maxLines(1)

                if (this.activeLine === item.line) {
                  Row()
                    .width(2)
                    .height(16)
                    .backgroundColor(this.colors().accent)
                    .borderRadius(1)
                    .margin({ left: Spacing.SM })
                }
              }
              .width('100%')
              .height(30)
              .padding({ left: Spacing.MD, right: Spacing.LG })
              .backgroundColor(this.activeLine === item.line
                ? this.colors().bgActive
                : Color.Transparent)
              .borderRadius(4)
              .margin({ left: Spacing.XS, right: Spacing.XS })
              .onClick(() => {
                this.activeLine = item.line;
                if (this.onJump) {
                  this.onJump(item.line);
                }
              })
            }
          }, (item: OutlineNode, index: number) => String(index))
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ top: Spacing.XS, bottom: Spacing.XS })
        .backgroundColor(this.colors().sidebarBg)
        .scrollBar(BarState.Auto)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.colors().sidebarBg)
  }
}
