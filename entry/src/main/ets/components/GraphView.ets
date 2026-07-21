// components/GraphView.ets
// 知识图谱视图 — 从 RealGraphService 加载真实数据
// 设计：Canvas 绘制网格背景（不用 Row hack）、精炼工具栏、信息栏

import { LuniusColors, ThemeMode, getColors, Spacing, Radius, Icons } from '../utils/Theme';
import { graphService } from '../services/IGraphService';
import { GraphData, GraphNodeData, GraphEdgeData } from '../services/ApiTypes';

@Component
export struct GraphView {
  @StorageLink('themeMode') themeMode: ThemeMode = ThemeMode.DARK;
  @State graphData: GraphData = { nodes: [], edges: [] };
  @State zoomScale: number = 1.0;
  @State offsetX: number = 0;
  @State offsetY: number = 0;
  @State isDragging: boolean = false;
  @State isLoading: boolean = true;
  @State selectedNodeId: string = '';
  @State showLocalGraph: boolean = false;
  @State localGraphData: GraphData | null = null;
  private canvasCtx: CanvasRenderingContext2D | null = null;
  private gridCtx: CanvasRenderingContext2D | null = null;

  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private gridSettings: RenderingContextSettings = new RenderingContextSettings(true);
  private gridContext: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.gridSettings);
  private lastX: number = 0;
  private lastY: number = 0;

  private colors(): LuniusColors {
    return getColors(this.themeMode);
  }

  private displayData(): GraphData {
    return this.showLocalGraph && this.localGraphData ? this.localGraphData : this.graphData;
  }

  async aboutToAppear(): Promise<void> {
    await this.loadGraph();
  }

  async loadGraph(): Promise<void> {
    this.isLoading = true;
    try {
      this.graphData = await graphService.getGraphData();
    } catch (e) {
      console.error('Graph load error: ' + JSON.stringify(e));
    } finally {
      this.isLoading = false;
    }
  }

  async loadLocalGraph(noteId: string): Promise<void> {
    try {
      this.localGraphData = await graphService.getLocalGraph(noteId, 2);
      this.showLocalGraph = true;
      this.selectedNodeId = noteId;
    } catch (e) {
      console.error('Local graph load error: ' + JSON.stringify(e));
    }
  }

  resetToGlobal(): void {
    this.showLocalGraph = false;
    this.localGraphData = null;
    this.selectedNodeId = '';
    this.zoomScale = 1.0;
    this.offsetX = 0;
    this.offsetY = 0;
    this.redrawEdges();
  }

  private onPinchUpdate = (ge: GestureEvent): void => {
    this.zoomScale = Math.max(0.3, Math.min(3.0, ge.scale));
    this.redrawEdges();
  }

  private drawGrid(): void {
    const ctx = this.gridCtx;
    if (!ctx) return;
    const w = 2000;
    const h = 2000;
    ctx.clearRect(0, 0, w, h);
    const gridColor = this.colors().border;
    ctx.strokeStyle = gridColor;
    ctx.lineWidth = 0.5;
    const gridSize = 40;
    for (let x = 0; x <= w; x += gridSize) {
      ctx.beginPath();
      ctx.moveTo(x, 0);
      ctx.lineTo(x, h);
      ctx.stroke();
    }
    for (let y = 0; y <= h; y += gridSize) {
      ctx.beginPath();
      ctx.moveTo(0, y);
      ctx.lineTo(w, y);
      ctx.stroke();
    }
  }

  private redrawEdges(): void {
    const ctx = this.canvasCtx;
    if (!ctx) return;
    ctx.clearRect(-500, -500, 2000, 2000);
    ctx.strokeStyle = this.colors().border;
    ctx.lineWidth = 1;
    const data = this.displayData();
    const nodes = data.nodes;
    const nodeMap: Map<string, GraphNodeData> = new Map();
    for (let i = 0; i < nodes.length; i++) {
      nodeMap.set(nodes[i].id, nodes[i]);
    }
    for (let j = 0; j < data.edges.length; j++) {
      const edge = data.edges[j];
      const source = nodeMap.get(edge.source);
      const target = nodeMap.get(edge.target);
      if (source && target) {
        ctx.beginPath();
        ctx.moveTo(
          (source.x + this.offsetX) * this.zoomScale + source.radius * this.zoomScale,
          (source.y + this.offsetY) * this.zoomScale + source.radius * this.zoomScale
        );
        ctx.lineTo(
          (target.x + this.offsetX) * this.zoomScale + target.radius * this.zoomScale,
          (target.y + this.offsetY) * this.zoomScale + target.radius * this.zoomScale
        );
        ctx.stroke();
      }
    }
  }

  @Builder
  ToolButton(icon: string, action: () => void) {
    Column() {
      Text(icon)
        .fontSize(14)
        .fontColor(this.colors().textSecondary)
    }
    .width(30).height(30)
    .justifyContent(FlexAlign.Center)
    .borderRadius(Radius.SM)
    .backgroundColor(this.colors().surface2)
    .onClick(action)
  }

  @Builder
  LoadingState() {
    Column({ space: Spacing.SM }) {
      Text(Icons.LOADING)
        .fontSize(28)
        .fontColor(this.colors().textTertiary)
      Text('\u52A0\u8F7D\u56FE\u8C31...')
        .fontSize(13)
        .fontColor(this.colors().textTertiary)
    }
    .width('100%').layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.colors().surface0)
  }

  @Builder
  EmptyState() {
    Column({ space: Spacing.SM }) {
      Text(Icons.GRAPH)
        .fontSize(40)
        .fontColor(this.colors().textTertiary)
      Text('\u6682\u65E0\u56FE\u8C31\u6570\u636E')
        .fontSize(14)
        .fontColor(this.colors().textSecondary)
      Text('\u5728\u7B14\u8BB0\u4E2D\u4F7F\u7528 [[wikilink]] \u521B\u5EFA\u94FE\u63A5')
        .fontSize(11)
        .fontColor(this.colors().textTertiary)
    }
    .width('100%').layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.colors().surface0)
  }

  build() {
    Column() {
      // 顶部工具栏
      Row() {
        Row({ space: Spacing.SM }) {
          Text(this.showLocalGraph ? '\u5C40\u90E8\u56FE\u8C31' : '\u5173\u7CFB\u56FE\u8C31')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.colors().textPrimary)

          if (this.showLocalGraph) {
            Row({ space: 4 }) {
              Text(Icons.BACK)
                .fontSize(10)
                .fontColor(this.colors().accent)
              Text('\u8FD4\u56DE\u5168\u5C40')
                .fontSize(11)
                .fontColor(this.colors().accent)
            }
            .height(24)
            .padding({ left: Spacing.SM, right: Spacing.SM })
            .backgroundColor(this.colors().accentSubtle)
            .borderRadius(Radius.SM)
            .onClick(() => this.resetToGlobal())
          }
        }

        Row({ space: Spacing.XS }) {
          this.ToolButton(Icons.ZOOM_IN, () => {
            this.zoomScale = Math.min(this.zoomScale + 0.2, 3.0);
            this.redrawEdges();
          })
          this.ToolButton(Icons.ZOOM_OUT, () => {
            this.zoomScale = Math.max(this.zoomScale - 0.2, 0.3);
            this.redrawEdges();
          })
          this.ToolButton(Icons.RESET, () => {
            this.zoomScale = 1.0;
            this.offsetX = 0;
            this.offsetY = 0;
            this.redrawEdges();
          })
          this.ToolButton(Icons.SYNC, () => this.loadGraph())
        }
      }
      .width('100%').height(44)
      .padding({ left: Spacing.MD, right: Spacing.MD })
      .justifyContent(FlexAlign.SpaceBetween)
      .backgroundColor(this.colors().surface1)
      .border({ width: { bottom: 1 }, color: this.colors().border })

      if (this.isLoading) {
        this.LoadingState()
      } else if (this.displayData().nodes.length === 0) {
        this.EmptyState()
      } else {
        Stack() {
          // 背景网格 — Canvas 绘制
          Canvas(this.gridContext)
            .width('100%').height('100%')
            .onReady(() => {
              this.gridCtx = this.gridContext;
              this.drawGrid();
            })

          // 连线层
          Canvas(this.context)
            .width('100%').height('100%')
            .onReady(() => {
              this.canvasCtx = this.context;
              this.redrawEdges();
            })

          // 节点层
          Stack() {
            ForEach(this.displayData().nodes, (node: GraphNodeData) => {
              Column() {
                Stack() {
                  Circle()
                    .width(node.radius * 2 * this.zoomScale)
                    .height(node.radius * 2 * this.zoomScale)
                    .fill(node.id === this.selectedNodeId
                      ? this.colors().accent : node.color)
                    .opacity(0.85)
                    .shadow({ radius: 6, color: node.color, offsetX: 0, offsetY: 2 })

                  Text(node.label.substring(0, 1))
                    .fontSize(Math.max(10, 16 * this.zoomScale))
                    .fontColor(this.colors().onAccent)
                    .fontWeight(FontWeight.Bold)
                }

                Text(node.label)
                  .fontSize(11)
                  .fontColor(this.colors().textPrimary)
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .textAlign(TextAlign.Center)
                  .width(80)
                  .margin({ top: 4 })
              }
              .position({
                x: (node.x + this.offsetX) * this.zoomScale,
                y: (node.y + this.offsetY) * this.zoomScale
              })
              .onClick(() => {
                this.loadLocalGraph(node.id);
              })
            }, (node: GraphNodeData) => node.id)
          }
          .width('100%').height('100%')
        }
        .width('100%').layoutWeight(1)
        .backgroundColor(this.colors().surface0)
        .gesture(
          PanGesture()
            .onActionStart((event: GestureEvent) => {
              this.isDragging = true;
              this.lastX = event.offsetX;
              this.lastY = event.offsetY;
            })
            .onActionUpdate((event: GestureEvent) => {
              this.offsetX += (event.offsetX - this.lastX) / this.zoomScale;
              this.offsetY += (event.offsetY - this.lastY) / this.zoomScale;
              this.lastX = event.offsetX;
              this.lastY = event.offsetY;
              this.redrawEdges();
            })
            .onActionEnd(() => { this.isDragging = false; })
        )
        .gesture(
          PinchGesture()
            .onActionUpdate(this.onPinchUpdate)
        )
      }

      // 底部信息栏
      Row() {
        Text('\u7F29\u653E: ' + (this.zoomScale * 100).toFixed(0) + '%')
          .fontSize(11).fontColor(this.colors().textTertiary)

        Text('\u8282\u70B9: ' + String(this.displayData().nodes.length)
          + ' | \u8FDE\u7EBF: ' + String(this.displayData().edges.length))
          .fontSize(11).fontColor(this.colors().textTertiary)

        if (this.selectedNodeId) {
          Text('\u9009\u4E2D: ' + this.selectedNodeId)
            .fontSize(11).fontColor(this.colors().accent)
        }
      }
      .width('100%').height(28)
      .padding({ left: Spacing.MD, right: Spacing.MD })
      .justifyContent(FlexAlign.SpaceBetween)
      .backgroundColor(this.colors().surface1)
      .border({ width: { top: 1 }, color: this.colors().border })
    }
    .width('100%').height('100%')
    .backgroundColor(this.colors().surface0)
  }
}
