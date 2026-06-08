// utils/BrushEngine.ets
// 画笔引擎 — 笔迹平滑 + 压感映射 + 笔刷纹理 + 速度感知

import { BrushType, TouchPoint } from '../models/DrawingTypes';

export interface RenderPoint {
  x: number;
  y: number;
  width: number;
}

interface BoundsResult {
  minX: number;
  minY: number;
  maxX: number;
  maxY: number;
}

interface BrushParams {
  globalAlpha: number;
  lineCap: CanvasLineCap;
  lineJoin: CanvasLineJoin;
}

function distanceXY(x1: number, y1: number, x2: number, y2: number): number {
  const dx = x1 - x2;
  const dy = y1 - y2;
  return Math.sqrt(dx * dx + dy * dy);
}

function distanceTP(a: TouchPoint, b: TouchPoint): number {
  return distanceXY(a.x, a.y, b.x, b.y);
}

function quadraticInterp(p0: number, p2: number, cp: number, t: number): number {
  const mt = 1 - t;
  return mt * mt * p0 + 2 * mt * t * cp + t * t * p2;
}

function pointToSegmentDist(px: number, py: number,
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

function speedFactor(p1: TouchPoint, p2: TouchPoint): number {
  const dist = distanceTP(p1, p2);
  const dt = Math.max(p2.time - p1.time, 1);
  const speed = dist / dt;
  return Math.max(0.4, 1.0 - speed * 0.005);
}

export class BrushEngine {
  static mapPressure(type: BrushType, pressure: number, baseWidth: number): number {
    if (pressure <= 0) pressure = 0.1;
    if (type === BrushType.PEN) {
      return baseWidth * 0.3 + pressure * baseWidth * 0.7;
    }
    if (type === BrushType.PENCIL) {
      return baseWidth * 0.6 + pressure * baseWidth * 0.4;
    }
    if (type === BrushType.MARKER) {
      return baseWidth * 0.8 + pressure * baseWidth * 0.2;
    }
    return baseWidth;
  }

  static smoothPoints(raw: TouchPoint[], minSpacing: number = 3): RenderPoint[] {
    if (raw.length < 2) {
      const result: RenderPoint[] = [];
      for (let i = 0; i < raw.length; i++) {
        const p: RenderPoint = { x: raw[i].x, y: raw[i].y, width: 2 };
        result.push(p);
      }
      return result;
    }

    const sorted: TouchPoint[] = [];
    for (let i = 0; i < raw.length; i++) {
      sorted.push(raw[i]);
    }
    for (let i = 0; i < sorted.length - 1; i++) {
      for (let j = 0; j < sorted.length - 1 - i; j++) {
        if (sorted[j].time > sorted[j + 1].time) {
          const tmp = sorted[j];
          sorted[j] = sorted[j + 1];
          sorted[j + 1] = tmp;
        }
      }
    }

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

    const sampled: TouchPoint[] = [denoised[0]];
    for (let i = 1; i < denoised.length; i++) {
      const last = sampled[sampled.length - 1];
      const dx = denoised[i].x - last.x;
      const dy = denoised[i].y - last.y;
      if (Math.sqrt(dx * dx + dy * dy) >= minSpacing || i === denoised.length - 1) {
        sampled.push(denoised[i]);
      }
    }

    const result: RenderPoint[] = [];
    for (let i = 0; i < sampled.length - 1; i++) {
      const p0 = i > 0 ? sampled[i - 1] : sampled[0];
      const p1 = sampled[i];
      const p2 = sampled[i + 1];
      const p3 = i < sampled.length - 2 ? sampled[i + 2] : p2;

      const steps = Math.max(1, Math.floor(distanceTP(p1, p2) / 2));
      for (let t = 0; t < steps; t++) {
        const frac = t / steps;
        const rx = quadraticInterp(p1.x, p2.x, (p0.x + p3.x) / 2, frac);
        const ry = quadraticInterp(p1.y, p2.y, (p0.y + p3.y) / 2, frac);
        const rpressure = p1.pressure + (p2.pressure - p1.pressure) * frac;
        const sw = speedFactor(p1, p2);
        const rp: RenderPoint = { x: rx, y: ry, width: rpressure * 6 * sw };
        result.push(rp);
      }
    }

    const last = sampled[sampled.length - 1];
    const rp: RenderPoint = { x: last.x, y: last.y, width: last.pressure * 6 };
    result.push(rp);
    return result;
  }

  static brushParams(type: BrushType): BrushParams {
    if (type === BrushType.PEN) {
      return { globalAlpha: 0.9, lineCap: 'round', lineJoin: 'round' };
    }
    if (type === BrushType.PENCIL) {
      return { globalAlpha: 0.7, lineCap: 'round', lineJoin: 'round' };
    }
    if (type === BrushType.MARKER) {
      return { globalAlpha: 0.35, lineCap: 'round', lineJoin: 'round' };
    }
    return { globalAlpha: 0.2, lineCap: 'square', lineJoin: 'miter' };
  }

  static computeBounds(points: TouchPoint[]): BoundsResult {
    let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
    for (let i = 0; i < points.length; i++) {
      const p = points[i];
      if (p.x < minX) minX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.x > maxX) maxX = p.x;
      if (p.y > maxY) maxY = p.y;
    }
    const bounds: BoundsResult = { minX: minX, minY: minY, maxX: maxX, maxY: maxY };
    return bounds;
  }

  static hitsEraser(
    pathBounds: BoundsResult,
    eraserX: number, eraserY: number, eraserRadius: number,
    points: TouchPoint[]): boolean {
    if (eraserX + eraserRadius < pathBounds.minX || eraserX - eraserRadius > pathBounds.maxX ||
        eraserY + eraserRadius < pathBounds.minY || eraserY - eraserRadius > pathBounds.maxY) {
      return false;
    }
    for (let i = 0; i < points.length - 1; i++) {
      const dist = pointToSegmentDist(eraserX, eraserY, points[i].x, points[i].y,
        points[i + 1].x, points[i + 1].y);
      if (dist < eraserRadius) return true;
    }
    return false;
  }
}
