// components/OutlineView.ets
// 大纲面板 — 文档标题层级树
// 设计：缩进+层级标签+hover/active 态

import { LuniusColors, ThemeMode, getColors, Spacing, Radius } from '../utils/Theme';
import { OutlineNode } from '../models/FileNode';

@Component
export struct OutlineView {
  @StorageLink('themeMode') themeMode: ThemeMode = ThemeMode.DARK;
  @Prop data: OutlineNode[] = [];
  @State activeLine: number = -1;
  @State hoverIndex: number = -1;
  onJump?: (line: number) => void;

  private colors(): LuniusColors {
    return getColors(this.themeMode);
  }

  private indentPx(level: number): number {
    return (level - 1) * 16;
  }

  private headingSize(level: number): number {
    if (level === 1) return 13;
    if (level === 2) return 12;
    return 11;
  }

  private headingWeight(level: number): FontWeight {
    if (level === 1) return FontWeight.Medium;
    if (level === 2) return FontWeight.Medium;
    return FontWeight.Regular;
  }

  @Builder
  OutlineItem(item: OutlineNode, index: number) {
    Row({ space: Spacing.XS }) {
      // 层级标签
      Text('H' + String(item.level))
        .fontSize(9)
        .fontColor(item.level === 1
          ? this.colors().accent : this.colors().textTertiary)
        .backgroundColor(item.level === 1
          ? this.colors().accentSubtle : this.colors().surface2)
        .padding({ left: 4, right: 4, top: 1, bottom: 1 })
        .borderRadius(Radius.XS)
        .margin({ right: Spacing.XS })

      Text(item.title)
        .fontSize(this.headingSize(item.level))
        .fontColor(this.activeLine === item.line
          ? this.colors().accent : this.colors().textPrimary)
        .fontWeight(this.headingWeight(item.level))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: this.indentPx(item.level) + Spacing.SM, right: Spacing.SM, top: 5, bottom: 5 })
    .backgroundColor(this.activeLine === item.line
      ? this.colors().surfaceActive
      : this.hoverIndex === index ? this.colors().surfaceHover : Color.Transparent)
    .borderRadius(Radius.SM)
    .onClick(() => {
      this.activeLine = item.line;
      if (this.onJump) this.onJump(item.line);
    })
    .onHover((isHover: boolean) => {
      this.hoverIndex = isHover ? index : -1;
    })
  }

  @Builder
  EmptyState() {
    Column({ space: Spacing.SM }) {
      Text('\u2261')
        .fontSize(28)
        .fontColor(this.colors().textTertiary)
      Text('\u6682\u65E0\u5927\u7EB2')
        .fontSize(12)
        .fontColor(this.colors().textTertiary)
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Column() {
      if (this.data.length === 0) {
        this.EmptyState()
      } else {
        List({ space: 1 }) {
          ForEach(this.data, (item: OutlineNode, index: number) => {
            ListItem() {
              this.OutlineItem(item, index)
            }
          }, (item: OutlineNode, index: number) => String(index))
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
