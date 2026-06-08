// services/VaultIndex.ets
// Vault 索引服务 — 全局标签索引、Vault 统计、按标签查询

import { FileNode, NodeType } from '../models/FileNode';
import { VaultStats, FrontmatterValue, PropertyType, PropertyUsage } from './ApiTypes';
import { fileService, IFileService } from './IFileService';

const TAG = 'VaultIndex';

export interface TagCount {
  tag: string;
  count: number;
}

export class VaultIndex {
  private tagIndex: Map<string, string[]> = new Map(); // tag → noteIds
  private fileTags: Map<string, string[]> = new Map(); // noteId → tags
  private propertyIndex: Map<string, Map<string, string[]>> = new Map(); // propertyKey → (valStr → noteIds)
  private stats: VaultStats | null = null;
  private lastUpdate: number = 0;
  private isBuilding: boolean = false;

  private needRefresh(): boolean {
    return this.tagIndex.size === 0 || (Date.now() - this.lastUpdate > 30000);
  }

  async ensureBuilt(force: boolean = false): Promise<void> {
    if (this.isBuilding) return;
    if (!force && !this.needRefresh()) return;

    this.isBuilding = true;
    try {
      this.tagIndex.clear();
      this.fileTags.clear();
      this.propertyIndex.clear();

      const tree = await fileService.getFileTree();
      const fileIds = this.collectFileIds(tree);

      let totalWords = 0;
      let totalChars = 0;
      let totalLinks = 0;
      let oldestNote = Date.now();
      let latestNote = 0;

      for (const id of fileIds) {
        try {
          const result = await fileService.readNote(id);
          const metadata = result.metadata;
          const tags = metadata.tags || [];

          this.fileTags.set(id, tags);

          for (const tag of tags) {
            if (!this.tagIndex.has(tag)) {
              this.tagIndex.set(tag, []);
            }
            this.tagIndex.get(tag)!.push(id);
          }

          // 构建属性索引
          const frontmatter = metadata.frontmatter;
          if (frontmatter && frontmatter.size > 0) {
            frontmatter.forEach((value: FrontmatterValue, key: string) => {
              if (!this.propertyIndex.has(key)) {
                this.propertyIndex.set(key, new Map<string, string[]>());
              }
              const valMap = this.propertyIndex.get(key)!;
              const valStr = Array.isArray(value) ? value.join(',') : String(value);
              if (!valMap.has(valStr)) {
                valMap.set(valStr, []);
              }
              valMap.get(valStr)!.push(id);
            });
          }

          totalWords += metadata.wordCount || 0;
          totalChars += metadata.charCount || 0;
          totalLinks += (metadata.links || []).length;

          if (metadata.createdAt < oldestNote) oldestNote = metadata.createdAt;
          if (metadata.updatedAt > latestNote) latestNote = metadata.updatedAt;
        } catch (e) {
          console.error(`${TAG} index error for ${id}: ${JSON.stringify(e)}`);
        }
      }

      const allTags = Array.from(this.tagIndex.keys());
      this.stats = {
        totalNotes: fileIds.length,
        totalWords,
        totalLinks,
        totalTags: allTags.length,
        oldestNote,
        latestNote
      };

      this.lastUpdate = Date.now();
    } finally {
      this.isBuilding = false;
    }
  }

  // ─── 标签查询 ─────────────────────────────────

  async getAllTags(): Promise<string[]> {
    await this.ensureBuilt();
    return Array.from(this.tagIndex.keys()).sort();
  }

  async getTagCounts(): Promise<TagCount[]> {
    await this.ensureBuilt();
    const result: TagCount[] = [];
    this.tagIndex.forEach((noteIds, tag) => {
      result.push({ tag, count: noteIds.length });
    });
    return result.sort((a, b) => b.count - a.count);
  }

  async getFilesByTag(tag: string): Promise<string[]> {
    await this.ensureBuilt();
    return this.tagIndex.get(tag) || [];
  }

  async getTagsForFile(noteId: string): Promise<string[]> {
    await this.ensureBuilt();
    return this.fileTags.get(noteId) || [];
  }

  // ─── Vault 统计 ────────────────────────────────

  async getVaultStats(): Promise<VaultStats> {
    await this.ensureBuilt();
    return this.stats || {
      totalNotes: 0, totalWords: 0, totalLinks: 0,
      totalTags: 0, oldestNote: 0, latestNote: 0
    };
  }

  async getNoteCount(): Promise<number> {
    await this.ensureBuilt();
    return this.stats?.totalNotes || 0;
  }

  // ─── 属性查询 ────────────────────────────────

  async getAllProperties(): Promise<PropertyUsage[]> {
    await this.ensureBuilt();
    const result: PropertyUsage[] = [];
    this.propertyIndex.forEach((valMap: Map<string, string[]>, key: string) => {
      const values: FrontmatterValue[] = [];
      let count = 0;
      valMap.forEach((noteIds: string[], valStr: string) => {
        values.push(this.guessValueType(valStr));
        count += noteIds.length;
      });
      result.push({
        key: key,
        type: this.guessPropertyType(values),
        count: count,
        values: values.slice(0, 20)
      });
    });
    return result.sort((a, b) => b.count - a.count);
  }

  async getPropertyValues(propertyKey: string): Promise<FrontmatterValue[]> {
    await this.ensureBuilt();
    const valMap = this.propertyIndex.get(propertyKey);
    if (!valMap) return [];
    const values: FrontmatterValue[] = [];
    valMap.forEach((_noteIds: string[], valStr: string) => {
      values.push(this.guessValueType(valStr));
    });
    return values;
  }

  async getFilesByProperty(key: string, value: FrontmatterValue): Promise<string[]> {
    await this.ensureBuilt();
    const valMap = this.propertyIndex.get(key);
    if (!valMap) return [];
    const valStr = Array.isArray(value) ? value.join(',') : String(value);
    return valMap.get(valStr) || [];
  }

  async getFilesHavingProperty(key: string): Promise<string[]> {
    await this.ensureBuilt();
    const valMap = this.propertyIndex.get(key);
    if (!valMap) return [];
    const allIds: string[] = [];
    valMap.forEach((noteIds: string[]) => {
      allIds.push(...noteIds);
    });
    return allIds;
  }

  private guessValueType(str: string): FrontmatterValue {
    if (str === 'true') return true;
    if (str === 'false') return false;
    const num = Number(str);
    if (!isNaN(num) && str.length > 0) return num;
    if (str.includes(',')) return str.split(',').filter((s: string) => s.length > 0);
    return str;
  }

  private guessPropertyType(values: FrontmatterValue[]): PropertyType {
    const types = values.map((v: FrontmatterValue) => {
      if (typeof v === 'boolean') return PropertyType.CHECKBOX;
      if (typeof v === 'number') return PropertyType.NUMBER;
      if (Array.isArray(v)) return PropertyType.TAGS;
      return PropertyType.TEXT;
    });
    return types[0] ?? PropertyType.TEXT;
  }

  // ─── 工具 ──────────────────────────────────────

  private collectFileIds(tree: FileNode[]): string[] {
    const ids: string[] = [];
    for (const node of tree) {
      if (node.type === NodeType.FILE) ids.push(node.id);
      if (node.children) ids.push(...this.collectFileIds(node.children));
    }
    return ids;
  }

  invalidate(): void {
    this.lastUpdate = 0;
    this.stats = null;
    this.propertyIndex.clear();
    this.tagIndex.clear();
    this.fileTags.clear();
  }
}

// 单例导出
export const vaultIndex: VaultIndex = new VaultIndex();
