// components/canvas/DrawingToolbar.ets
// 绘制工具栏 — 笔刷/颜色/宽度选择 + 橡皮擦 + 清除

import { LuniusColors, ThemeMode, getColors } from '../../utils/Theme';
import { CanvasViewModel } from '../../viewmodels/CanvasViewModel';
import { BrushType, getBrushPreset, PALETTE_COLORS } from '../../models/DrawingTypes';

@Component
export struct DrawingToolbar {
  @StorageLink('themeMode') themeMode: ThemeMode = ThemeMode.DARK;
  @ObjectLink vm: CanvasViewModel;

  private colors(): LuniusColors {
    return getColors(this.themeMode);
  }

  private brushTypes(): BrushType[] {
    return [BrushType.PEN, BrushType.PENCIL, BrushType.MARKER, BrushType.HIGHLIGHTER];
  }

  build() {
    Column({ space: 8 }) {
      // ---- 第一行：笔刷类型 ----
      Row({ space: 6 }) {
        ForEach(this.brushTypes(), (type: BrushType) => {
          const preset = getBrushPreset(type);
          Button() {
            Text(preset.icon).fontSize(16)
          }
          .width(36).height(36)
          .backgroundColor(this.vm.brushType === type ? this.colors().accent : this.colors().bgTertiary)
          .borderRadius(8)
          .onClick(() => { this.vm.setBrushType(type); })
        }, (type: BrushType) => type)

        Divider().vertical(true).height(28).color(this.colors().divider)

        // 一笔成形
        Button() {
          Text('⬠').fontSize(16)
        }
        .width(36).height(36)
        .backgroundColor(this.vm.drawingMode === 'shape' ? this.colors().accent : this.colors().bgTertiary)
        .borderRadius(8)
        .onClick(() => {
          this.vm.drawingMode = this.vm.drawingMode === 'shape' ? 'freehand' : 'shape';
        })

        // 橡皮擦切换
        Button() {
          Text('🧹').fontSize(16)
        }
        .width(36).height(36)
        .backgroundColor(this.vm.drawingMode === 'eraser' ? this.colors().accent : this.colors().bgTertiary)
        .borderRadius(8)
        .onClick(() => {
          this.vm.drawingMode = this.vm.drawingMode === 'eraser' ? 'freehand' : 'eraser';
        })
      }
      .width('100%').justifyContent(FlexAlign.Center)

      // ---- 第二行：颜色选择 + 宽度 ----
      Row({ space: 6 }) {
        // 颜色圆点
        ForEach(PALETTE_COLORS, (color: string) => {
          Stack() {
            Column()
              .width(24).height(24).borderRadius(12)
              .backgroundColor(color)
              .border({
                width: color === '#FFFFFF' ? 1 : 0,
                color: this.colors().divider
              })
            if (this.vm.brushColor === color) {
              Column()
                .width(8).height(8).borderRadius(4)
                .backgroundColor(color === '#000000' ? '#FFFFFF' : '#000000')
            }
          }
          .width(28).height(28)
          .onClick(() => { this.vm.brushColor = color; })
        }, (color: string) => color)

        Divider().vertical(true).height(28).color(this.colors().divider)

        // 笔宽滑块
        Column({ space: 2 }) {
          Text(`${this.vm.brushWidth.toFixed(1)}`)
            .fontSize(10).fontColor(this.colors().textSecondary).textAlign(TextAlign.Center)
          Slider({
            value: this.vm.brushWidth,
            min: 1, max: 12, step: 0.5
          })
            .width(60).height(16)
            .selectedColor(this.colors().accent)
            .onChange((value: number) => { this.vm.brushWidth = value; })
        }
      }
      .width('100%').justifyContent(FlexAlign.Center)

      // ---- 第三行：操作按钮 ----
      Row({ space: 12 }) {
        Button('清除全部')
          .fontSize(12).fontColor('#E74C3C')
          .height(30).padding({ left: 12, right: 12 })
          .backgroundColor(this.colors().bgTertiary).borderRadius(6)
          .onClick(() => { this.vm.clearDrawing(); })

        Button('完成')
          .fontSize(12).fontColor(Color.White)
          .height(30).padding({ left: 20, right: 20 })
          .backgroundColor(this.colors().accent).borderRadius(6)
          .onClick(() => { this.vm.drawingMode = 'none'; })
      }
      .width('100%').justifyContent(FlexAlign.Center)
    }
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .backgroundColor(this.colors().bgSecondary + 'EE')
    .borderRadius(16)
    .shadow({ radius: 6, color: '#00000030' })
  }
}
