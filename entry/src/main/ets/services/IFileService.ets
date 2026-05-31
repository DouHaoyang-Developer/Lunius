// services/IFileService.ets
// 文件系统服务接口 - 后端实现后可替换为真实文件系统或远程 API

import { NoteMetadata, SearchResultItem, SearchMatch, NoteReadResult, FrontmatterValue } from './ApiTypes';
import { FileNode } from '../models/FileNode';
import { RealFileService } from './RealFileService';

export interface IFileService {
  // 读取目录树
  getFileTree(): Promise<FileNode[]>;

  // 读取笔记内容
  readNote(noteId: string): Promise<NoteReadResult>;

  // 写入笔记
  writeNote(noteId: string, content: string, metadata?: Partial<NoteMetadata>): Promise<void>;

  // 创建笔记
  createNote(path: string, title: string, template?: string): Promise<NoteMetadata>;

  // 删除笔记
  deleteNote(noteId: string): Promise<void>;

  // 重命名/移动
  moveNote(noteId: string, newPath: string): Promise<void>;

  // 搜索
  searchNotes(query: string, options?: SearchOptions): Promise<SearchResultItem[]>;

  // 获取笔记元数据
  getMetadata(noteId: string): Promise<NoteMetadata>;

  // 更新 frontmatter 单个字段
  updateFrontmatterField(noteId: string, key: string, value: FrontmatterValue): Promise<void>;

  // 获取所有笔记文件名（供自动补全等使用）
  getAllNoteFileNames(): Promise<string[]>;

  // 监听文件变化（后端推送）
  onFileChange(callback: (event: FileChangeEvent) => void): void;
}

export interface SearchOptions {
  includeContent?: boolean;
  caseSensitive?: boolean;
  regex?: boolean;
  scope?: 'vault' | 'folder' | 'current';
  tags?: string[];
}

export interface FileChangeEvent {
  type: 'create' | 'modify' | 'delete' | 'rename';
  nodeId: string;
  path: string;
  timestamp: number;
}

interface MockNoteData {
  content: string;
  metadata: NoteMetadata;
}

// 模拟实现（前端开发阶段使用）
export class MockFileService implements IFileService {
  private mockData: Map<string, MockNoteData> = new Map();

  constructor() {
    this.initMockData();
  }

  private makeMockNoteMetadata(id: string, title: string, filePath: string, createdDelta: number,
    updatedDelta: number, tagList: string[], aliasList: string[],
    wordC: number, charC: number, linkList: string[], blList: string[]): NoteMetadata {
    const fm = new Map<string, string | number | boolean | string[]>();
    fm.set('author', 'Team A');
    fm.set('priority', 'high');
    const md: NoteMetadata = {
      id: id, title: title, path: filePath,
      createdAt: Date.now() - createdDelta, updatedAt: Date.now() - updatedDelta,
      tags: tagList, aliases: aliasList,
      wordCount: wordC, charCount: charC,
      links: linkList, backlinks: blList, attachments: [],
      frontmatter: fm
    };
    return md;
  }

  private initMockData(): void {
    const meta1: NoteMetadata = this.makeMockNoteMetadata(
      '01-1', 'HarmonyOS 开发规范', '/01 项目笔记/HarmonyOS 开发规范.md',
      432000000, 86400000, ['dev', 'harmonyos'], ['HOS规范'],
      2340, 15600, ['ArkTS 性能优化.md', '响应式设计原理.md'], []
    );
    const data1: MockNoteData = {
      content: '# HarmonyOS 开发规范\n\n> 本文档定义了基于 ArkTS 与 ArkUI 的 HarmonyOS 应用开发标准。\n\n## 一、ArkTS 语言规范\n\n### 1.1 类型系统\n\nArkTS 是 TypeScript 的严格超集...',
      metadata: meta1
    };
    this.mockData.set(meta1.id, data1);

    const meta2: NoteMetadata = this.makeMockNoteMetadata(
      '01-2', 'ArkTS 性能优化', '/01 项目笔记/ArkTS 性能优化.md',
      345600000, 172800000, ['dev', 'performance'], [],
      1890, 12400, ['HarmonyOS 开发规范.md'], ['HarmonyOS 开发规范.md']
    );
    const data2: MockNoteData = {
      content: '# ArkTS 性能优化\n\n性能优化是 HarmonyOS 应用开发的关键...',
      metadata: meta2
    };
    this.mockData.set(meta2.id, data2);
  }

  async getFileTree(): Promise<FileNode[]> {
    const mod = await import('../models/FileNode');
    return mod.MockVaultData;
  }

  async readNote(noteId: string): Promise<NoteReadResult> {
    const data = this.mockData.get(noteId);
    if (!data) throw new Error('Note ' + noteId + ' not found');
    return data;
  }

  async writeNote(noteId: string, content: string, metadata?: Partial<NoteMetadata>): Promise<void> {
    const existing = this.mockData.get(noteId);
    if (existing) {
      existing.content = content;
      if (metadata) {
        existing.metadata.updatedAt = Date.now();
        if (metadata.tags) existing.metadata.tags = metadata.tags;
        if (metadata.aliases) existing.metadata.aliases = metadata.aliases;
      }
    }
  }

  async createNote(path: string, title: string, template?: string): Promise<NoteMetadata> {
    const id = 'note-' + Date.now().toString();
    const fm = new Map<string, string | number | boolean | string[]>();
    const metadata: NoteMetadata = {
      id: id, title: title, path: path + '/' + title + '.md',
      createdAt: Date.now(), updatedAt: Date.now(),
      tags: [], aliases: [], wordCount: 0, charCount: 0,
      links: [], backlinks: [], attachments: [], frontmatter: fm
    };
    const content = template || '# ' + title + '\n';
    const data: MockNoteData = { content: content, metadata: metadata };
    this.mockData.set(id, data);
    return metadata;
  }

  async deleteNote(noteId: string): Promise<void> {
    this.mockData.delete(noteId);
  }

  async moveNote(noteId: string, newPath: string): Promise<void> {
    const data = this.mockData.get(noteId);
    if (data) {
      data.metadata.path = newPath;
    }
  }

  async searchNotes(query: string, options?: SearchOptions): Promise<SearchResultItem[]> {
    const results: SearchResultItem[] = [];
    this.mockData.forEach((val: MockNoteData, id: string) => {
      if (val.metadata.title.toLowerCase().includes(query.toLowerCase()) ||
          val.content.toLowerCase().includes(query.toLowerCase())) {
        const match: SearchMatch = { line: 0, text: val.content.substring(0, 100), start: 0, end: 100 };
        const matches: SearchMatch[] = [match];
        const item: SearchResultItem = {
          noteId: id,
          title: val.metadata.title,
          path: val.metadata.path,
          matches: matches,
          score: 1.0
        };
        results.push(item);
      }
    });
    return results;
  }

  async getMetadata(noteId: string): Promise<NoteMetadata> {
    const data = this.mockData.get(noteId);
    if (!data) throw new Error('Note ' + noteId + ' not found');
    return data.metadata;
  }

  async updateFrontmatterField(noteId: string, key: string, value: FrontmatterValue): Promise<void> {
    const data = this.mockData.get(noteId);
    if (data) {
      data.metadata.updatedAt = Date.now();
    }
  }

  async getAllNoteFileNames(): Promise<string[]> {
    return Array.from(this.mockData.keys());
  }

  onFileChange(callback: (event: FileChangeEvent) => void): void {
    setTimeout(() => {
      callback({
        type: 'modify',
        nodeId: '01-1',
        path: '/01 项目笔记/HarmonyOS 开发规范.md',
        timestamp: Date.now()
      });
    }, 5000);
  }
}

// 单例导出 - 使用真实文件系统实现
export const fileService: IFileService = new RealFileService();
