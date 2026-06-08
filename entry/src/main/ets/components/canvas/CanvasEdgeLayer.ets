// components/canvas/CanvasEdgeLayer.ets
// Canvas 连线绘制层 — CanvasRenderingContext2D 绘制连线 + 箭头

import { CanvasEdge, CanvasNode } from '../../models/CanvasTypes';
import { CanvasViewModel } from '../../viewmodels/CanvasViewModel';
import { ObsidianColors, ThemeMode, getColors } from '../../utils/Theme';

@Component
export struct CanvasEdgeLayer {
  @StorageLink('themeMode') themeMode: ThemeMode = ThemeMode.DARK;
  @ObjectLink vm: CanvasViewModel;

  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  private colors(): ObsidianColors {
    return getColors(this.themeMode);
  }

  build() {
    Canvas(this.ctx)
      .width('100%').height('100%')
      .onReady(() => {
        this.drawEdges();
      })
  }

  private drawEdges(): void {
    const ctx = this.ctx;
    ctx.clearRect(0, 0, 9999, 9999);

    const edgeColor = this.colors().textMuted;
    for (const edge of this.vm.edges) {
      const fromNode = this.vm.nodes.find((n: CanvasNode) => n.id === edge.fromNode);
      const toNode = this.vm.nodes.find((n: CanvasNode) => n.id === edge.toNode);
      if (!fromNode || !toNode) continue;

      const fromPt = this.getPortPoint(fromNode, edge.fromSide || 'right');
      const toPt = this.getPortPoint(toNode, edge.toSide || 'left');

      const sx = (fromPt.x + this.vm.offsetX) * this.vm.zoomScale;
      const sy = (fromPt.y + this.vm.offsetY) * this.vm.zoomScale;
      const ex = (toPt.x + this.vm.offsetX) * this.vm.zoomScale;
      const ey = (toPt.y + this.vm.offsetY) * this.vm.zoomScale;

      // 贝塞尔曲线路径
      const cpOffset = Math.abs(ex - sx) * 0.4;
      ctx.beginPath();
      ctx.moveTo(sx, sy);
      ctx.bezierCurveTo(sx + cpOffset, sy, ex - cpOffset, ey, ex, ey);
      ctx.strokeStyle = edge.color || edgeColor;
      ctx.lineWidth = 1.5;
      ctx.stroke();

      // 箭头
      if (edge.toEnd === 'arrow') {
        this.drawArrow(ctx, sx + cpOffset, sy, ex - cpOffset, ey, ex, ey);
      }

      // 标签
      if (edge.label) {
        const mx = (sx + ex) / 2;
        const my = (sy + ey) / 2 - 8;
        ctx.font = '10px sans-serif';
        ctx.fillStyle = this.colors().textSecondary;
        ctx.fillText(edge.label, mx, my);
      }
    }
  }

  private getPortPoint(node: CanvasNode, side: string): { x: number, y: number } {
    switch (side) {
      case 'top': return { x: node.x + node.width / 2, y: node.y };
      case 'bottom': return { x: node.x + node.width / 2, y: node.y + node.height };
      case 'left': return { x: node.x, y: node.y + node.height / 2 };
      case 'right': return { x: node.x + node.width, y: node.y + node.height / 2 };
    }
    return { x: node.x + node.width / 2, y: node.y + node.height / 2 };
  }

  private drawArrow(ctx: CanvasRenderingContext2D,
    cp1x: number, cp1y: number, cp2x: number, cp2y: number,
    ex: number, ey: number): void {
    // 箭头方向由贝塞尔曲线末端切线决定
    const dx = ex - cp2x;
    const dy = ey - cp2y;
    const len = Math.sqrt(dx * dx + dy * dy);
    if (len === 0) return;
    const ux = dx / len;
    const uy = dy / len;
    const arrowSize = 8;

    ctx.beginPath();
    ctx.moveTo(ex, ey);
    ctx.lineTo(ex - ux * arrowSize + uy * arrowSize * 0.5,
      ey - uy * arrowSize - ux * arrowSize * 0.5);
    ctx.lineTo(ex - ux * arrowSize - uy * arrowSize * 0.5,
      ey - uy * arrowSize + ux * arrowSize * 0.5);
    ctx.closePath();
    ctx.fillStyle = ctx.strokeStyle;
    ctx.fill();
  }
}
