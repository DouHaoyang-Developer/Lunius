// components/GraphView.ets
// 知识图谱视图 — 从 RealGraphService 加载真实数据

import { ObsidianColors, ThemeMode, getColors } from '../utils/Theme';
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

  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private lastX: number = 0;
  private lastY: number = 0;

  private colors(): ObsidianColors {
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

  private redrawEdges(): void {
    const ctx = this.canvasCtx;
    if (!ctx) return;
    ctx.clearRect(-500, -500, 2000, 2000);
    ctx.strokeStyle = this.colors().divider;
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

  build() {
    Column() {
      // 顶部工具栏
      Row() {
        Row({ space: 8 }) {
          Text(this.showLocalGraph ? '局部图谱' : '关系图谱')
            .fontSize(14).fontWeight(FontWeight.Medium)
            .fontColor(this.colors().textSecondary)

          if (this.showLocalGraph) {
            Button('← 返回全局')
              .fontSize(11).fontColor(this.colors().accent)
              .backgroundColor(this.colors().bgHover)
              .height(24).borderRadius(4)
              .onClick(() => this.resetToGlobal())
          }
        }

        Row({ space: 8 }) {
          Button({ type: ButtonType.Circle }) {
            Text('⊕').fontSize(16).fontColor(this.colors().iconSecondary)
          }
          .width(28).height(28).backgroundColor(this.colors().bgHover)
          .onClick(() => { this.zoomScale = Math.min(this.zoomScale + 0.2, 3.0); this.redrawEdges(); })

          Button({ type: ButtonType.Circle }) {
            Text('⊖').fontSize(16).fontColor(this.colors().iconSecondary)
          }
          .width(28).height(28).backgroundColor(this.colors().bgHover)
          .onClick(() => { this.zoomScale = Math.max(this.zoomScale - 0.2, 0.3); this.redrawEdges(); })

          Button({ type: ButtonType.Circle }) {
            Text('⟲').fontSize(14).fontColor(this.colors().iconSecondary)
          }
          .width(28).height(28).backgroundColor(this.colors().bgHover)
          .onClick(() => {
            this.zoomScale = 1.0;
            this.offsetX = 0;
            this.offsetY = 0;
            this.redrawEdges();
          })

          Button({ type: ButtonType.Circle }) {
            Text('🔄').fontSize(12).fontColor(this.colors().iconSecondary)
          }
          .width(28).height(28).backgroundColor(this.colors().bgHover)
          .onClick(() => this.loadGraph())
        }
      }
      .width('100%').height(40).padding({ left: 16, right: 16 })
      .justifyContent(FlexAlign.SpaceBetween)
      .backgroundColor(this.colors().sidebarBg)
      .border({ width: { bottom: 1 }, color: this.colors().divider })

      if (this.isLoading) {
        Column() {
          Text('⏳').fontSize(32)
          Text('加载图谱...').fontSize(14).fontColor(this.colors().textSecondary).margin({ top: 8 })
        }
        .width('100%').layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(this.colors().bgPrimary)
      } else if (this.displayData().nodes.length === 0) {
        Column() {
          Text('🕸️').fontSize(48)
          Text('暂无图谱数据').fontSize(16).fontColor(this.colors().textSecondary)
          Text('在笔记中使用 [[wikilink]] 创建链接').fontSize(12).fontColor(this.colors().textMuted).margin({ top: 4 })
        }
        .width('100%').layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(this.colors().bgPrimary)
      } else {
        Stack() {
          // 背景网格
          Column() {
            ForEach([0, 1, 2, 3, 4, 5, 6, 7, 8, 9], (row: number) => {
              Row() {
                ForEach([0, 1, 2, 3, 4, 5, 6, 7, 8, 9], (col: number) => {
                  Row()
                    .width(60).height(60)
                    .border({ width: 0.5, color: this.colors().divider })
                    .opacity(0.3)
                }, (col: number) => col.toString())
              }
            }, (row: number) => row.toString())
          }
          .width('100%').height('100%')
          .position({ x: 0, y: 0 })

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
                    .fill(node.id === this.selectedNodeId ? '#FF4D4F' : node.color)
                    .opacity(0.85)
                    .shadow({ radius: 8, color: node.color, offsetX: 0, offsetY: 4 })

                  Text(node.label.substring(0, 1))
                    .fontSize(Math.max(10, 16 * this.zoomScale))
                    .fontColor('#FFFFFF')
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
        .backgroundColor(this.colors().bgPrimary)
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
        Text(`缩放: ${(this.zoomScale * 100).toFixed(0)}%`)
          .fontSize(11).fontColor(this.colors().textMuted)

        Text(`节点: ${this.displayData().nodes.length} | 连线: ${this.displayData().edges.length}`)
          .fontSize(11).fontColor(this.colors().textMuted)

        if (this.selectedNodeId) {
          Text(`选中: ${this.selectedNodeId}`)
            .fontSize(11).fontColor(this.colors().accent)
        }
      }
      .width('100%').height(28)
      .padding({ left: 16, right: 16 })
      .justifyContent(FlexAlign.SpaceBetween)
      .backgroundColor(this.colors().sidebarBg)
      .border({ width: { top: 1 }, color: this.colors().divider })
    }
    .width('100%').height('100%')
    .backgroundColor(this.colors().bgPrimary)
  }
}
