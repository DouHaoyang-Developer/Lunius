// components/OutlineView.ets
// 文档大纲视图

import { LuniusColors, ThemeMode, getColors } from '../utils/Theme';
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

  private getIndent(level: number): number {
    return (level - 1) * 16;
  }

  private getFontSize(level: number): number {
    switch (level) {
      case 1: return 14;
      case 2: return 13;
      default: return 12;
    }
  }

  private getFontWeight(level: number): FontWeight {
    return level === 1 ? FontWeight.Medium : FontWeight.Regular;
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Text('大纲')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.colors().textSecondary)

        Text(`${this.data.length} 节`)
          .fontSize(11)
          .fontColor(this.colors().textMuted)
      }
      .width('100%')
      .height(40)
      .padding({ left: 16, right: 16 })
      .justifyContent(FlexAlign.SpaceBetween)
      .backgroundColor(this.colors().sidebarBg)
      .border({ width: { bottom: 1 }, color: this.colors().divider })

      // 大纲列表
      List({ space: 0 }) {
        ForEach(this.data, (item: OutlineNode, index: number) => {
          ListItem() {
            Row() {
              Row()
                .width(this.getIndent(item.level))
                .height('100%')

              Text('H' + item.level)
                .fontSize(9)
                .fontColor(this.colors().textMuted)
                .width(20)
                .textAlign(TextAlign.Center)
                .margin({ right: 4 })

              Text(item.title)
                .fontSize(this.getFontSize(item.level))
                .fontWeight(this.getFontWeight(item.level))
                .fontColor(this.activeLine === item.line 
                  ? this.colors().accent 
                  : this.colors().textPrimary)
                .layoutWeight(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .maxLines(1)
            }
            .width('100%')
            .height(32)
            .padding({ left: 12, right: 16 })
            .backgroundColor(this.activeLine === item.line 
              ? this.colors().bgActive 
              : Color.Transparent)
            .borderRadius(4)
            .onClick(() => {
              this.activeLine = item.line;
              if (this.onJump) {
                this.onJump(item.line);
              }
            })
          }
        }, (item: OutlineNode) => item.line.toString())
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ top: 4 })
      .backgroundColor(this.colors().sidebarBg)
      .scrollBar(BarState.Auto)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.colors().sidebarBg)
  }
}
