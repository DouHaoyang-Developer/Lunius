// components/BacklinksView.ets
// 反向链接面板 — 显示引用当前笔记的来源
// 设计：来源文件名+上下文预览，hover 态

import { LuniusColors, ThemeMode, getColors, Spacing, Radius, Icons } from '../utils/Theme';
import { Backlink } from '../models/FileNode';

@Component
export struct BacklinksView {
  @StorageLink('themeMode') themeMode: ThemeMode = ThemeMode.DARK;
  @Prop backlinks: Backlink[] = [];
  @State hoverIndex: number = -1;
  onBacklinkClick?: (source: string) => void;

  private colors(): LuniusColors {
    return getColors(this.themeMode);
  }

  @Builder
  BacklinkItem(link: Backlink, index: number) {
    Column({ space: 4 }) {
      // 来源文件名
      Row({ space: Spacing.XS }) {
        Text(Icons.LINK)
          .fontSize(10)
          .fontColor(this.colors().textTertiary)
        Text(link.source)
          .fontSize(12)
          .fontColor(this.colors().textPrimary)
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
      }

      // 上下文预览
      Text(link.context)
        .fontSize(11)
        .fontColor(this.colors().textTertiary)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .lineHeight(16)
    }
    .width('100%')
    .padding(Spacing.SM)
    .backgroundColor(this.hoverIndex === index
      ? this.colors().surfaceHover : this.colors().surface2)
    .borderRadius(Radius.SM)
    .border({ width: 1, color: this.colors().border })
    .onClick(() => {
      if (this.onBacklinkClick) this.onBacklinkClick(link.source);
    })
    .onHover((isHover: boolean) => {
      this.hoverIndex = isHover ? index : -1;
    })
  }

  @Builder
  EmptyState() {
    Column({ space: Spacing.SM }) {
      Text(Icons.LINK)
        .fontSize(28)
        .fontColor(this.colors().textTertiary)
      Text('\u6682\u65E0\u53CD\u5411\u94FE\u63A5')
        .fontSize(12)
        .fontColor(this.colors().textTertiary)
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Column() {
      if (this.backlinks.length === 0) {
        this.EmptyState()
      } else {
        // 顶部计数
        Row() {
          Text(String(this.backlinks.length) + ' \u4E2A\u53CD\u5411\u94FE\u63A5')
            .fontSize(11)
            .fontColor(this.colors().textTertiary)
        }
        .width('100%')
        .height(32)
        .padding({ left: Spacing.MD })
        .backgroundColor(this.colors().surface1)
        .border({ width: { bottom: 1 }, color: this.colors().border })

        List({ space: Spacing.SM }) {
          ForEach(this.backlinks, (link: Backlink, index: number) => {
            ListItem() {
              this.BacklinkItem(link, index)
            }
          }, (link: Backlink, index: number) => String(index))
        }
        .width('100%')
        .layoutWeight(1)
        .padding(Spacing.SM)
        .scrollBar(BarState.Auto)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.colors().surface1)
  }
}
