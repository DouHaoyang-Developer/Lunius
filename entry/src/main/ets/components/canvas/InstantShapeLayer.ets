// components/canvas/InstantShapeLayer.ets
// 一笔成形集成层 — Pen Kit InstantShapeGenerator + 几何识别降级方案

import { CanvasViewModel } from '../../viewmodels/CanvasViewModel';
import { CanvasNode } from '../../models/CanvasTypes';
import { TouchPoint } from '../../models/DrawingTypes';

export enum RecognizedShape {
  RECTANGLE = 'rectangle',
  CIRCLE = 'circle',
  ELLIPSE = 'ellipse',
  LINE = 'line',
  TRIANGLE = 'triangle',
  DIAMOND = 'diamond',
  ARROW = 'arrow'
}

interface ShapeResult {
  type: RecognizedShape;
  x: number;
  y: number;
  width: number;
  height: number;
  pathPoints?: TouchPoint[];
}

export class InstantShapeEngine {
  private points: TouchPoint[] = [];
  private pauseTimer: number = -1;
  private pauseTimeMs: number = 600;
  private usePenKit: boolean = false;
  private penKitGenerator: Object | null = null;
  onShapeRecognized?: (shape: ShapeResult) => void;

  setPauseTime(ms: number): void {
    this.pauseTimeMs = ms;
  }

  start(x: number, y: number, pressure: number): void {
    this.points = [{ x, y, pressure, time: Date.now() }];
    this.clearTimer();
  }

  move(x: number, y: number, pressure: number): void {
    this.points.push({ x, y, pressure, time: Date.now() });
    this.clearTimer();
  }

  end(): void {
    if (this.points.length < 5) {
      this.points = [];
      return;
    }
    // 停顿超时 → 尝试识别
    this.pauseTimer = setTimeout(() => {
      this.tryRecognize();
    }, this.pauseTimeMs);
  }

  cancel(): void {
    this.clearTimer();
    this.points = [];
  }

  private clearTimer(): void {
    if (this.pauseTimer >= 0) {
      clearTimeout(this.pauseTimer);
      this.pauseTimer = -1;
    }
  }

  private tryRecognize(): void {
    if (this.points.length < 8) return;

    const shape = this.geometricRecognize();
    if (shape && this.onShapeRecognized) {
      this.onShapeRecognized(shape);
    }
    this.points = [];
  }

  // ─── 几何形状识别 ────────────────────────────

  private geometricRecognize(): ShapeResult | null {
    const pts = this.points;
    const bounds = this.getBounds(pts);
    const width = bounds.maxX - bounds.minX;
    const height = bounds.maxY - bounds.minY;

    if (width < 15 && height < 15) return null;

    const circularity = this.circularityRatio(pts, bounds);
    const rectilinearity = this.rectilinearity(pts, bounds);
    const linearity = this.linearityRatio(pts, bounds);

    // 圆度 > 0.8 → 圆或椭圆
    if (circularity > 0.78) {
      if (Math.abs(width - height) / Math.max(width, height) < 0.3) {
        const r = Math.max(width, height) / 2;
        return {
          type: RecognizedShape.CIRCLE,
          x: bounds.minX - 4, y: bounds.minY - 4,
          width: r * 2 + 8, height: r * 2 + 8
        };
      }
      return {
        type: RecognizedShape.ELLIPSE,
        x: bounds.minX - 4, y: bounds.minY - 4,
        width: width + 8, height: height + 8
      };
    }

    // 矩形度 > 0.75 → 矩形
    if (rectilinearity > 0.75) {
      return {
        type: RecognizedShape.RECTANGLE,
        x: bounds.minX - 4, y: bounds.minY - 4,
        width: width + 8, height: height + 8
      };
    }

    // 线性度 > 0.9 → 直线
    if (linearity > 0.9 && pts.length > 5) {
      const first = pts[0];
      const last = pts[pts.length - 1];
      return {
        type: RecognizedShape.LINE,
        x: Math.min(first.x, last.x), y: Math.min(first.y, last.y),
        width: Math.abs(last.x - first.x) + 4, height: Math.abs(last.y - first.y) + 4
      };
    }

    return null;
  }

  private getBounds(pts: TouchPoint[]): { minX: number; minY: number; maxX: number; maxY: number; cx: number; cy: number } {
    let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
    for (const p of pts) {
      if (p.x < minX) minX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.x > maxX) maxX = p.x;
      if (p.y > maxY) maxY = p.y;
    }
    return { minX, minY, maxX, maxY, cx: (minX + maxX) / 2, cy: (minY + maxY) / 2 };
  }

  // 圆度：4π * area / perimeter²
  private circularityRatio(pts: TouchPoint[], bounds: ReturnType<typeof this.getBounds>): number {
    const area = (bounds.maxX - bounds.minX) * (bounds.maxY - bounds.minY);
    let perimeter = 0;
    for (let i = 1; i < pts.length; i++) {
      const dx = pts[i].x - pts[i - 1].x;
      const dy = pts[i].y - pts[i - 1].y;
      perimeter += Math.sqrt(dx * dx + dy * dy);
    }
    if (perimeter === 0) return 0;
    return (4 * Math.PI * area) / (perimeter * perimeter);
  }

  // 矩形度：包围盒面积 vs 凸包面积
  private rectilinearity(pts: TouchPoint[], bounds: ReturnType<typeof this.getBounds>): number {
    const boxArea = (bounds.maxX - bounds.minX) * (bounds.maxY - bounds.minY);
    // 简化：采样点中有多少落在边界附近
    let onEdge = 0;
    for (const p of pts) {
      const distToEdge = Math.min(
        Math.abs(p.x - bounds.minX), Math.abs(p.x - bounds.maxX),
        Math.abs(p.y - bounds.minY), Math.abs(p.y - bounds.maxY)
      );
      const threshold = Math.max(bounds.maxX - bounds.minX, bounds.maxY - bounds.minY) * 0.15;
      if (distToEdge < threshold) onEdge++;
    }
    return onEdge / pts.length;
  }

  // 线性度：Pearson 相关系数
  private linearityRatio(pts: TouchPoint[], bounds: ReturnType<typeof this.getBounds>): number {
    if (pts.length < 3) return 1;
    const n = pts.length;
    let sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0, sumY2 = 0;
    for (const p of pts) {
      sumX += p.x;
      sumY += p.y;
      sumXY += p.x * p.y;
      sumX2 += p.x * p.x;
      sumY2 += p.y * p.y;
    }
    const numerator = n * sumXY - sumX * sumY;
    const denom = Math.sqrt((n * sumX2 - sumX * sumX) * (n * sumY2 - sumY * sumY));
    if (denom === 0) return 1;
    return Math.abs(numerator / denom);
  }

  release(): void {
    this.clearTimer();
    this.points = [];
  }
}

// ─── Canvas 集成辅助 ──────────────────────────

export function shapeToCanvasNode(shape: ShapeResult, genId: () => string): CanvasNode {
  const labelMap: Record<string, string> = {
    [RecognizedShape.RECTANGLE]: '矩形',
    [RecognizedShape.CIRCLE]: '圆',
    [RecognizedShape.ELLIPSE]: '椭圆',
    [RecognizedShape.LINE]: '直线',
    [RecognizedShape.TRIANGLE]: '三角形',
    [RecognizedShape.DIAMOND]: '菱形',
    [RecognizedShape.ARROW]: '箭头'
  };
  return {
    id: genId(),
    type: 'group',
    x: shape.x,
    y: shape.y,
    width: Math.max(shape.width, 40),
    height: Math.max(shape.height, 40),
    label: labelMap[shape.type] || '形状',
    color: '4'
  };
}
