// viewmodels/NoteViewModel.ets
// 笔记详情 ViewModel - 连接 UI 与 Service 层

import { fileService, IFileService, FileChangeEvent } from '../services/IFileService';
import { NoteMetadata } from '../services/ApiTypes';

@Observed
export class NoteViewModel {
  private service: IFileService;

  // 状态
  noteId: string = '';
  title: string = '';
  content: string = '';
  metadata: NoteMetadata | null = null;
  isLoading: boolean = false;
  isSaving: boolean = false;
  hasUnsavedChanges: boolean = false;
  saveError: string | null = null;

  // 编辑器状态
  cursorPosition: number = 0;
  scrollPosition: number = 0;
  selectionStart: number = 0;
  selectionEnd: number = 0;

  // 预览状态
  isPreviewMode: boolean = true;
  outlineExpanded: boolean = true;
  backlinksExpanded: boolean = true;

  constructor(service: IFileService = fileService) {
    this.service = service;
    this.setupFileWatcher();
  }

  async loadNote(noteId: string): Promise<void> {
    this.isLoading = true;
    this.saveError = null;
    try {
      const result = await this.service.readNote(noteId);
      this.noteId = noteId;
      this.title = result.metadata.title;
      this.content = result.content;
      this.metadata = result.metadata;
      this.hasUnsavedChanges = false;
    } catch (e) {
      this.saveError = '加载失败';
    } finally {
      this.isLoading = false;
    }
  }

  async saveNote(): Promise<void> {
    if (!this.hasUnsavedChanges || !this.noteId) return;
    this.isSaving = true;
    try {
      await this.service.writeNote(this.noteId, this.content, {
        updatedAt: Date.now()
      });
      this.hasUnsavedChanges = false;
      if (this.metadata) {
        this.metadata.updatedAt = Date.now();
      }
    } catch (e) {
      this.saveError = '保存失败';
    } finally {
      this.isSaving = false;
    }
  }

  updateContent(newContent: string): void {
    this.content = newContent;
    this.hasUnsavedChanges = true;
  }

  async updateFrontmatter(key: string, value: string | number | boolean | string[]): Promise<void> {
    if (!this.noteId) return;
    await this.service.updateFrontmatterField(this.noteId, key, value);
  }

  async addTag(tag: string): Promise<void> {
    if (!this.metadata) return;
    if (!this.metadata.tags.includes(tag)) {
      this.metadata.tags.push(tag);
      await this.service.writeNote(this.noteId, this.content, {
        tags: this.metadata.tags
      });
    }
  }

  async removeTag(tag: string): Promise<void> {
    if (!this.metadata) return;
    this.metadata.tags = this.metadata.tags.filter((t: string) => t !== tag);
    await this.service.writeNote(this.noteId, this.content, {
      tags: this.metadata.tags
    });
  }

  getWordCount(): number {
    return this.content.split(/\s+/).filter((w: string): boolean => w.length > 0).length;
  }

  getCharCount(): number {
    return this.content.length;
  }

  getReadingTime(): number {
    return Math.ceil(this.getWordCount() / 300);
  }

  private setupFileWatcher(): void {
    this.service.onFileChange((event: FileChangeEvent) => {
      if (event.nodeId === this.noteId && event.type === 'modify') {
        this.saveError = '文件已被外部修改，请刷新';
      }
    });
  }
}
