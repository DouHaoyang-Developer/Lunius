// utils/DrawingExport.ets
// 图纸导出 — DrawingPath → SVG / PNG

import { DrawingPath, BrushType, TouchPoint } from '../models/DrawingTypes';
import { BrushEngine } from './BrushEngine';

export class DrawingExport {
  // ─── SVG 导出 ─────────────────────────────────

  static toSvg(paths: DrawingPath[], viewWidth: number = 1200, viewHeight: number = 900): string {
    if (paths.length === 0) {
      return `<svg xmlns="http://www.w3.org/2000/svg" width="${viewWidth}" height="${viewHeight}"></svg>`;
    }

    // 计算全局包围盒
    let globalMinX = Infinity, globalMinY = Infinity;
    let globalMaxX = -Infinity, globalMaxY = -Infinity;
    for (const path of paths) {
      if (path.minX < globalMinX) globalMinX = path.minX;
      if (path.minY < globalMinY) globalMinY = path.minY;
      if (path.maxX > globalMaxX) globalMaxX = path.maxX;
      if (path.maxY > globalMaxY) globalMaxY = path.maxY;
    }

    const padding = 20;
    const contentWidth = globalMaxX - globalMinX + padding * 2;
    const contentHeight = globalMaxY - globalMinY + padding * 2;
    const svgWidth = Math.max(viewWidth, contentWidth);
    const svgHeight = Math.max(viewHeight, contentHeight);

    let svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${svgWidth}" height="${svgHeight}" viewBox="${globalMinX - padding} ${globalMinY - padding} ${contentWidth} ${contentHeight}">\n`;
    svg += `  <rect width="100%" height="100%" fill="white"/>\n`;

    for (const path of paths) {
      svg += DrawingExport.pathToSvgElement(path);
    }

    svg += `</svg>`;
    return svg;
  }

  private static pathToSvgElement(path: DrawingPath): string {
    if (path.points.length < 2) return '';

    const smoothed = BrushEngine.smoothPoints(path.points, 2);
    if (smoothed.length < 2) return '';

    const opacity = path.opacity;
    const strokeLinecap = path.brushType === BrushType.HIGHLIGHTER ? 'square' : 'round';
    const strokeLinejoin = path.brushType === BrushType.HIGHLIGHTER ? 'miter' : 'round';

    let d = `M ${smoothed[0].x.toFixed(1)} ${smoothed[0].y.toFixed(1)}`;
    for (let i = 1; i < smoothed.length; i++) {
      d += ` L ${smoothed[i].x.toFixed(1)} ${smoothed[i].y.toFixed(1)}`;
    }

    // 取平均笔宽
    let totalWidth = 0;
    for (const s of smoothed) {
      totalWidth += s.width;
    }
    const avgWidth = (totalWidth / smoothed.length).toFixed(1);

    return `  <path d="${d}" stroke="${path.color}" stroke-width="${avgWidth}" stroke-linecap="${strokeLinecap}" stroke-linejoin="${strokeLinejoin}" fill="none" opacity="${opacity}"/>\n`;
  }

  // ─── PNG 导出（路径渲染到临时 Canvas 后保存）──

  static renderToCanvas(paths: DrawingPath[],
    ctx: CanvasRenderingContext2D, width: number, height: number): void {
    ctx.clearRect(0, 0, width, height);

    // 白色背景
    ctx.fillStyle = '#FFFFFF';
    ctx.fillRect(0, 0, width, height);

    for (const path of paths) {
      DrawingExport.renderPath(ctx, path);
    }
  }

  private static renderPath(ctx: CanvasRenderingContext2D, path: DrawingPath): void {
    if (path.points.length < 2) return;

    const params = BrushEngine.brushParams(path.brushType);
    ctx.save();
    ctx.globalAlpha = path.opacity;
    ctx.strokeStyle = path.color;
    ctx.lineCap = params.lineCap;
    ctx.lineJoin = params.lineJoin;

    const smoothed = BrushEngine.smoothPoints(path.points);
    if (smoothed.length < 2) { ctx.restore(); return; }

    ctx.beginPath();
    ctx.moveTo(smoothed[0].x, smoothed[0].y);

    for (let i = 1; i < smoothed.length; i++) {
      ctx.lineWidth = Math.max(0.5, path.baseWidth * smoothed[i].width / 6);
      ctx.lineTo(smoothed[i].x, smoothed[i].y);
    }
    ctx.stroke();
    ctx.restore();
  }
}
