// components/canvas/PenKitCard.ets
// Pen Kit 手写卡片 — HandwriteComponent 包装 + .pen 文件持久化

import { LuniusColors, ThemeMode, getColors } from '../../utils/Theme';
import { CanvasNode } from '../../models/CanvasTypes';

@Component
export struct PenKitCard {
  @StorageLink('themeMode') themeMode: ThemeMode = ThemeMode.DARK;
  @Prop node: CanvasNode;
  @Prop isSelected: boolean = false;
  @Prop zoomScale: number = 1;
  onTap?: () => void;
  onDoubleTap?: () => void;
  onSave?: (penFilePath: string) => void;

  @State private label: string = '手写笔记';
  @State private isLoaded: boolean = false;

  private colors(): LuniusColors {
    return getColors(this.themeMode);
  }

  aboutToAppear(): void {
    if (this.node.penFilePath) {
      this.label = this.node.penFilePath.split('/').pop()?.replace('.pen', '') || '手写笔记';
    }
    this.isLoaded = true;
  }

  build() {
    Column({ space: 6 }) {
      // 头部
      Row({ space: 6 }) {
        Text('✒️').fontSize(16)
        Text(this.label)
          .fontSize(13).fontWeight(FontWeight.Medium)
          .fontColor(this.colors().textPrimary)
          .layoutWeight(1).maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .padding({ left: 8, right: 8, top: 6, bottom: 2 })

      // 占位画布区域
      Column() {
        if (this.isLoaded) {
          // Pen Kit HandwriteComponent 集成点
          // 真机环境下启用以下代码：
          // HandwriteComponent({
          //   handwriteController: this.controller,
          //   onInit: () => {
          //     if (this.node.penFilePath) {
          //       this.controller.load(this.node.penFilePath);
          //     }
          //   }
          // })
          Text('✏️ 点击编写手写笔记')
            .fontSize(11).fontColor(this.colors().textMuted)
        }
      }
      .width('100%').height(60)
      .backgroundColor(this.colors().bgTertiary)
      .borderRadius(4)
      .justifyContent(FlexAlign.Center)

      // 底部信息
      Row() {
        Text('.pen')
          .fontSize(10).fontColor(this.colors().textMuted)
        Text('Pen Kit')
          .fontSize(10).fontColor(this.colors().accent)
          .margin({ left: 4 })
      }
      .width('100%')
      .padding({ left: 8, right: 8, bottom: 6 })
    }
    .width(this.node.width * this.zoomScale)
    .height(this.node.height * this.zoomScale)
    .backgroundColor(this.colors().bgSecondary)
    .border({
      width: this.isSelected ? 2 : 1,
      color: this.isSelected ? this.colors().accent : this.colors().divider
    })
    .borderRadius(6)
    .shadow(this.isSelected ? { radius: 8, color: this.colors().accent + '40' } : {})
    .onClick(() => { if (this.onTap) this.onTap(); })
  }
}
