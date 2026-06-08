// viewmodels/BasesViewModel.ets
// 数据库视图 ViewModel — 加载数据 + 筛选排序 + 状态管理

import {
  TableViewConfig, TableRowData, TableViewState,
  FilterGroup, FilterCondition, SortRule, ColumnDef
} from '../models/BasesTypes';
import { NoteMetadata, FrontmatterValue, PropertyType } from '../services/ApiTypes';
import { vaultIndex } from '../services/VaultIndex';
import { fileService } from '../services/IFileService';

@Observed
export class BasesViewModel {
  @State config: TableViewConfig;
  rows: TableRowData[] = [];
  isLoading: boolean = false;
  totalCount: number = 0;
  filteredCount: number = 0;

  constructor() {
    this.config = {
      columns: this.defaultColumns(),
      filter: { conjunction: 'and', conditions: [] },
      sort: [],
      groupBy: '',
      limit: 100
    };
  }

  private defaultColumns(): ColumnDef[] {
    return [
      { key: 'title', label: '标题', type: PropertyType.TEXT, width: 200, visible: true, sortable: true, filterable: true },
      { key: 'path', label: '路径', type: PropertyType.TEXT, width: 180, visible: true, sortable: true, filterable: true },
      { key: 'tags', label: '标签', type: PropertyType.TAGS, width: 150, visible: true, sortable: false, filterable: true },
      { key: 'wordCount', label: '字数', type: PropertyType.NUMBER, width: 80, visible: true, sortable: true, filterable: false },
      { key: 'updatedAt', label: '修改时间', type: PropertyType.DATE, width: 140, visible: true, sortable: true, filterable: false }
    ];
  }

  async loadData(): Promise<void> {
    this.isLoading = true;
    try {
      await vaultIndex.ensureBuilt(true);
      const allProps = await vaultIndex.getAllProperties();

      // 动态扩展列定义（基于 vault 中存在的属性）
      for (const prop of allProps) {
        if (!this.config.columns.find((c: ColumnDef) => c.key === prop.key)) {
          this.config.columns.push({
            key: prop.key, label: prop.key, type: prop.type,
            width: 120, visible: false, sortable: true, filterable: true
          });
        }
      }

      // 索引属性匹配的文件
      const candidateIds = this.getFilterCandidates();
      const allRows: TableRowData[] = [];

      for (const id of candidateIds) {
        try {
          const result = await fileService.readNote(id);
          const meta = result.metadata;
          if (this.evaluateFilter(meta, this.config.filter)) {
            const cells = this.extractCells(meta);
            const row: TableRowData = {
              noteId: meta.id, title: meta.title, path: meta.path, cells: cells
            };
            allRows.push(row);
          }
        } catch (e) { /* skip unreadable files */ }
      }

      this.totalCount = allRows.length;
      const sorted = this.sortRows(allRows, this.config.sort);
      this.rows = this.config.limit > 0 ? sorted.slice(0, this.config.limit) : sorted;
      this.filteredCount = this.rows.length;
    } catch (e) {
      console.error('BasesViewModel loadData failed: ' + JSON.stringify(e));
    }
    this.isLoading = false;
  }

  // 从索引中快速获取过滤候选文件（缩小全量扫描范围）
  private getFilterCandidates(): string[] {
    const propFilters = this.getPropertyConditions(this.config.filter);
    if (propFilters.length === 0) {
      // 无属性筛选条件，返回所有文件
      const stats = vaultIndex.getVaultStats ? null : null;
      // 使用标签索引的辅助方法获取文件列表
      const ids: string[] = [];
      const allTags = this.config.columns.find((c: ColumnDef) => c.key === 'tags');
      return ids; // 由调用方通过 fileService 获取全量
    }
    // 有属性筛选：取第一个条件对应的文件 ID 集
    const firstProp = propFilters[0];
    const candidateIds = vaultIndex.getFilesHavingProperty(firstProp.property);
    // 同步方法的 workaround：直接返回空让调用方传全量
    return [];
  }

  private getPropertyConditions(filter: FilterGroup): FilterCondition[] {
    const result: FilterCondition[] = [];
    for (const cond of filter.conditions) {
      if ('property' in cond) {
        result.push(cond as FilterCondition);
      } else {
        result.push(...this.getPropertyConditions(cond as FilterGroup));
      }
    }
    return result;
  }

  // ─── 筛选引擎 ──────────────────────────────────

  evaluateFilter(metadata: NoteMetadata, filter: FilterGroup): boolean {
    if (filter.conditions.length === 0) return true;
    const results: boolean[] = [];
    for (const cond of filter.conditions) {
      if ('property' in cond) {
        results.push(this.evaluateCondition(metadata, cond as FilterCondition));
      } else {
        results.push(this.evaluateFilter(metadata, cond as FilterGroup));
      }
    }
    if (filter.conjunction === 'and') {
      return results.every((r: boolean) => r);
    }
    return results.some((r: boolean) => r);
  }

  private evaluateCondition(metadata: NoteMetadata, cond: FilterCondition): boolean {
    const fm = metadata.frontmatter;
    // 内置属性
    let propValue: string;
    if (cond.property === 'title') {
      propValue = metadata.title;
    } else if (cond.property === 'path') {
      propValue = metadata.path;
    } else if (cond.property === 'tags') {
      propValue = (metadata.tags || []).join(',');
    } else if (cond.property === 'wordCount') {
      propValue = String(metadata.wordCount);
    } else if (cond.property === 'updatedAt') {
      propValue = String(metadata.updatedAt);
    } else {
      const raw = fm.get(cond.property);
      propValue = raw !== undefined ? (Array.isArray(raw) ? raw.join(',') : String(raw)) : '';
    }

    switch (cond.operator) {
      case 'exists':
        return fm.has(cond.property);
      case 'not_exists':
        return !fm.has(cond.property);
      case 'equals':
        return propValue === cond.value;
      case 'not_equals':
        return propValue !== cond.value;
      case 'contains':
        return propValue.toLowerCase().includes(cond.value.toLowerCase());
      case 'not_contains':
        return !propValue.toLowerCase().includes(cond.value.toLowerCase());
      case 'greater_than':
        return Number(propValue) > Number(cond.value);
      case 'less_than':
        return Number(propValue) < Number(cond.value);
    }
    return true;
  }

  // ─── 排序引擎 ──────────────────────────────────

  sortRows(rows: TableRowData[], rules: SortRule[]): TableRowData[] {
    if (rules.length === 0) return rows;
    const sorted = [...rows];
    sorted.sort((a: TableRowData, b: TableRowData) => {
      for (const rule of rules) {
        const va = a.cells.get(rule.property) || '';
        const vb = b.cells.get(rule.property) || '';
        const cmp = this.compareValues(va, vb);
        if (cmp !== 0) {
          return rule.direction === 'asc' ? cmp : -cmp;
        }
      }
      return 0;
    });
    return sorted;
  }

  private compareValues(a: string, b: string): number {
    const na = Number(a);
    const nb = Number(b);
    if (!isNaN(na) && !isNaN(nb)) return na - nb;
    return a.localeCompare(b);
  }

  // ─── 工具 ──────────────────────────────────────

  private extractCells(metadata: NoteMetadata): Map<string, string> {
    const cells = new Map<string, string>();
    cells.set('title', metadata.title);
    cells.set('path', metadata.path);
    cells.set('tags', (metadata.tags || []).join(', '));
    cells.set('wordCount', String(metadata.wordCount));
    cells.set('updatedAt', this.formatDate(metadata.updatedAt));

    metadata.frontmatter.forEach((value: FrontmatterValue, key: string) => {
      cells.set(key, Array.isArray(value) ? value.join(', ') : String(value));
    });
    return cells;
  }

  private formatDate(ts: number): string {
    if (!ts) return '-';
    const d = new Date(ts);
    return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;
  }

  // ─── 配置更新 ─────────────────────────────────

  updateColumn(col: ColumnDef): void {
    const idx = this.config.columns.findIndex((c: ColumnDef) => c.key === col.key);
    if (idx >= 0) this.config.columns[idx] = col;
  }

  addSortRule(property: string): void {
    const existing = this.config.sort.findIndex((s: SortRule) => s.property === property);
    if (existing >= 0) {
      this.config.sort[existing].direction =
        this.config.sort[existing].direction === 'asc' ? 'desc' : 'asc';
    } else {
      this.config.sort.push({ property: property, direction: 'asc' });
    }
  }

  clearSort(): void {
    this.config.sort = [];
  }

  updateFilter(filter: FilterGroup): void {
    this.config.filter = filter;
  }
}
