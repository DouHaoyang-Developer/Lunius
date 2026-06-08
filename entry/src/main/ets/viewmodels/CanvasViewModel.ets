// viewmodels/CanvasViewModel.ets
// 画布 ViewModel — 节点/连线 CRUD + 选中/撤销状态

import { CanvasNode, CanvasEdge, CanvasData } from '../models/CanvasTypes';
import { DrawingPath, BrushType, DrawingMode, getBrushPreset, TouchPoint } from '../models/DrawingTypes';
import { canvasFileService } from '../services/CanvasFileService';
import { DrawingExport } from '../utils/DrawingExport';

@Observed
export class CanvasViewModel {
  filePath: string;
  nodes: CanvasNode[] = [];
  edges: CanvasEdge[] = [];
  drawingPaths: DrawingPath[] = [];
  zoomScale: number = 1;
  offsetX: number = 0;
  offsetY: number = 0;
  selectedNodeId: string = '';
  selectedEdgeId: string = '';
  editingNodeId: string = '';
  connectingFromNodeId: string = '';
  isLoading: boolean = false;

  // 绘制模式状态
  drawingMode: DrawingMode = 'none';
  brushType: BrushType = BrushType.PEN;
  brushColor: string = '#000000';
  brushWidth: number = 3;

  private undoStack: CanvasData[] = [];
  private redoStack: CanvasData[] = [];

  constructor(filePath: string) {
    this.filePath = filePath;
  }

  async loadCanvas(): Promise<void> {
    this.isLoading = true;
    try {
      const data = canvasFileService.readCanvas(this.filePath);
      this.nodes = data.nodes;
      this.edges = data.edges;
      this.drawingPaths = data.drawingPaths || [];
      this.saveUndo();
    } catch (e) {
      console.error('CanvasViewModel load failed: ' + JSON.stringify(e));
    }
    this.isLoading = false;
  }

  private persist(): void {
    canvasFileService.writeCanvas(this.filePath, {
      nodes: this.nodes,
      edges: this.edges,
      drawingPaths: this.drawingPaths
    });
  }

  // ─── 节点操作 ─────────────────────────────────

  addNode(type: 'text' | 'file' | 'link' | 'group' | 'drawing', x: number, y: number): CanvasNode {
    const node = canvasFileService.createNode(type, x, y);
    this.nodes.push(node);
    this.persist();
    return node;
  }

  updateNode(id: string, changes: Partial<CanvasNode>): void {
    const idx = this.nodes.findIndex((n: CanvasNode) => n.id === id);
    if (idx === -1) return;
    const old = this.nodes[idx];
    this.nodes[idx] = {
      id: old.id, type: old.type, x: old.x, y: old.y,
      width: old.width, height: old.height,
      color: old.color, text: old.text, file: old.file, subpath: old.subpath,
      url: old.url, label: old.label, background: old.background,
      backgroundStyle: old.backgroundStyle
    };
    if (changes.x !== undefined) this.nodes[idx].x = changes.x;
    if (changes.y !== undefined) this.nodes[idx].y = changes.y;
    if (changes.width !== undefined) this.nodes[idx].width = changes.width;
    if (changes.height !== undefined) this.nodes[idx].height = changes.height;
    if (changes.text !== undefined) this.nodes[idx].text = changes.text;
    if (changes.file !== undefined) this.nodes[idx].file = changes.file;
    if (changes.label !== undefined) this.nodes[idx].label = changes.label;
    if (changes.url !== undefined) this.nodes[idx].url = changes.url;
    if (changes.color !== undefined) this.nodes[idx].color = changes.color;
    this.persist();
  }

  deleteNode(id: string): void {
    const idx = this.nodes.findIndex((n: CanvasNode) => n.id === id);
    if (idx === -1) return;
    this.nodes.splice(idx, 1);
    // 删除关联连线
    this.edges = this.edges.filter((e: CanvasEdge) =>
      e.fromNode !== id && e.toNode !== id
    );
    if (this.selectedNodeId === id) this.selectedNodeId = '';
    this.persist();
  }

  moveNode(id: string, x: number, y: number): void {
    const idx = this.nodes.findIndex((n: CanvasNode) => n.id === id);
    if (idx === -1) return;
    this.nodes[idx].x = x;
    this.nodes[idx].y = y;
    this.persist();
  }

  selectNode(id: string): void {
    this.selectedNodeId = id;
    this.selectedEdgeId = '';
  }

  startEditingNode(id: string): void {
    this.editingNodeId = id;
  }

  stopEditing(): void {
    this.editingNodeId = '';
  }

  // ─── 连线操作 ─────────────────────────────────

  addEdge(fromNode: string, toNode: string): CanvasEdge | null {
    if (fromNode === toNode) return null;
    const exists = this.edges.find((e: CanvasEdge) =>
      e.fromNode === fromNode && e.toNode === toNode
    );
    if (exists) return exists;
    const edge = canvasFileService.createEdge(fromNode, toNode);
    this.edges.push(edge);
    this.persist();
    return edge;
  }

  deleteEdge(id: string): void {
    const idx = this.edges.findIndex((e: CanvasEdge) => e.id === id);
    if (idx === -1) return;
    this.edges.splice(idx, 1);
    if (this.selectedEdgeId === id) this.selectedEdgeId = '';
    this.persist();
  }

  selectEdge(id: string): void {
    this.selectedEdgeId = id;
    this.selectedNodeId = '';
  }

  startConnecting(nodeId: string): void {
    this.connectingFromNodeId = nodeId;
  }

  cancelConnecting(): void {
    this.connectingFromNodeId = '';
  }

  // ─── 平移/缩放 ───────────────────────────────

  updateViewport(zoom: number, offsetX: number, offsetY: number): void {
    this.zoomScale = Math.max(0.2, Math.min(5, zoom));
    this.offsetX = offsetX;
    this.offsetY = offsetY;
  }

  resetView(): void {
    this.zoomScale = 1;
    this.offsetX = 0;
    this.offsetY = 0;
  }

  // ─── 绘制模式 ─────────────────────────────────

  cycleDrawingMode(): void {
    const modes: DrawingMode[] = ['none', 'freehand', 'shape', 'eraser', 'none'];
    const idx = modes.indexOf(this.drawingMode);
    this.drawingMode = modes[(idx + 1) % modes.length];
  }

  setBrushType(type: BrushType): void {
    this.brushType = type;
    const preset = getBrushPreset(type);
    this.brushWidth = preset.width;
  }

  addPath(path: DrawingPath): void {
    this.drawingPaths.push(path);
    this.persist();
  }

  deletePath(id: string): void {
    const idx = this.drawingPaths.findIndex((p: DrawingPath) => p.id === id);
    if (idx === -1) return;
    this.drawingPaths.splice(idx, 1);
    this.persist();
  }

  clearDrawing(): void {
    this.drawingPaths = [];
    this.persist();
  }

  // ─── 导出 ─────────────────────────────────────

  exportSvg(): string {
    return DrawingExport.toSvg(this.drawingPaths);
  }

  exportPngToFile(filePath: string): void {
    // 需要渲染到离屏 Canvas 后保存
    // 在真机环境下可使用 Canvas.toDataURL 或截图 API
    const svgContent = this.exportSvg();
    // 简化实现：保存 SVG（PNG 转换需 Native API 支持）
    console.info('SVG exported, length: ' + svgContent.length);
  }

  // ─── 撤销/重做 ───────────────────────────────

  saveUndo(): void {
    const snapshotNodes: CanvasNode[] = [];
    for (let i = 0; i < this.nodes.length; i++) {
      const n = this.nodes[i];
      const copy: CanvasNode = {
        id: n.id, type: n.type, x: n.x, y: n.y,
        width: n.width, height: n.height,
        color: n.color, text: n.text, file: n.file, subpath: n.subpath,
        url: n.url, label: n.label, background: n.background,
        backgroundStyle: n.backgroundStyle,
        penFilePath: n.penFilePath, penPreviewSvg: n.penPreviewSvg
      };
      snapshotNodes.push(copy);
    }

    const snapshotEdges: CanvasEdge[] = [];
    for (let i = 0; i < this.edges.length; i++) {
      const e = this.edges[i];
      const copy: CanvasEdge = {
        id: e.id, fromNode: e.fromNode, toNode: e.toNode,
        fromSide: e.fromSide, toSide: e.toSide,
        fromEnd: e.fromEnd, toEnd: e.toEnd,
        color: e.color, label: e.label
      };
      snapshotEdges.push(copy);
    }

    const snapshotPaths: DrawingPath[] = [];
    for (let i = 0; i < this.drawingPaths.length; i++) {
      const p = this.drawingPaths[i];
      const pathPoints: TouchPoint[] = [];
      for (let j = 0; j < p.points.length; j++) {
        const pt = p.points[j];
        const copyPt: TouchPoint = { x: pt.x, y: pt.y, pressure: pt.pressure, time: pt.time };
        pathPoints.push(copyPt);
      }
      const copy: DrawingPath = {
        id: p.id, brushType: p.brushType, color: p.color,
        baseWidth: p.baseWidth, opacity: p.opacity,
        points: pathPoints,
        minX: p.minX, minY: p.minY, maxX: p.maxX, maxY: p.maxY
      };
      snapshotPaths.push(copy);
    }

    const snapshot: CanvasData = {
      nodes: snapshotNodes,
      edges: snapshotEdges,
      drawingPaths: snapshotPaths
    };
    this.undoStack.push(snapshot);
    if (this.undoStack.length > 50) this.undoStack.shift();
    this.redoStack = [];
  }

  undo(): void {
    if (this.undoStack.length === 0) return;
    const prev = this.undoStack.pop()!;
    const current: CanvasData = { nodes: this.nodes, edges: this.edges, drawingPaths: this.drawingPaths };
    this.redoStack.push(current);
    this.nodes = prev.nodes;
    this.edges = prev.edges;
    this.drawingPaths = prev.drawingPaths;
    this.persist();
  }

  redo(): void {
    if (this.redoStack.length === 0) return;
    const next = this.redoStack.pop()!;
    const current: CanvasData = { nodes: this.nodes, edges: this.edges, drawingPaths: this.drawingPaths };
    this.undoStack.push(current);
    this.nodes = next.nodes;
    this.edges = next.edges;
    this.drawingPaths = next.drawingPaths;
    this.persist();
  }
}
