// services/VersionService.ets
// 版本控制实现 — 本地快照 + 行级 Diff 对比
// 在每次 NoteViewModel.saveNote() 成功后自动创建版本

import { FileService } from '../utils/FileService';
import { IVersionService } from './IVersionService';
import {
  VersionEntry, VersionDetail, VersionCompareResult, VersionStats
} from './ApiTypes';

interface DiffResult {
  additions: number;
  deletions: number;
  text: string;
}

export class VersionService implements IVersionService {
  private static instance: VersionService;
  private fileService: FileService;
  private versionIndex: Map<string, VersionEntry[]> = new Map();

  private static readonly VERSIONS_DIR = '.lunius/versions';
  private static readonly INDEX_FILE = '.lunius/version_index.json';
  private static readonly MAX_VERSIONS_PER_NOTE = 50;

  private constructor() {
    this.fileService = FileService.getInstance();
  }

  static getInstance(): VersionService {
    if (!VersionService.instance) {
      VersionService.instance = new VersionService();
    }
    return VersionService.instance;
  }

  async init(): Promise<void> {
    const indexPath = this.getIndexPath();
    const content = await this.fileService.readFile(indexPath);
    if (content && content.length > 0) {
      try {
        const parsed = JSON.parse(content) as object;
        const data = parsed as Record<string, Object>;
        const keys = Object.keys(data);
        for (let i = 0; i < keys.length; i++) {
          const key = keys[i];
          const val = data[key];
          this.versionIndex.set(key, val as VersionEntry[]);
        }
      } catch (e) {
        console.error('VersionService: failed to parse index, resetting');
        this.versionIndex = new Map();
      }
    }
    console.info(`VersionService initialized: ${this.getTotalTrackedNotes()} notes tracked`);
  }

  async createVersion(noteId: string, content: string): Promise<VersionEntry> {
    const entries = this.getEntriesForNote(noteId);
    const lastEntry = entries[entries.length - 1];

    // 去重：内容未变化时跳过
    if (lastEntry) {
      const lastContent = await this.readVersionContent(noteId, lastEntry.versionId);
      if (lastContent === content) {
        return lastEntry;
      }
    }

    const versionNumber = (lastEntry?.versionNumber ?? 0) + 1;
    const timestamp = Date.now();
    const versionId = `v${String(versionNumber).padStart(3, '0')}_${timestamp}`;

    const entry: VersionEntry = {
      versionId,
      noteId,
      timestamp,
      contentSize: content.length,
      versionNumber,
      isCheckpoint: false
    };

    // 确保版本目录存在
    const versionDir = `${this.getBasePath()}/${VersionService.VERSIONS_DIR}/${noteId}`;
    await this.fileService.createDirectory(`${VersionService.VERSIONS_DIR}/${noteId}`);

    // 写入版本文件
    const versionPath = this.getVersionPath(noteId, versionId);
    await this.fileService.writeFile(versionPath, content);

    // 更新索引
    if (!this.versionIndex.has(noteId)) {
      this.versionIndex.set(noteId, []);
    }
    const noteVersions = this.versionIndex.get(noteId)!;
    noteVersions.push(entry);

    // 保存索引
    await this.persistIndex();

    // 自动清理超出限制的旧版本
    if (noteVersions.length > VersionService.MAX_VERSIONS_PER_NOTE) {
      await this.cleanupVersions(noteId, VersionService.MAX_VERSIONS_PER_NOTE);
    }

    return entry;
  }

  async listVersions(noteId: string, limit: number = 20, offset: number = 0): Promise<VersionEntry[]> {
    const entries = this.getEntriesForNote(noteId);
    return entries.slice(offset, offset + limit);
  }

  async getVersion(noteId: string, versionId: string): Promise<VersionDetail> {
    const entry = this.findEntry(noteId, versionId);
    if (!entry) {
      throw new Error(`Version ${versionId} not found for note ${noteId}`);
    }
    const contentResult = await this.readVersionContent(noteId, versionId);
    const detail: VersionDetail = {
      versionId: entry.versionId,
      noteId: entry.noteId,
      timestamp: entry.timestamp,
      contentSize: entry.contentSize,
      versionNumber: entry.versionNumber,
      isCheckpoint: entry.isCheckpoint,
      message: entry.message,
      content: contentResult
    };
    return detail;
  }

  async restoreVersion(noteId: string, versionId: string): Promise<VersionEntry> {
    const detail = await this.getVersion(noteId, versionId);
    // 恢复版本：以旧内容创建一个新版本
    return this.createVersion(noteId, detail.content);
  }

  async compareVersions(
    noteId: string, oldVersionId: string, newVersionId: string
  ): Promise<VersionCompareResult> {
    const oldDetail = await this.getVersion(noteId, oldVersionId);
    const newDetail = await this.getVersion(noteId, newVersionId);
    const diff = this.computeDiff(oldDetail.content, newDetail.content);

    return {
      oldVersion: oldDetail,
      newVersion: newDetail,
      additions: diff.additions,
      deletions: diff.deletions,
      unifiedDiff: diff.text
    };
  }

  async cleanupVersions(noteId: string, keepRecent: number): Promise<number> {
    const entries = this.getEntriesForNote(noteId);
    if (entries.length <= keepRecent) {
      return 0;
    }

    const toDelete = entries.slice(0, entries.length - keepRecent)
      .filter((e: VersionEntry) => !e.isCheckpoint);

    for (const entry of toDelete) {
      const path = this.getVersionPath(noteId, entry.versionId);
      const deleted = await this.fileService.deleteFile(path);
      if (!deleted) {
        console.warn(`VersionService: failed to delete ${path}`);
      }
    }

    // 更新索引
    const keepIds = new Set(
      entries.slice(entries.length - keepRecent).map((e: VersionEntry) => e.versionId)
    );
    const checkpointIds = new Set(
      entries.filter((e: VersionEntry) => e.isCheckpoint).map((e: VersionEntry) => e.versionId)
    );
    this.versionIndex.set(noteId, entries.filter(
      (e: VersionEntry) => keepIds.has(e.versionId) || checkpointIds.has(e.versionId)
    ));

    await this.persistIndex();
    return toDelete.length;
  }

  async getVersionStats(): Promise<VersionStats> {
    let totalVersions = 0;
    let totalSize = 0;
    let notesTracked = 0;

    const noteIds: string[] = [];
    this.versionIndex.forEach((_entries: VersionEntry[], id: string) => { noteIds.push(id); });
    for (const noteId of noteIds) {
      const entries = this.versionIndex.get(noteId)!;
      if (entries.length > 0) {
        notesTracked++;
        totalVersions += entries.length;
        totalSize += entries.reduce((sum: number, e: VersionEntry) => sum + e.contentSize, 0);
      }
    }

    return { totalVersions, totalSize, notesTracked };
  }

  async markCheckpoint(noteId: string, versionId: string, message?: string): Promise<void> {
    const entry = this.findEntry(noteId, versionId);
    if (!entry) {
      throw new Error(`Version ${versionId} not found for note ${noteId}`);
    }
    entry.isCheckpoint = true;
    if (message) {
      entry.message = message;
    }
    await this.persistIndex();
  }

  // ─── 私有方法 ────────────────────────────────

  private getBasePath(): string {
    return this.fileService.getBaseDirectory();
  }

  private getIndexPath(): string {
    return `${this.getBasePath()}/${VersionService.INDEX_FILE}`;
  }

  private getVersionPath(noteId: string, versionId: string): string {
    return `${this.getBasePath()}/${VersionService.VERSIONS_DIR}/${noteId}/${versionId}.md`;
  }

  private async readVersionContent(noteId: string, versionId: string): Promise<string> {
    return this.fileService.readFile(this.getVersionPath(noteId, versionId));
  }

  private getEntriesForNote(noteId: string): VersionEntry[] {
    return this.versionIndex.get(noteId) ?? [];
  }

  private findEntry(noteId: string, versionId: string): VersionEntry | undefined {
    const entries = this.getEntriesForNote(noteId);
    return entries.find((e: VersionEntry) => e.versionId === versionId);
  }

  private async persistIndex(): Promise<void> {
    let json = '{';
    const noteIds: string[] = [];
    this.versionIndex.forEach((_entries: VersionEntry[], id: string) => { noteIds.push(id); });
    for (let i = 0; i < noteIds.length; i++) {
      const id = noteIds[i];
      const entries = this.versionIndex.get(id)!;
      json += '"' + id + '":' + JSON.stringify(entries);
      if (i < noteIds.length - 1) {
        json += ',';
      }
    }
    json += '}';
    await this.fileService.writeFile(this.getIndexPath(), json);
  }

  private getTotalTrackedNotes(): number {
    return this.versionIndex.size;
  }

  /**
   * 行级 Diff 算法（基于 LCS）
   */
  private computeDiff(oldText: string, newText: string): DiffResult {
    const oldLines = oldText.split('\n');
    const newLines = newText.split('\n');
    const lcs = this.longestCommonSubsequence(oldLines, newLines);

    let additions = 0;
    let deletions = 0;
    let text = '';
    let oi = 0;
    let ni = 0;
    let li = 0;

    while (li < lcs.length || oi < oldLines.length || ni < newLines.length) {
      if (li < lcs.length && oi < oldLines.length && oldLines[oi] === lcs[li]) {
        if (ni < newLines.length && newLines[ni] === lcs[li]) {
          text += `  ${lcs[li]}\n`;
          oi++;
          ni++;
          li++;
        } else {
          text += `+ ${newLines[ni]}\n`;
          additions++;
          ni++;
        }
      } else if (oi < oldLines.length && (li >= lcs.length || oldLines[oi] !== lcs[li])) {
        text += `- ${oldLines[oi]}\n`;
        deletions++;
        oi++;
      } else if (ni < newLines.length && (li >= lcs.length || newLines[ni] !== lcs[li])) {
        text += `+ ${newLines[ni]}\n`;
        additions++;
        ni++;
      } else {
        break;
      }
    }

    const result: DiffResult = { additions, deletions, text };
    return result;
  }

  private longestCommonSubsequence(a: string[], b: string[]): string[] {
    const m = a.length;
    const n = b.length;
    const dp: number[][] = [];
    for (let x = 0; x <= m; x++) {
      const row: number[] = [];
      for (let y = 0; y <= n; y++) {
        row.push(0);
      }
      dp.push(row);
    }

    for (let i = 1; i <= m; i++) {
      for (let j = 1; j <= n; j++) {
        if (a[i - 1] === b[j - 1]) {
          dp[i][j] = dp[i - 1][j - 1] + 1;
        } else {
          dp[i][j] = Math.max(dp[i - 1][j], dp[i][j - 1]);
        }
      }
    }

    const result: string[] = [];
    let i = m;
    let j = n;
    while (i > 0 && j > 0) {
      if (a[i - 1] === b[j - 1]) {
        result.unshift(a[i - 1]);
        i--;
        j--;
      } else if (dp[i - 1][j] > dp[i][j - 1]) {
        i--;
      } else {
        j--;
      }
    }
    return result;
  }
}