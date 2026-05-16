// services/VaultIndex.ets
// Vault 索引服务 — 全局标签索引、Vault 统计、按标签查询

import { FileNode, NodeType } from '../models/FileNode';
import { VaultStats } from './ApiTypes';
import { fileService, IFileService } from './IFileService';

const TAG = 'VaultIndex';

export interface TagCount {
  tag: string;
  count: number;
}

export class VaultIndex {
  private tagIndex: Map<string, string[]> = new Map(); // tag → noteIds
  private fileTags: Map<string, string[]> = new Map(); // noteId → tags
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

      const tree = await fileService.getFileTree();
      const fileIds = this.collectFileIds(tree);

      let totalWords = 0;
      let totalChars = 0;
      let totalLinks = 0;
      let oldestNote = Date.now();
      let latestNote = 0;

      for (const id of fileIds) {
        try {
          const { metadata } = await fileService.readNote(id);
          const tags = metadata.tags || [];

          this.fileTags.set(id, tags);

          for (const tag of tags) {
            if (!this.tagIndex.has(tag)) {
              this.tagIndex.set(tag, []);
            }
            this.tagIndex.get(tag)!.push(id);
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
  }
}

// 单例导出
export const vaultIndex: VaultIndex = new VaultIndex();
