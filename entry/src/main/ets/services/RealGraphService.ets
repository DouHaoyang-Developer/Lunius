// services/RealGraphService.ets
// 知识图谱服务 — 解析 [[wikilinks]] 构建节点/边关系图

import { IGraphService } from './IGraphService';
import { GraphData, GraphNodeData, GraphEdgeData, LinkStats } from './ApiTypes';
import { FileNode, NodeType } from '../models/FileNode';
import { fileService } from './IFileService';

const TAG = 'RealGraphService';

// 标签 → 颜色映射
const GROUP_COLORS: Record<string, string> = {
  'dev': '#7B68EE',
  'harmonyos': '#7B68EE',
  'performance': '#52C41A',
  'design': '#FAAD14',
  'ts': '#1890FF',
  'weekly': '#FF7BA0',
  'idea': '#F5A623',
  'meta': '#999999',
  'study': '#1890FF',
  'project': '#7B68EE',
  'daily': '#FF7BA0',
  'tech': '#52C41A',
  'default': '#7B68EE'
};

export class RealGraphService implements IGraphService {
  // 缓存
  private graphCache: GraphData | null = null;
  private linkIndex: Map<string, Set<string>> = new Map(); // noteId → set of targetIds
  private backlinkIndex: Map<string, Set<string>> = new Map(); // noteId → set of sourceIds
  private lastUpdate: number = 0;

  private needRefresh(): boolean {
    return this.graphCache === null || (Date.now() - this.lastUpdate > 30000);
  }

  // ─── 索引构建 ─────────────────────────────────

  private async ensureIndex(): Promise<void> {
    if (!this.needRefresh()) return;

    this.linkIndex.clear();
    this.backlinkIndex.clear();

    const tree = await fileService.getFileTree();
    const fileIds = this.collectFileIds(tree);

    for (const id of fileIds) {
      try {
        const result = await fileService.readNote(id);
        const links: string[] = result.metadata.links;

        if (!this.linkIndex.has(id)) {
          this.linkIndex.set(id, new Set());
        }
        const linkSet = this.linkIndex.get(id)!;

        for (const linkName of links) {
          // 尝试匹配到实际文件
          const targetId = this.resolveLink(linkName, fileIds);
          if (targetId) {
            linkSet.add(targetId);

            if (!this.backlinkIndex.has(targetId)) {
              this.backlinkIndex.set(targetId, new Set());
            }
            this.backlinkIndex.get(targetId)!.add(id);
          }
        }
      } catch (e) {
        console.error(`${TAG} index error for ${id}: ${JSON.stringify(e)}`);
      }
    }

    this.lastUpdate = Date.now();
    this.graphCache = null; // 使 graphCache 失效触发重建
  }

  private resolveLink(linkName: string, fileIds: string[]): string | null {
    // 精确匹配
    const exact = fileIds.find(id => id === linkName || `${id}.md` === linkName || id === linkName.replace('.md', ''));
    if (exact) return exact;

    // 模糊匹配（忽略大小写）
    const lower = linkName.toLowerCase().replace('.md', '');
    return fileIds.find(id => id.toLowerCase() === lower) || null;
  }

  private collectFileIds(tree: FileNode[]): string[] {
    const ids: string[] = [];
    for (const node of tree) {
      if (node.type === NodeType.FILE) {
        ids.push(node.id);
      }
      if (node.children) {
        ids.push(...this.collectFileIds(node.children));
      }
    }
    return ids;
  }

  // ─── 图谱数据构建 ─────────────────────────────

  async getGraphData(): Promise<GraphData> {
    await this.ensureIndex();

    if (this.graphCache) return this.graphCache;

    const tree = await fileService.getFileTree();
    const fileIds = this.collectFileIds(tree);

    const nodes: GraphNodeData[] = [];
    const edges: GraphEdgeData[] = [];
    const edgeSet = new Set<string>();
    const nodeDegree = new Map<string, number>();

    // 计算节点度数
    for (const id of fileIds) {
      const outLinks = this.linkIndex.get(id);
      const outDegree = outLinks ? outLinks.size : 0;
      const inLinks = this.backlinkIndex.get(id);
      const inDegree = inLinks ? inLinks.size : 0;
      nodeDegree.set(id, outDegree + inDegree);
    }

    const maxDegree = Math.max(1, ...Array.from(nodeDegree.values()));

    // 构建节点
    const tagColors = new Map<string, string>();
    let colorIdx = 0;
    const palette = ['#7B68EE', '#52C41A', '#FAAD14', '#1890FF', '#FF7BA0', '#F5A623', '#00BCD4', '#E91E63'];

    const angleStep = (2 * Math.PI) / Math.max(fileIds.length, 1);

    for (let i = 0; i < fileIds.length; i++) {
      const id = fileIds[i];
      const name = id + '.md';
      let tags: string[] = [];
      try {
        const meta = await fileService.getMetadata(id);
        tags = meta.tags;
      } catch (e) { /* ignore */ }

      const group = tags.length > 0 ? tags[0] : 'uncategorized';
      let color = GROUP_COLORS[group];
      if (!color) {
        if (!tagColors.has(group)) {
          tagColors.set(group, palette[colorIdx % palette.length]);
          colorIdx++;
        }
        color = tagColors.get(group)!;
      }

      const degree = nodeDegree.get(id) || 0;
      const radius = 16 + (degree / maxDegree) * 24; // 16~40

      // 环形布局 + 随机扰动
      const angle = i * angleStep;
      const baseR = 120 + (fileIds.length > 10 ? fileIds.length * 8 : 0);
      const x = Math.cos(angle) * baseR + (Math.random() - 0.5) * 40;
      const y = Math.sin(angle) * baseR + (Math.random() - 0.5) * 40;

      nodes.push({ id, label: name.replace('.md', ''), x, y, radius, color, group });
    }

    // 构建边
    const idSet = new Set(fileIds);
    for (const sourceId of fileIds) {
      const targets = this.linkIndex.get(sourceId);
      if (!targets) continue;
      for (const targetId of targets) {
        if (!idSet.has(targetId)) continue;
        const edgeKey = [sourceId, targetId].sort().join('→');
        if (edgeSet.has(edgeKey)) continue;
        edgeSet.add(edgeKey);

        const strength = 0.5;
        edges.push({ source: sourceId, target: targetId, strength });
      }
    }

    this.graphCache = { nodes, edges };
    return this.graphCache;
  }

  async getLocalGraph(centerNoteId: string, depth: number = 1): Promise<GraphData> {
    const full = await this.getGraphData();
    const nodeMap = new Map(full.nodes.map(n => [n.id, n]));
    const centerNode = nodeMap.get(centerNoteId);
    if (!centerNode) {
      return { nodes: [], edges: [] };
    }

    // BFS 收集范围内的节点
    const visited = new Set<string>([centerNoteId]);
    let frontier = [centerNoteId];
    for (let d = 0; d < depth; d++) {
      const next: string[] = [];
      for (const nodeId of frontier) {
        // 出边
        const outLinks = this.linkIndex.get(nodeId);
        if (outLinks) {
          for (const targetId of outLinks) {
            if (!visited.has(targetId)) {
              visited.add(targetId);
              next.push(targetId);
            }
          }
        }
        // 入边
        const inLinks = this.backlinkIndex.get(nodeId);
        if (inLinks) {
          for (const sourceId of inLinks) {
            if (!visited.has(sourceId)) {
              visited.add(sourceId);
              next.push(sourceId);
            }
          }
        }
      }
      frontier = next;
    }

    // 标记中心节点
    centerNode.color = '#FF4D4F';
    centerNode.radius = Math.min(centerNode.radius * 1.4, 48);

    const filteredNodes = full.nodes.filter(n => visited.has(n.id));
    const filteredEdges = full.edges.filter(e => visited.has(e.source) && visited.has(e.target));

    return { nodes: filteredNodes, edges: filteredEdges };
  }

  async getLinkStats(noteId: string): Promise<LinkStats> {
    await this.ensureIndex();

    const outLinks = this.linkIndex.get(noteId);
    const outgoing = outLinks ? outLinks.size : 0;

    const inLinks = this.backlinkIndex.get(noteId);
    const incoming = inLinks ? inLinks.size : 0;

    // 检查断链（已链接但文件不存在）
    const tree = await fileService.getFileTree();
    const fileIds = this.collectFileIds(tree);
    let missing = 0;
    if (outLinks) {
      for (const targetId of outLinks) {
        if (!fileIds.includes(targetId)) missing++;
      }
    }

    const stats: LinkStats = { outgoing: outgoing, incoming: incoming, missing: missing };
    return stats;
  }
}
