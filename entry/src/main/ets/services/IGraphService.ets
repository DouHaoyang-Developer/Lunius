// services/IGraphService.ets
// 关系图谱服务接口

import { GraphData, GraphNodeData, GraphEdgeData, LinkStats } from './ApiTypes';
import { RealGraphService } from './RealGraphService';

export interface IGraphService {
  // 获取整个 Vault 的图谱数据
  getGraphData(): Promise<GraphData>;

  // 获取局部图谱（以某笔记为中心）
  getLocalGraph(centerNoteId: string, depth?: number): Promise<GraphData>;

  // 获取笔记的连接统计
  getLinkStats(noteId: string): Promise<LinkStats>;
}

export class MockGraphService implements IGraphService {
  async getGraphData(): Promise<GraphData> {
    return {
      nodes: [
        { id: 'n1', label: 'HarmonyOS 开发规范', x: 0, y: 0, radius: 30, color: '#7B68EE', group: 'project' },
        { id: 'n2', label: 'ArkTS 性能优化', x: 120, y: -80, radius: 24, color: '#52C41A', group: 'project' },
        { id: 'n3', label: '响应式设计原理', x: -100, y: 100, radius: 22, color: '#FAAD14', group: 'study' },
        { id: 'n4', label: 'TypeScript 高级类型', x: 140, y: 90, radius: 26, color: '#1890FF', group: 'study' },
        { id: 'n5', label: '组件复用', x: 220, y: -40, radius: 18, color: '#52C41A', group: 'tech' },
        { id: 'n6', label: '断点系统', x: -160, y: 40, radius: 20, color: '#FAAD14', group: 'tech' },
        { id: 'n7', label: '装饰器模式', x: 200, y: 140, radius: 20, color: '#1890FF', group: 'tech' },
        { id: 'n8', label: '2026-05-16 周报', x: 260, y: 20, radius: 18, color: '#999999', group: 'daily' },
        { id: 'n9', label: '灵感碎片', x: 60, y: 180, radius: 16, color: '#999999', group: 'idea' }
      ],
      edges: [
        { source: 'n1', target: 'n2', strength: 0.8 },
        { source: 'n1', target: 'n3', strength: 0.6 },
        { source: 'n1', target: 'n4', strength: 0.7 },
        { source: 'n2', target: 'n5', strength: 0.9 },
        { source: 'n3', target: 'n6', strength: 0.8 },
        { source: 'n4', target: 'n7', strength: 0.7 },
        { source: 'n1', target: 'n8', strength: 0.3 },
        { source: 'n3', target: 'n9', strength: 0.4 },
        { source: 'n6', target: 'n9', strength: 0.5 },
        { source: 'n2', target: 'n4', strength: 0.5 }
      ]
    };
  }

  async getLocalGraph(centerNoteId: string, depth: number = 1): Promise<GraphData> {
    const full = await this.getGraphData();
    // 简化：返回全量数据，实际应根据 centerNoteId 过滤
    return full;
  }

  async getLinkStats(noteId: string): Promise<LinkStats> {
    const stats: LinkStats = { outgoing: 3, incoming: 2, missing: 1 };
    return stats;
  }
}

// 单例导出 - 使用真实图谱服务
export const graphService: IGraphService = new RealGraphService();
