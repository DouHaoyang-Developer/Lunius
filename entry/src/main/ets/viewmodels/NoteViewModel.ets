// viewmodels/NoteViewModel.ets
// 笔记详情 ViewModel - 连接 UI 与 Service 层
// 支持防抖自动保存、错误回调、文件变更监听

import { fileService, IFileService, FileChangeEvent } from '../services/IFileService';
import { NoteMetadata } from '../services/ApiTypes';

@Observed
export class NoteViewModel {
  private service: IFileService;
  private saveTimer: number = -1;
  private static readonly SAVE_DEBOUNCE_MS: number = 2000;
  private static readonly SAVE_INTERVAL_MS: number = 20000;
  private saveIntervalTimer: number = -1;

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

  // 错误回调（UI 层注册，用于 Toast 提示）
  onErrorCallback?: (message: string) => void;
  onSaveCallback?: (success: boolean) => void;

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
      this.notifyError('加载笔记失败');
    } finally {
      this.isLoading = false;
    }
  }

  async saveNote(): Promise<void> {
    if (!this.noteId) return;
    if (!this.hasUnsavedChanges) {
      this.startIntervalSave();
      return;
    }
    this.isSaving = true;
    this.saveError = null;
    try {
      await this.service.writeNote(this.noteId, this.content, {
        updatedAt: Date.now()
      });
      this.hasUnsavedChanges = false;
      if (this.metadata) {
        this.metadata.updatedAt = Date.now();
      }
      this.notifySave(true);
    } catch (e) {
      this.saveError = '保存失败';
      this.notifyError('保存笔记失败');
      this.notifySave(false);
    } finally {
      this.isSaving = false;
      this.startIntervalSave();
    }
  }

  // 内容变更时：标记脏数据 + 启动防抖保存
  updateContent(newContent: string): void {
    this.content = newContent;
    this.hasUnsavedChanges = true;
    this.debouncedSave();
  }

  // 插入文本到光标位置
  insertTextAtCursor(text: string, cursorPos: number): void {
    if (cursorPos < 0) {
      this.content = this.content + text;
    } else {
      const before = this.content.substring(0, cursorPos);
      const after = this.content.substring(cursorPos);
      this.content = before + text + after;
    }
    this.hasUnsavedChanges = true;
    this.debouncedSave();
  }

  async updateFrontmatter(key: string, value: string | number | boolean | string[]): Promise<void> {
    if (!this.noteId) return;
    await this.service.updateFrontmatterField(this.noteId, key, value);
    this.debouncedSave();
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

  // ─── 保存策略 ────────────────────────────────

  // 防抖保存：内容变更后 2s 内无新输入则自动保存
  private debouncedSave(): void {
    if (this.saveTimer !== -1) {
      clearTimeout(this.saveTimer);
    }
    this.saveTimer = setTimeout(() => {
      this.saveTimer = -1;
      this.saveNote();
    }, NoteViewModel.SAVE_DEBOUNCE_MS);
  }

  // 定时兜底保存：每 20s 检查并保存（参照 LightNote）
  startIntervalSave(): void {
    if (this.saveIntervalTimer !== -1) return;
    this.saveIntervalTimer = setInterval(() => {
      if (this.hasUnsavedChanges && this.noteId) {
        this.saveNote();
      }
    }, NoteViewModel.SAVE_INTERVAL_MS);
  }

  stopIntervalSave(): void {
    if (this.saveIntervalTimer !== -1) {
      clearInterval(this.saveIntervalTimer);
      this.saveIntervalTimer = -1;
    }
  }

  // 立即落盘：应用进入后台时调用
  flushToDisk(): void {
    if (this.saveTimer !== -1) {
      clearTimeout(this.saveTimer);
      this.saveTimer = -1;
    }
    if (this.hasUnsavedChanges && this.noteId) {
      this.service.writeNote(this.noteId, this.content, {
        updatedAt: Date.now()
      });
    }
  }

  release(): void {
    this.stopIntervalSave();
    if (this.saveTimer !== -1) {
      clearTimeout(this.saveTimer);
      this.saveTimer = -1;
    }
  }

  // ─── 错误通知 ────────────────────────────────

  private notifyError(message: string): void {
    if (this.onErrorCallback) {
      this.onErrorCallback(message);
    }
  }

  private notifySave(success: boolean): void {
    if (this.onSaveCallback) {
      this.onSaveCallback(success);
    }
  }

  // ─── 文件变更监听 ────────────────────────────

  private setupFileWatcher(): void {
    this.service.onFileChange((event: FileChangeEvent) => {
      if (event.nodeId === this.noteId && event.type === 'modify') {
        this.saveError = '文件已被外部修改，请刷新';
        this.notifyError('文件已被外部修改，请刷新');
      }
    });
  }
}
