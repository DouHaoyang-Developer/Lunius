// components/canvas/FreehandLayer.ets
// 自由手绘 Canvas 2D 层 — Touch→Path + 增量渲染 + 橡皮擦

import { CanvasViewModel } from '../../viewmodels/CanvasViewModel';
import { DrawingPath, TouchPoint, BrushType } from '../../models/DrawingTypes';
import { BrushEngine, RenderPoint } from '../../utils/BrushEngine';
import { ObsidianColors, ThemeMode, getColors } from '../../utils/Theme';

@Component
export struct FreehandLayer {
  @StorageLink('themeMode') themeMode: ThemeMode = ThemeMode.DARK;
  @ObjectLink vm: CanvasViewModel;

  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private currentPoints: TouchPoint[] = [];
  private isDrawing: boolean = false;
  private lastRenderTime: number = 0;

  private colors(): ObsidianColors {
    return getColors(this.themeMode);
  }

  // 坐标转换：屏幕坐标 → 画布坐标
  screenToCanvas(screenX: number, screenY: number): { x: number, y: number } {
    return {
      x: screenX / this.vm.zoomScale - this.vm.offsetX,
      y: screenY / this.vm.zoomScale - this.vm.offsetY
    };
  }

  handleTouchStart(screenX: number, screenY: number, pressure: number): void {
    if (this.vm.drawingMode === 'freehand') {
      const pt = this.screenToCanvas(screenX, screenY);
      this.currentPoints = [{ x: pt.x, y: pt.y, pressure: pressure, time: Date.now() }];
      this.isDrawing = true;
    }
  }

  handleTouchMove(screenX: number, screenY: number, pressure: number): void {
    if (!this.isDrawing) return;

    if (this.vm.drawingMode === 'freehand') {
      const pt = this.screenToCanvas(screenX, screenY);
      this.currentPoints.push({ x: pt.x, y: pt.y, pressure: pressure, time: Date.now() });

      // 增量渲染：只画当前笔迹（历史路径缓存）
      const now = Date.now();
      if (now - this.lastRenderTime > 16) { // ~60fps
        this.renderAll();
        this.lastRenderTime = now;
      }
    }

    if (this.vm.drawingMode === 'eraser') {
      const pt = this.screenToCanvas(screenX, screenY);
      this.eraseAt(pt.x, pt.y);
    }
  }

  handleTouchUp(screenX: number, screenY: number, pressure: number): void {
    if (!this.isDrawing) return;
    this.isDrawing = false;

    if (this.vm.drawingMode === 'freehand' && this.currentPoints.length > 1) {
      const pt = this.screenToCanvas(screenX, screenY);
      this.currentPoints.push({ x: pt.x, y: pt.y, pressure: pressure, time: Date.now() });

      const bounds = BrushEngine.computeBounds(this.currentPoints);
      const path: DrawingPath = {
        id: `dp-${Date.now()}`,
        brushType: this.vm.brushType,
        color: this.vm.brushColor,
        baseWidth: this.vm.brushWidth,
        opacity: this.vm.brushType === BrushType.MARKER ? 0.35 : BrushType.HIGHLIGHTER ? 0.2 : 0.9,
        points: [...this.currentPoints],
        minX: bounds.minX, minY: bounds.minY,
        maxX: bounds.maxX, maxY: bounds.maxY
      };
      this.vm.addPath(path);
    }
    this.currentPoints = [];
    this.renderAll();
  }

  // ─── 橡皮擦 ───────────────────────────────────

  private eraseAt(cx: number, cy: number): void {
    const eraserRadius = 15;
    const paths = [...this.vm.drawingPaths];
    for (let i = paths.length - 1; i >= 0; i--) {
      const p = paths[i];
      const bounds = { minX: p.minX, minY: p.minY, maxX: p.maxX, maxY: p.maxY };
      if (BrushEngine.hitsEraser(bounds, cx, cy, eraserRadius, p.points)) {
        this.vm.deletePath(p.id);
        break;
      }
    }
  }

  // ─── 全量渲染 ─────────────────────────────────

  renderAll(): void {
    const ctx = this.ctx;
    ctx.clearRect(0, 0, 9999, 9999);

    // 渲染历史路径
    for (const path of this.vm.drawingPaths) {
      this.renderPath(ctx, path);
    }

    // 渲染当前正在绘制的路径
    if (this.currentPoints.length > 1) {
      const currentPath: DrawingPath = {
        id: '__current__',
        brushType: this.vm.brushType,
        color: this.vm.brushColor,
        baseWidth: this.vm.brushWidth,
        opacity: this.vm.brushType === BrushType.MARKER ? 0.35 : BrushType.HIGHLIGHTER ? 0.2 : 0.9,
        points: this.currentPoints,
        minX: 0, minY: 0, maxX: 0, maxY: 0
      };
      this.renderPath(ctx, currentPath);
    }
  }

  private renderPath(ctx: CanvasRenderingContext2D, path: DrawingPath): void {
    if (path.points.length < 2) return;

    const params = BrushEngine.brushParams(path.brushType);
    const zoom = this.vm.zoomScale;
    const ox = this.vm.offsetX * zoom;
    const oy = this.vm.offsetY * zoom;

    ctx.save();
    ctx.globalAlpha = path.opacity;
    ctx.strokeStyle = path.color;
    ctx.lineCap = params.lineCap;
    ctx.lineJoin = params.lineJoin;

    const smoothed = BrushEngine.smoothPoints(path.points);
    if (smoothed.length < 2) {
      ctx.restore();
      return;
    }

    ctx.beginPath();
    const first = smoothed[0];
    ctx.moveTo(first.x * zoom + ox, first.y * zoom + oy);

    if (path.brushType === BrushType.PENCIL) {
      // 铅笔：纹理感随机偏移
      for (let i = 1; i < smoothed.length; i++) {
        const jitterX = (Math.random() - 0.5) * 1.5;
        const jitterY = (Math.random() - 0.5) * 1.5;
        ctx.lineWidth = Math.max(0.5, path.baseWidth * path.points[Math.min(i, path.points.length - 1)].pressure);
        ctx.lineTo(smoothed[i].x * zoom + ox + jitterX, smoothed[i].y * zoom + oy + jitterY);
      }
    } else if (path.brushType === BrushType.HIGHLIGHTER) {
      // 荧光笔：固定宽矩形
      ctx.lineWidth = path.baseWidth * zoom;
      for (let i = 1; i < smoothed.length; i++) {
        ctx.lineTo(smoothed[i].x * zoom + ox, smoothed[i].y * zoom + oy);
      }
    } else {
      // 钢笔 + 马克笔：可变宽圆线
      for (let i = 1; i < smoothed.length; i++) {
        const pressure = path.points[Math.min(i, path.points.length - 1)].pressure;
        ctx.lineWidth = BrushEngine.mapPressure(path.brushType, pressure, path.baseWidth) * zoom;
        ctx.lineTo(smoothed[i].x * zoom + ox, smoothed[i].y * zoom + oy);
      }
    }

    ctx.stroke();
    ctx.restore();
  }

  // 暴露给 CanvasView 的 onTouch 调用
  handleTouch(e: TouchEvent): void {
    const touch = e.touches[0];
    const pressure = touch.force ?? 0.5;

    if (e.type === TouchType.Down) {
      this.handleTouchStart(touch.x, touch.y, pressure);
    } else if (e.type === TouchType.Move) {
      this.handleTouchMove(touch.x, touch.y, pressure);
    } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
      this.handleTouchUp(touch.x, touch.y, pressure);
    }
  }

  build() {
    Canvas(this.ctx)
      .width('100%').height('100%')
      .onReady(() => {
        this.renderAll();
      })
  }
}
