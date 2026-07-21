// components/canvas/CanvasView.ets
// 画布渲染容器 — 手势路由 + 绘制模式切换 + 节点/连线/手绘层

import { LuniusColors, ThemeMode, getColors } from '../../utils/Theme';
import { CanvasNode } from '../../models/CanvasTypes';
import { CanvasViewModel } from '../../viewmodels/CanvasViewModel';
import { CanvasNodeComponent } from './CanvasNode';
import { CanvasEdgeLayer } from './CanvasEdgeLayer';
import { FreehandLayer } from './FreehandLayer';
import { CanvasToolbar } from './CanvasToolbar';
import { DrawingToolbar } from './DrawingToolbar';
import { InstantShapeEngine, shapeToCanvasNode } from './InstantShapeLayer';
import { PalmRejection } from '../../utils/PalmRejection';

@Component
export struct CanvasView {
  @StorageLink('themeMode') themeMode: ThemeMode = ThemeMode.DARK;
  @ObjectLink vm: CanvasViewModel;
  onNoteClick?: (noteId: string) => void;

  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private drawCtx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private shapeEngine: InstantShapeEngine = new InstantShapeEngine();
  private palmRejection: PalmRejection = new PalmRejection();
  private shapeCancelled: boolean = false;

  private colors(): LuniusColors {
    return getColors(this.themeMode);
  }

  private isDrawingActive(): boolean {
    return this.vm.drawingMode === 'freehand' || this.vm.drawingMode === 'eraser' || this.vm.drawingMode === 'shape';
  }

  aboutToAppear(): void {
    // 一笔成形识别回调
    this.shapeEngine.onShapeRecognized = (shape) => {
      const node = shapeToCanvasNode(shape, () => this.genShapeId());
      this.vm.nodes.push(node);
      this.vm.saveUndo();
    };
  }

  // 生成 ID 供 shapeToCanvasNode 使用
  private shapeIdCounter: number = 0;
  private genShapeId(): string {
    return `shape-${Date.now()}-${++this.shapeIdCounter}`;
  }

  // 绘制模式的触摸处理
  private handleDrawingTouch(e: TouchEvent): void {
    // 手掌误触过滤
    if (this.palmRejection.isInCooldown()) return;
    if (this.palmRejection.isPalmTouch(e)) {
      // 取消当前绘制
      this.currentPoints = [];
      this.isDrawing = false;
      if (this.vm.drawingMode === 'shape') {
        this.shapeEngine.cancel();
      }
      return;
    }

    // 一笔成形模式：尝试找笔尖
    let touch: Touch | null = null;
    if (this.vm.drawingMode === 'shape') {
      touch = this.palmRejection.getStylusTouch(e);
      if (!touch) return; // 找不到笔尖，跳过
    } else {
      touch = e.touches[0];
    }

    const pressure = touch.force ?? 0.5;
    const cx = touch.x / this.vm.zoomScale - this.vm.offsetX;
    const cy = touch.y / this.vm.zoomScale - this.vm.offsetY;

    // 一笔成形模式
    if (this.vm.drawingMode === 'shape') {
      if (e.type === TouchType.Down) {
        this.shapeEngine.start(cx, cy, pressure);
      } else if (e.type === TouchType.Move) {
        this.shapeEngine.move(cx, cy, pressure);
      } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.shapeEngine.end();
      }
      return;
    }

    // freehand / eraser 模式
    if (e.type === TouchType.Down) {
      this.drawingStart(cx, cy, pressure);
    } else if (e.type === TouchType.Move) {
      this.drawingMove(cx, cy, pressure);
    } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
      this.drawingEnd(cx, cy, pressure);
    }
  }

  private currentPoints: { x: number; y: number; pressure: number; time: number }[] = [];
  private isDrawing: boolean = false;

  private drawingStart(cx: number, cy: number, pressure: number): void {
    if (this.vm.drawingMode === 'freehand') {
      this.currentPoints = [{ x: cx, y: cy, pressure: pressure, time: Date.now() }];
      this.isDrawing = true;
    }
    if (this.vm.drawingMode === 'eraser') {
      this.eraseAt(cx, cy);
    }
  }

  private drawingMove(cx: number, cy: number, pressure: number): void {
    if (this.vm.drawingMode === 'freehand' && this.isDrawing) {
      this.currentPoints.push({ x: cx, y: cy, pressure: pressure, time: Date.now() });
    }
    if (this.vm.drawingMode === 'eraser') {
      this.eraseAt(cx, cy);
    }
  }

  private drawingEnd(cx: number, cy: number, pressure: number): void {
    if (!this.isDrawing) return;
    this.isDrawing = false;

    if (this.vm.drawingMode === 'freehand' && this.currentPoints.length > 1) {
      this.currentPoints.push({ x: cx, y: cy, pressure: pressure, time: Date.now() });
      let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
      for (const p of this.currentPoints) {
        if (p.x < minX) minX = p.x;
        if (p.y < minY) minY = p.y;
        if (p.x > maxX) maxX = p.x;
        if (p.y > maxY) maxY = p.y;
      }
      this.vm.addPath({
        id: `dp-${Date.now()}`,
        brushType: this.vm.brushType,
        color: this.vm.brushColor,
        baseWidth: this.vm.brushWidth,
        opacity: 0.9,
        points: this.currentPoints.map((p) => ({
          x: p.x, y: p.y, pressure: p.pressure, time: p.time
        })),
        minX: minX, minY: minY, maxX: maxX, maxY: maxY
      });
    }
    this.currentPoints = [];
  }

  private eraseAt(cx: number, cy: number): void {
    const eraserRadius = 15 / this.vm.zoomScale;
    const paths = [...this.vm.drawingPaths];
    for (let i = paths.length - 1; i >= 0; i--) {
      const p = paths[i];
      const hits = this.boundsIntersect(
        { minX: p.minX, minY: p.minY, maxX: p.maxX, maxY: p.maxY },
        cx, cy, eraserRadius
      );
      if (hits) {
        this.vm.deletePath(p.id);
        break;
      }
    }
  }

  private boundsIntersect(
    bounds: { minX: number; minY: number; maxX: number; maxY: number },
    cx: number, cy: number, r: number
  ): boolean {
    if (cx + r < bounds.minX || cx - r > bounds.maxX ||
        cy + r < bounds.minY || cy - r > bounds.maxY) {
      return false;
    }
    return true;
  }

  build() {
    Stack() {
      // 背景网格
      Column()
        .width('100%').height('100%')
        .backgroundColor(this.colors().surface0)

      // 连线层
      CanvasEdgeLayer({ vm: this.vm })

      // 历史手绘渲染层
      FreehandLayer({ vm: this.vm })

      // 节点层
      ForEach(this.vm.nodes, (node: CanvasNode) => {
        Stack() {
          CanvasNodeComponent({
            node: node,
            isSelected: this.vm.selectedNodeId === node.id,
            zoomScale: this.vm.zoomScale,
            onTap: () => { this.vm.selectNode(node.id); },
            onDoubleTap: () => {
              if (node.type === 'file' && node.file && this.onNoteClick) {
                this.onNoteClick(node.file.replace('.md', ''));
              } else {
                this.vm.startEditingNode(node.id);
              }
            },
            onDragEnd: (x: number, y: number) => {
              this.vm.moveNode(node.id, x, y);
            },
            onPortDragStart: (_side: string) => {
              this.vm.startConnecting(node.id);
            },
            onPortDragEnd: (targetId: string) => {
              this.vm.addEdge(this.vm.connectingFromNodeId, targetId);
              this.vm.cancelConnecting();
            }
          })
        }
        .position({
          x: (node.x + this.vm.offsetX) * this.vm.zoomScale,
          y: (node.y + this.vm.offsetY) * this.vm.zoomScale
        })
      }, (node: CanvasNode) => node.id)

      // 绘制模式触控覆盖层（透明，仅在绘制/橡皮擦模式激活）
      if (this.isDrawingActive()) {
        Stack()
          .width('100%').height('100%')
          .zIndex(50)
          .hitTestBehavior(HitTestMode.Block)
          .onTouch((e: TouchEvent) => {
            this.handleDrawingTouch(e);
          })
      }

      // 工具栏（根据模式切换）
      if (this.isDrawingActive()) {
        DrawingToolbar({ vm: this.vm })
          .position({ x: 0, y: '100%' }).translate({ y: -120 }).zIndex(60)
      } else {
        CanvasToolbar({ vm: this.vm })
          .position({ x: 0, y: '100%' }).translate({ y: -50 }).zIndex(60)
      }
    }
    .width('100%').height('100%')
    .gesture(
      PinchGesture({ fingers: 2 })
        .onActionUpdate((event: GestureEvent) => {
          if (event.scale !== undefined && event.scale > 0 && this.vm.drawingMode === 'none') {
            this.vm.updateViewport(
              this.vm.zoomScale * event.scale,
              this.vm.offsetX,
              this.vm.offsetY
            );
          }
        })
    )
    .gesture(
      PanGesture({ fingers: 1, direction: PanDirection.All })
        .onActionUpdate((event: GestureEvent) => {
          if (event.offsetX !== undefined && event.offsetY !== undefined && this.vm.drawingMode === 'none') {
            this.vm.updateViewport(
              this.vm.zoomScale,
              this.vm.offsetX + event.offsetX / this.vm.zoomScale,
              this.vm.offsetY + event.offsetY / this.vm.zoomScale
            );
          }
        })
    )
  }
}
