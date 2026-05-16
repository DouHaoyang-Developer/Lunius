// services/IFileService.ets
// 文件系统服务接口 - 后端实现后可替换为真实文件系统或远程 API

import { NoteMetadata, SearchResultItem, FrontmatterValue } from './ApiTypes';
import { FileNode } from '../models/FileNode';
import { RealFileService } from './RealFileService';

export interface IFileService {
  // 读取目录树
  getFileTree(): Promise<FileNode[]>;

  // 读取笔记内容
  readNote(noteId: string): Promise<{ content: string; metadata: NoteMetadata }>;

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

// 模拟实现（前端开发阶段使用）
export class MockFileService implements IFileService {
  private mockData: Map<string, { content: string; metadata: NoteMetadata }> = new Map();

  constructor() {
    this.initMockData();
  }

  private makeMockFrontmatter(author: string, priority: string, reviewed: boolean): Map<string, string | number | boolean | string[]> {
    const fm = new Map<string, string | number | boolean | string[]>();
    fm.set('author', author);
    fm.set('priority', priority);
    fm.set('reviewed', reviewed);
    return fm;
  }

  private initMockData(): void {
    const now = Date.now();
    const notes = [
      {
        id: '01-1',
        content: '# HarmonyOS 开发规范\n\n> 本文档定义了基于 ArkTS 与 ArkUI 的 HarmonyOS 应用开发标准。\n\n## 一、ArkTS 语言规范\n\n### 1.1 类型系统\n\nArkTS 是 TypeScript 的严格超集...',
        metadata: {
          id: '01-1', title: 'HarmonyOS 开发规范', path: '/01 项目笔记/HarmonyOS 开发规范.md',
          createdAt: now - 86400000 * 5, updatedAt: now - 86400000,
          tags: ['dev', 'harmonyos'], aliases: ['HOS规范'],
          wordCount: 2340, charCount: 15600,
          links: ['ArkTS 性能优化.md', '响应式设计原理.md'],
          backlinks: [], attachments: [],
          frontmatter: this.makeMockFrontmatter('Team A', 'high', false)
        }
      },
      {
        id: '01-2',
        content: '# ArkTS 性能优化\n\n性能优化是 HarmonyOS 应用开发的关键...',
        metadata: {
          id: '01-2', title: 'ArkTS 性能优化', path: '/01 项目笔记/ArkTS 性能优化.md',
          createdAt: now - 86400000 * 4, updatedAt: now - 86400000 * 2,
          tags: ['dev', 'performance'], aliases: [],
          wordCount: 1890, charCount: 12400,
          links: ['HarmonyOS 开发规范.md'],
          backlinks: ['HarmonyOS 开发规范.md'], attachments: [],
          frontmatter: this.makeMockFrontmatter('Team B', 'medium', true)
        }
      }
    ];
    notes.forEach(n => this.mockData.set(n.id, n));
  }

  async getFileTree(): Promise<FileNode[]> {
    // 返回与 FileNode.ets 兼容的树
    const { MockVaultData } = await import('../models/FileNode');
    return MockVaultData;
  }

  async readNote(noteId: string): Promise<{ content: string; metadata: NoteMetadata }> {
    const data = this.mockData.get(noteId);
    if (!data) throw new Error(`Note ${noteId} not found`);
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
    const id = `note-${Date.now()}`;
    const metadata: NoteMetadata = {
      id, title, path: `${path}/${title}.md`,
      createdAt: Date.now(), updatedAt: Date.now(),
      tags: [], aliases: [], wordCount: 0, charCount: 0,
      links: [], backlinks: [], attachments: [], frontmatter: new Map<string, string | number | boolean | string[]>()
    };
    this.mockData.set(id, { content: template ?? `# ${title}\n`, metadata });
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
    this.mockData.forEach((val, id) => {
      if (val.metadata.title.toLowerCase().includes(query.toLowerCase()) ||
          val.content.toLowerCase().includes(query.toLowerCase())) {
        results.push({
          noteId: id,
          title: val.metadata.title,
          path: val.metadata.path,
          matches: [{ line: 0, text: val.content.substring(0, 100), start: 0, end: 100 }],
          score: 1.0
        });
      }
    });
    return results;
  }

  async getMetadata(noteId: string): Promise<NoteMetadata> {
    const data = this.mockData.get(noteId);
    if (!data) throw new Error(`Note ${noteId} not found`);
    return data.metadata;
  }

  async updateFrontmatterField(noteId: string, key: string, value: FrontmatterValue): Promise<void> {
    // Mock: 无实际持久化
    const data = this.mockData.get(noteId);
    if (data) {
      data.metadata.updatedAt = Date.now();
    }
  }

  onFileChange(callback: (event: FileChangeEvent) => void): void {
    // 模拟：5秒后触发一个变更事件
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

// 保留 MockFileService 供测试和后端对接参考
export { MockFileService };
