// utils/BrushEngine.ets
// 画笔引擎 — 笔迹平滑 + 压感映射 + 笔刷纹理 + 速度感知

import { BrushType, TouchPoint } from '../models/DrawingTypes';

export interface RenderPoint {
  x: number;
  y: number;
  width: number;
}

export class BrushEngine {
  // ─── 压感 → 笔宽映射 ──────────────────────────

  static mapPressure(type: BrushType, pressure: number, baseWidth: number): number {
    if (pressure <= 0) pressure = 0.1;
    switch (type) {
      case BrushType.PEN:
        return baseWidth * 0.3 + pressure * baseWidth * 0.7;
      case BrushType.PENCIL:
        return baseWidth * 0.6 + pressure * baseWidth * 0.4;
      case BrushType.MARKER:
        return baseWidth * 0.8 + pressure * baseWidth * 0.2;
      case BrushType.HIGHLIGHTER:
        return baseWidth;
    }
  }

  // ─── 速度感知变细 ──────────────────────────────

  static speedFactor(p1: TouchPoint, p2: TouchPoint): number {
    const dx = p2.x - p1.x;
    const dy = p2.y - p1.y;
    const dist = Math.sqrt(dx * dx + dy * dy);
    const dt = Math.max(p2.time - p1.time, 1);
    const speed = dist / dt;
    return Math.max(0.4, 1.0 - speed * 0.005);
  }

  // ─── 笔迹平滑（移动平均 + 二次贝塞尔插值）─────

  static smoothPoints(raw: TouchPoint[], minSpacing: number = 3): RenderPoint[] {
    if (raw.length < 2) {
      return raw.map((p: TouchPoint) => ({ x: p.x, y: p.y, width: 2 }));
    }

    // 步骤1：时间戳排序
    const sorted = [...raw].sort((a, b) => a.time - b.time);

    // 步骤2：移动平均去噪（窗口3）
    const denoised: TouchPoint[] = [];
    for (let i = 0; i < sorted.length; i++) {
      const start = Math.max(0, i - 1);
      const end = Math.min(sorted.length - 1, i + 1);
      let sumX = 0, sumY = 0, sumP = 0;
      let count = 0;
      for (let j = start; j <= end; j++) {
        sumX += sorted[j].x;
        sumY += sorted[j].y;
        sumP += sorted[j].pressure;
        count++;
      }
      denoised.push({
        x: sumX / count,
        y: sumY / count,
        pressure: sumP / count,
        time: sorted[i].time
      });
    }

    // 步骤3：降采样（每 minSpacing px 一个点 + 关键点保留）
    const sampled: TouchPoint[] = [denoised[0]];
    for (let i = 1; i < denoised.length; i++) {
      const last = sampled[sampled.length - 1];
      const dx = denoised[i].x - last.x;
      const dy = denoised[i].y - last.y;
      if (Math.sqrt(dx * dx + dy * dy) >= minSpacing || i === denoised.length - 1) {
        sampled.push(denoised[i]);
      }
    }

    // 步骤4：生成贝塞尔控制点
    const result: RenderPoint[] = [];
    for (let i = 0; i < sampled.length - 1; i++) {
      const p0 = i > 0 ? sampled[i - 1] : sampled[0];
      const p1 = sampled[i];
      const p2 = sampled[i + 1];
      const p3 = i < sampled.length - 2 ? sampled[i + 2] : p2;

      // Catmull-Rom → Quadratic Bezier 转换
      const steps = Math.max(1, Math.floor(this.distance(p1, p2) / 2));
      for (let t = 0; t < steps; t++) {
        const frac = t / steps;
        const x = this.quadraticInterp(p1.x, p2.x, (p0.x + p3.x) / 2, frac);
        const y = this.quadraticInterp(p1.y, p2.y, (p0.y + p3.y) / 2, frac);
        const pressure = p1.pressure + (p2.pressure - p1.pressure) * frac;

        const speedW = this.speedFactor(p1, p2);
        result.push({ x, y, width: pressure * 6 * speedW });
      }
    }

    // 确保最后一个点被包含
    const last = sampled[sampled.length - 1];
    result.push({ x: last.x, y: last.y, width: last.pressure * 6 });
    return result;
  }

  // ─── 笔刷纹理参数 ──────────────────────────────

  static brushParams(type: BrushType): { globalAlpha: number; lineCap: CanvasLineCap; lineJoin: CanvasLineJoin } {
    switch (type) {
      case BrushType.PEN:
        return { globalAlpha: 0.9, lineCap: 'round', lineJoin: 'round' };
      case BrushType.PENCIL:
        return { globalAlpha: 0.7, lineCap: 'round', lineJoin: 'round' };
      case BrushType.MARKER:
        return { globalAlpha: 0.35, lineCap: 'round', lineJoin: 'round' };
      case BrushType.HIGHLIGHTER:
        return { globalAlpha: 0.2, lineCap: 'square', lineJoin: 'miter' };
    }
  }

  // ─── 包围盒计算 ────────────────────────────────

  static computeBounds(points: TouchPoint[]): { minX: number; minY: number; maxX: number; maxY: number } {
    let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
    for (const p of points) {
      if (p.x < minX) minX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.x > maxX) maxX = p.x;
      if (p.y > maxY) maxY = p.y;
    }
    return { minX, minY, maxX, maxY };
  }

  // ─── 橡皮擦命中检测 ────────────────────────────

  static hitsEraser(pathBounds: { minX: number; minY: number; maxX: number; maxY: number },
    eraserX: number, eraserY: number, eraserRadius: number, points: TouchPoint[]): boolean {
    // 快速剔除：包围盒不相交
    if (eraserX + eraserRadius < pathBounds.minX || eraserX - eraserRadius > pathBounds.maxX ||
        eraserY + eraserRadius < pathBounds.minY || eraserY - eraserRadius > pathBounds.maxY) {
      return false;
    }
    // 精确检测：点到线段最短距离
    for (let i = 0; i < points.length - 1; i++) {
      const dist = this.pointToSegmentDist(eraserX, eraserY, points[i].x, points[i].y,
        points[i + 1].x, points[i + 1].y);
      if (dist < eraserRadius) return true;
    }
    return false;
  }

  // ─── 工具函数 ──────────────────────────────────

  private static distance(a: TouchPoint, b: TouchPoint): number {
    const dx = a.x - b.x;
    const dy = a.y - b.y;
    return Math.sqrt(dx * dx + dy * dy);
  }

  private static quadraticInterp(p0: number, p2: number, cp: number, t: number): number {
    const mt = 1 - t;
    return mt * mt * p0 + 2 * mt * t * cp + t * t * p2;
  }

  private static pointToSegmentDist(px: number, py: number,
    x1: number, y1: number, x2: number, y2: number): number {
    const dx = x2 - x1;
    const dy = y2 - y1;
    const lenSq = dx * dx + dy * dy;
    if (lenSq === 0) {
      return Math.sqrt((px - x1) * (px - x1) + (py - y1) * (py - y1));
    }
    let t = ((px - x1) * dx + (py - y1) * dy) / lenSq;
    t = Math.max(0, Math.min(1, t));
    const projX = x1 + t * dx;
    const projY = y1 + t * dy;
    return Math.sqrt((px - projX) * (px - projX) + (py - projY) * (py - projY));
  }
}
