// components/LinkPreviewCard.ets
// 悬停链接预览卡片 — 光标在 [[wikilink]] 上时显示浮动预览

import { ObsidianColors, ThemeMode, getColors } from '../utils/Theme';

export interface LinkPreviewData {
  title: string;
  snippet: string;
  wordCount: number;
}

@Component
export struct LinkPreviewCard {
  @StorageLink('themeMode') themeMode: ThemeMode = ThemeMode.DARK;
  @Prop data: LinkPreviewData = { title: '', snippet: '', wordCount: 0 };
  @Prop visible: boolean = false;
  onOpenNote?: () => void;
  onOpenInNewTab?: () => void;
  onClose?: () => void;

  private colors(): ObsidianColors {
    return getColors(this.themeMode);
  }

  build() {
    if (this.visible && this.data.title) {
      Column({ space: 0 }) {
        // 标题栏
        Row() {
          Text(this.data.title)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.colors().textPrimary)
            .layoutWeight(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .maxLines(1)

          Button({ type: ButtonType.Circle }) {
            Text('✕')
              .fontSize(10)
              .fontColor(this.colors().textMuted)
          }
          .width(20)
          .height(20)
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            if (this.onClose) {
              this.onClose();
            }
          })
        }
        .width('100%')
        .padding({ left: 12, right: 8, top: 10, bottom: 6 })

        // 内容摘要
        Text(this.data.snippet)
          .fontSize(12)
          .fontColor(this.colors().textSecondary)
          .maxLines(5)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .lineHeight(18)
          .width('100%')
          .padding({ left: 12, right: 12, top: 0, bottom: 8 })

        // 底部操作栏
        Row({ space: 8 }) {
          Text(`${this.data.wordCount} 词`)
            .fontSize(11)
            .fontColor(this.colors().textMuted)

          Blank()

          Button('打开')
            .fontSize(11)
            .fontColor(this.colors().accent)
            .backgroundColor(this.colors().bgHover)
            .height(28)
            .borderRadius(4)
            .padding({ left: 12, right: 12 })
            .onClick(() => {
              if (this.onOpenNote) {
                this.onOpenNote();
              }
            })
        }
        .width('100%')
        .padding({ left: 12, right: 12, top: 4, bottom: 10 })
        .border({ width: { top: 1 }, color: this.colors().divider })
      }
      .width(280)
      .backgroundColor(this.colors().bgSecondary)
      .borderRadius(8)
      .border({ width: 1, color: this.colors().divider })
      .shadow({ radius: 12, color: 'rgba(0,0,0,0.25)', offsetX: 0, offsetY: 4 })
      .position({ x: 'auto', y: 0 })
      .zIndex(250)
    }
  }
}
