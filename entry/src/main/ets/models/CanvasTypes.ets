// models/CanvasTypes.ets
// JSON Canvas 1.0 数据类型定义 + 视图状态

import { DrawingPath } from './DrawingTypes';

export interface CanvasNode {
  id: string;
  type: 'text' | 'file' | 'link' | 'group' | 'drawing';
  x: number;
  y: number;
  width: number;
  height: number;
  color?: string;
  text?: string;
  file?: string;
  subpath?: string;
  url?: string;
  label?: string;
  background?: string;
  backgroundStyle?: 'cover' | 'ratio' | 'repeat';
  // drawing 类型特有
  penFilePath?: string;
  penPreviewSvg?: string;
}

export interface CanvasEdge {
  id: string;
  fromNode: string;
  fromSide?: 'top' | 'right' | 'bottom' | 'left';
  fromEnd?: 'none' | 'arrow';
  toNode: string;
  toSide?: 'top' | 'right' | 'bottom' | 'left';
  toEnd?: 'none' | 'arrow';
  color?: string;
  label?: string;
}

export interface CanvasData {
  nodes: CanvasNode[];
  edges: CanvasEdge[];
  drawingPaths: DrawingPath[];
}

export const CANVAS_PRESET_COLORS: string[] = [
  '#E74C3C', '#E67E22', '#F1C40F', '#2ECC71', '#3498DB', '#9B59B6'
];
