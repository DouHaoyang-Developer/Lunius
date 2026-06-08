// utils/LQLExecutor.ets
// LQL 查询执行引擎 — source解析 → filter筛选 → sort排序 → limit截断

import { LQLAst, LQLOutputType, parseLQL } from './LQLParser';
import { SortRule, TableRowData } from '../models/BasesTypes';
import { NoteMetadata, FrontmatterValue, PropertyType } from '../services/ApiTypes';
import { vaultIndex } from '../services/VaultIndex';
import { fileService } from '../services/IFileService';

export interface LQLResult {
  type: string;
  headers: string[];
  rows: TableRowData[];
  totalCount: number;
}

export class LQLExecutor {
  async execute(lqlText: string): Promise<LQLResult> {
    const startTime = Date.now();
    const ast = parseLQL(lqlText);

    // 1. 获取候选文件
    const candidateIds = await this.resolveSources(ast);
    if (candidateIds.length === 0) {
      return { type: ast.outputType, headers: [], rows: [], totalCount: 0 };
    }

    // 2. 加载元数据并筛选
    const rows: TableRowData[] = [];
    for (const id of candidateIds) {
      try {
        const result = await fileService.readNote(id);
        const meta = result.metadata;
        const cells = this.extractCells(meta, ast.columns);
        const row: TableRowData = { noteId: id, title: meta.title, path: meta.path, cells: cells };
        rows.push(row);
      } catch (e) { /* skip */ }
    }

    // 3. 排序
    if (ast.sortRules.length > 0) {
      this.sortRows(rows, ast.sortRules);
    }

    // 4. 截断
    const limited = ast.limit > 0 ? rows.slice(0, ast.limit) : rows;

    // 5. 确定列头
    const headers = ast.columns.length > 0 ? ast.columns :
      ['title', 'path', 'tags'];

    return {
      type: ast.outputType,
      headers: headers,
      rows: limited,
      totalCount: limited.length
    };
  }

  private async resolveSources(ast: LQLAst): Promise<string[]> {
    if (ast.fromSources.length === 0) {
      // 无 FROM → 返回所有文件
      const allIds: string[] = [];
      const tags = await vaultIndex.getAllTags();
      for (const tag of tags) {
        const ids = await vaultIndex.getFilesByTag(tag);
        for (const id of ids) {
          if (!allIds.includes(id)) allIds.push(id);
        }
      }
      return allIds;
    }

    const ids: string[] = [];
    for (const src of ast.fromSources) {
      if (src.type === 'tag') {
        const tagIds = await vaultIndex.getFilesByTag(src.value);
        for (const id of tagIds) {
          if (!ids.includes(id)) ids.push(id);
        }
      } else if (src.type === 'path') {
        // 路径匹配：从文件树中筛选
        const tree = await fileService.getFileTree();
        this.collectByPath(tree, src.value, ids);
      }
    }
    return ids;
  }

  private collectByPath(nodes: object[], path: string, result: string[]): void {
    for (const node of nodes as Record<string, Object>[]) {
      const nodePath = node['path'] as string || '';
      const nodeId = node['id'] as string || '';
      const children = node['children'] as object[] | undefined;
      if (nodePath.includes(path) && nodeId) {
        result.push(nodeId);
      }
      if (children) {
        this.collectByPath(children, path, result);
      }
    }
  }

  private extractCells(meta: NoteMetadata, columns: string[]): Map<string, string> {
    const cells = new Map<string, string>();
    cells.set('title', meta.title);
    cells.set('path', meta.path);
    cells.set('tags', (meta.tags || []).join(', '));
    cells.set('wordCount', String(meta.wordCount));
    cells.set('createdAt', String(meta.createdAt));
    cells.set('updatedAt', String(meta.updatedAt));

    meta.frontmatter.forEach((v: FrontmatterValue, k: string) => {
      cells.set(k, Array.isArray(v) ? v.join(', ') : String(v));
    });

    return cells;
  }

  private sortRows(rows: TableRowData[], rules: SortRule[]): void {
    rows.sort((a: TableRowData, b: TableRowData) => {
      for (const rule of rules) {
        const va = a.cells.get(rule.property) || '';
        const vb = b.cells.get(rule.property) || '';
        const na = Number(va);
        const nb = Number(vb);
        let cmp: number;
        if (!isNaN(na) && !isNaN(nb)) {
          cmp = na - nb;
        } else {
          cmp = va.localeCompare(vb);
        }
        if (cmp !== 0) return rule.direction === 'asc' ? cmp : -cmp;
      }
      return 0;
    });
  }
}

export const lqlExecutor: LQLExecutor = new LQLExecutor();
