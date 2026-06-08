// services/CanvasFileService.ets
// Canvas .canvas JSON 文件读写服务

import { CanvasData, CanvasNode, CanvasEdge } from '../models/CanvasTypes';
import { DrawingPath } from '../models/DrawingTypes';
import { fileIo as fs } from '@kit.CoreFileKit';

export class CanvasFileService {
  private basePath: string = '';

  setBasePath(path: string): void {
    this.basePath = path;
  }

  private generateId(): string {
    const chars = '0123456789abcdef';
    let id = '';
    for (let i = 0; i < 16; i++) {
      id += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return id;
  }

  readCanvas(filePath: string): CanvasData {
    try {
      const fullPath = this.basePath ? `${this.basePath}/${filePath}` : filePath;
      const exists = fs.accessSync(fullPath);
      if (!exists) {
        return { nodes: [], edges: [], drawingPaths: [] };
      }
      const raw = fs.readTextSync(fullPath);
      const data = JSON.parse(raw) as CanvasData;
      return {
        nodes: data.nodes || [],
        edges: data.edges || [],
        drawingPaths: data.drawingPaths || []
      };
    } catch (e) {
      console.error('CanvasFileService read failed: ' + JSON.stringify(e));
      return { nodes: [], edges: [], drawingPaths: [] };
    }
  }

  writeCanvas(filePath: string, data: CanvasData): void {
    try {
      const fullPath = this.basePath ? `${this.basePath}/${filePath}` : filePath;
      const raw = JSON.stringify(data, null, 2);
      const file = fs.openSync(fullPath,
        fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
      fs.writeSync(file.fd, raw);
      fs.closeSync(file);
    } catch (e) {
      console.error('CanvasFileService write failed: ' + JSON.stringify(e));
    }
  }

  createNode(type: 'text' | 'file' | 'link' | 'group' | 'drawing', x: number, y: number): CanvasNode {
    const base: CanvasNode = {
      id: this.generateId(),
      type: type,
      x: x,
      y: y,
      width: type === 'group' ? 600 : type === 'drawing' ? 400 : 300,
      height: type === 'group' ? 400 : type === 'drawing' ? 300 : 150
    };
    if (type === 'text') {
      base.text = '新文本';
    } else if (type === 'file') {
      base.file = '';
    } else if (type === 'link') {
      base.url = 'https://';
    } else if (type === 'group') {
      base.label = '分组';
    } else if (type === 'drawing') {
      base.penFilePath = '';
    }
    return base;
  }

  createEdge(fromNode: string, toNode: string): CanvasEdge {
    return {
      id: this.generateId(),
      fromNode: fromNode,
      toNode: toNode,
      fromSide: 'right',
      toSide: 'left',
      toEnd: 'arrow'
    };
  }
}

export const canvasFileService: CanvasFileService = new CanvasFileService();
