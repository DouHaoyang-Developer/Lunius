// components/canvas/CanvasToolbar.ets
// Canvas 底部工具栏 — 添加节点 / 缩放控制 / 重置 / 撤销重做

import { ObsidianColors, ThemeMode, getColors } from '../../utils/Theme';
import { CanvasViewModel } from '../../viewmodels/CanvasViewModel';

@Component
export struct CanvasToolbar {
  @StorageLink('themeMode') themeMode: ThemeMode = ThemeMode.DARK;
  @ObjectLink vm: CanvasViewModel;

  private get colors(): ObsidianColors {
    return getColors(this.themeMode);
  }

  build() {
    Row({ space: 8 }) {
      // 添加文本节点
      Button({ type: ButtonType.Circle }) {
        Text('T').fontSize(14).fontWeight(FontWeight.Bold).fontColor(this.colors.textPrimary)
      }
      .width(32).height(32).backgroundColor(this.colors.bgTertiary)
      .onClick(() => { this.vm.addNode('text', 100, 100); })

      // 添加文件节点
      Button({ type: ButtonType.Circle }) {
        Text('📄').fontSize(14)
      }
      .width(32).height(32).backgroundColor(this.colors.bgTertiary)
      .onClick(() => { this.vm.addNode('file', 200, 100); })

      // 添加链接节点
      Button({ type: ButtonType.Circle }) {
        Text('🔗').fontSize(14)
      }
      .width(32).height(32).backgroundColor(this.colors.bgTertiary)
      .onClick(() => { this.vm.addNode('link', 300, 100); })

      // 分隔
      Divider().vertical(true).height(20).color(this.colors.divider)

      // 手写模式切换
      Button({ type: ButtonType.Circle }) {
        Text('✏️').fontSize(14)
      }
      .width(32).height(32)
      .backgroundColor(this.vm.drawingMode !== 'none' ? this.colors.accent : this.colors.bgTertiary)
      .onClick(() => { this.vm.cycleDrawingMode(); })

      // 分隔
      Divider().vertical(true).height(20).color(this.colors.divider)

      // 缩放控制
      Button({ type: ButtonType.Circle }) {
        Text('-').fontSize(16).fontColor(this.colors.textPrimary)
      }
      .width(28).height(28).backgroundColor(this.colors.bgTertiary)
      .onClick(() => {
        this.vm.updateViewport(this.vm.zoomScale * 0.8, this.vm.offsetX, this.vm.offsetY);
      })

      Text(`${Math.round(this.vm.zoomScale * 100)}%`)
        .fontSize(12).fontColor(this.colors.textSecondary)

      Button({ type: ButtonType.Circle }) {
        Text('+').fontSize(16).fontColor(this.colors.textPrimary)
      }
      .width(28).height(28).backgroundColor(this.colors.bgTertiary)
      .onClick(() => {
        this.vm.updateViewport(this.vm.zoomScale * 1.25, this.vm.offsetX, this.vm.offsetY);
      })

      // 分隔
      Divider().vertical(true).height(20).color(this.colors.divider)

      // 撤销/重做
      Button({ type: ButtonType.Circle }) {
        Text('↩').fontSize(14).fontColor(this.colors.textPrimary)
      }
      .width(28).height(28).backgroundColor(this.colors.bgTertiary)
      .onClick(() => { this.vm.undo(); })

      Button({ type: ButtonType.Circle }) {
        Text('↪').fontSize(14).fontColor(this.colors.textPrimary)
      }
      .width(28).height(28).backgroundColor(this.colors.bgTertiary)
      .onClick(() => { this.vm.redo(); })

      // 重置视图
      Button({ type: ButtonType.Circle }) {
        Text('⊡').fontSize(14).fontColor(this.colors.textPrimary)
      }
      .width(28).height(28).backgroundColor(this.colors.bgTertiary)
      .onClick(() => { this.vm.resetView(); })
    }
    .padding({ left: 12, right: 12, top: 6, bottom: 6 })
    .backgroundColor(this.colors.bgSecondary + 'E6')
    .borderRadius(20)
    .shadow({ radius: 4, color: '#00000020' })
  }
}
