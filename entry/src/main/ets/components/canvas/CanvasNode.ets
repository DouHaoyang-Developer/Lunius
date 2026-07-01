// components/canvas/CanvasNode.ets
// Canvas 节点渲染组件 — 支持 text/file/link/group 四种类型

import { LuniusColors, ThemeMode, getColors } from '../../utils/Theme';
import { CanvasNode, CANVAS_PRESET_COLORS } from '../../models/CanvasTypes';
import { PenKitCard } from './PenKitCard';

@Component
export struct CanvasNodeComponent {
  @StorageLink('themeMode') themeMode: ThemeMode = ThemeMode.DARK;
  @Prop node: CanvasNode;
  @Prop isSelected: boolean = false;
  @Prop zoomScale: number = 1;
  onTap?: () => void;
  onDoubleTap?: () => void;
  onDragEnd?: (x: number, y: number) => void;
  onPortDragStart?: (side: string) => void;
  onPortDragEnd?: (targetId: string) => void;

  @State private dragStartX: number = 0;
  @State private dragStartY: number = 0;

  private colors(): LuniusColors {
    return getColors(this.themeMode);
  }

  private nodeColor(): string {
    if (this.node.color) {
      const idx = parseInt(this.node.color);
      if (!isNaN(idx) && idx >= 1 && idx <= 6) {
        return CANVAS_PRESET_COLORS[idx - 1];
      }
      if (this.node.color.startsWith('#')) return this.node.color;
    }
    return this.colors().accent;
  }

  private truncatedText(text: string, maxLen: number): string {
    if (text.length <= maxLen) return text;
    return text.substring(0, maxLen) + '...';
  }

  build() {
    Column() {
      if (this.node.type === 'group') {
        // Group 节点：半透明背景 + 标签
        Column() {
          if (this.node.label) {
            Text(this.node.label)
              .fontSize(13).fontWeight(FontWeight.Medium)
              .fontColor(this.colors().textPrimary)
              .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          }
        }
        .width(this.node.width * this.zoomScale)
        .height(this.node.height * this.zoomScale)
        .backgroundColor(this.nodeColor() + '20')
        .border({ width: 1.5, color: this.nodeColor(), style: BorderStyle.Dashed })
        .borderRadius(8)
        .alignItems(HorizontalAlign.Start)
        .justifyContent(FlexAlign.Start)
      } else if (this.node.type === 'drawing') {
        PenKitCard({
          node: this.node,
          isSelected: this.isSelected,
          zoomScale: this.zoomScale,
          onTap: () => { if (this.onTap) this.onTap(); },
          onDoubleTap: () => { if (this.onDoubleTap) this.onDoubleTap(); }
        })
      } else {
        // 普通节点
        Column({ space: 4 }) {
          // 头部（类型图标 + 标题）
          Row({ space: 6 }) {
            Text(this.typeIcon())
              .fontSize(14)
            Text(this.nodeTitle())
              .fontSize(12).fontWeight(FontWeight.Medium)
              .fontColor(this.colors().textPrimary)
              .layoutWeight(1).maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .width('100%')
          .padding({ left: 8, right: 8, top: 6, bottom: 2 })

          // 内容预览
          Text(this.nodePreview())
            .fontSize(11).fontColor(this.colors().textSecondary)
            .width('100%').maxLines(3)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
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
      }

      // 连线端口（四个边缘中点）
      if (this.isSelected && this.node.type !== 'drawing') {
        this.PortDot('top')
        this.PortDot('bottom')
        this.PortDot('left')
        this.PortDot('right')
      }
    }
    .onClick(() => { if (this.onTap) this.onTap(); })
    .gesture(
      PanGesture({ fingers: 1, direction: PanDirection.All })
        .onActionStart((event: GestureEvent) => {
          this.dragStartX = this.node.x;
          this.dragStartY = this.node.y;
        })
        .onActionUpdate((event: GestureEvent) => {
          if (event.offsetX !== undefined && event.offsetY !== undefined && this.onDragEnd) {
            this.onDragEnd(
              this.dragStartX + event.offsetX / this.zoomScale,
              this.dragStartY + event.offsetY / this.zoomScale
            );
          }
        })
    )
  }

  @Builder
  PortDot(side: string) {
    Stack()
      .width(12).height(12)
      .backgroundColor(this.colors().accent)
      .borderRadius(6)
      .position(this.portPosition(side))
      .onClick(() => { if (this.onPortDragStart) this.onPortDragStart(side); })
  }

  private portPosition(side: string): { x: number | string, y: number | string } {
    const w = this.node.width * this.zoomScale;
    const h = this.node.height * this.zoomScale;
    switch (side) {
      case 'top': return { x: w / 2 - 6, y: -6 };
      case 'bottom': return { x: w / 2 - 6, y: h - 6 };
      case 'left': return { x: -6, y: h / 2 - 6 };
      case 'right': return { x: w - 6, y: h / 2 - 6 };
    }
    return { x: 0, y: 0 };
  }

  private typeIcon(): string {
    switch (this.node.type) {
      case 'text': return '📝';
      case 'file': return '📄';
      case 'link': return '🔗';
      case 'drawing': return '✒️';
    }
    return '📝';
  }

  private nodeTitle(): string {
    if (this.node.type === 'text' && this.node.text) {
      const firstLine = this.node.text.split('\n')[0];
      return firstLine.replace(/^#+\s*/, '');
    }
    if (this.node.type === 'file' && this.node.file) {
      return this.node.file.replace('.md', '').split('/').pop() || this.node.file;
    }
    if (this.node.type === 'link' && this.node.url) {
      return this.truncatedText(this.node.url, 30);
    }
    return '';
  }

  private nodePreview(): string {
    if (this.node.type === 'text' && this.node.text) {
      const lines = this.node.text.split('\n');
      const nonHeading = lines.find((l: string) => l.length > 0 && !l.startsWith('#'));
      return this.truncatedText(nonHeading || '', 80);
    }
    if (this.node.type === 'file' && this.node.file) {
      return `📂 ${this.node.file}`;
    }
    if (this.node.type === 'link' && this.node.url) {
      return `🌐 ${this.truncatedText(this.node.url, 50)}`;
    }
    return '';
  }
}
