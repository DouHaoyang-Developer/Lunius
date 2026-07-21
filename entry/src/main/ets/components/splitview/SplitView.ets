// components/splitview/SplitView.ets
// Lunius 分屏编辑 - 左右同时显示编辑器和预览

import { LuniusColors, ThemeMode, getColors } from '../../utils/Theme';
import { NoteViewModel } from '../../viewmodels/NoteViewModel';

@Component
export struct SplitView {
  @StorageLink('themeMode') themeMode: ThemeMode = ThemeMode.DARK;
  @ObjectLink vm: NoteViewModel;
  @State editorWidth: number = 50; // 百分比
  @State isDragging: boolean = false;

  private colors(): LuniusColors {
    return getColors(this.themeMode);
  }

  build() {
    Row({ space: 0 }) {
      // 编辑器区域
      Column() {
        TextArea({ text: this.vm.content })
          .width('100%')
          .height('100%')
          .fontSize(14)
          .fontColor(this.colors().textPrimary)
          .fontFamily('monospace')
          .backgroundColor(this.colors().surface0)
          .padding(16)
          .onChange((value: string) => {
            this.vm.updateContent(value);
          })
      }
      .width(`${this.editorWidth}%`)
      .height('100%')
      .border({ width: { right: 1 }, color: this.colors().border })

      // 拖拽条
      Column() {
        Row()
          .width(4)
          .height('100%')
          .backgroundColor(this.isDragging ? this.colors().accent : this.colors().border)
          .borderRadius(2)
      }
      .width(8)
      .height('100%')
      .backgroundColor(Color.Transparent)
      .gesture(
        PanGesture()
          .onActionStart(() => {
            this.isDragging = true;
          })
          .onActionUpdate((event: GestureEvent) => {
            // 简化：根据屏幕宽度计算百分比
            // 实际应根据父容器宽度计算
            const delta = (event.offsetX / 800) * 100;
            this.editorWidth = Math.max(20, Math.min(80, this.editorWidth + delta));
          })
          .onActionEnd(() => {
            this.isDragging = false;
          })
      )

      // 预览区域
      Column() {
        Scroll() {
          Column({ space: 12 }) {
            Text(this.vm.title)
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.colors().textPrimary)
              .width('100%')

            Text(this.vm.content.substring(0, 500) + '...')
              .fontSize(14)
              .fontColor(this.colors().textPrimary)
              .width('100%')
              .lineHeight(22)
          }
          .width('100%')
          .padding(16)
        }
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Auto)
      }
      .width(`${100 - this.editorWidth - 1}%`) // 减去拖拽条
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.colors().surface0)
  }
}
