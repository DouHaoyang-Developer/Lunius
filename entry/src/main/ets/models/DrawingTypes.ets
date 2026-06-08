// models/DrawingTypes.ets
// 画笔/手写白板数据类型 — DrawingPath / BrushType / TouchPoint

export enum BrushType {
  PEN = 'pen',
  PENCIL = 'pencil',
  MARKER = 'marker',
  HIGHLIGHTER = 'highlighter'
}

export interface TouchPoint {
  x: number;
  y: number;
  pressure: number;
  time: number;
}

export interface DrawingPath {
  id: string;
  brushType: BrushType;
  color: string;
  baseWidth: number;
  opacity: number;
  points: TouchPoint[];
  minX: number;
  minY: number;
  maxX: number;
  maxY: number;
}

export const BRUSH_PRESETS: Record<BrushType, { label: string; width: number; opacity: number; icon: string }> = {
  [BrushType.PEN]:         { label: '钢笔', width: 3, opacity: 0.9, icon: '🖊' },
  [BrushType.PENCIL]:      { label: '铅笔', width: 3.5, opacity: 0.7, icon: '✏' },
  [BrushType.MARKER]:      { label: '马克笔', width: 6, opacity: 0.35, icon: '🖍' },
  [BrushType.HIGHLIGHTER]: { label: '荧光笔', width: 10, opacity: 0.2, icon: '🖌' }
};

export const PALETTE_COLORS: string[] = [
  '#000000', '#E74C3C', '#E67E22', '#F1C40F',
  '#2ECC71', '#3498DB', '#9B59B6', '#FFFFFF'
];

export type DrawingMode = 'none' | 'freehand' | 'shape' | 'eraser';
