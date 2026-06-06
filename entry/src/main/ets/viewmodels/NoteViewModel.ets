// viewmodels/NoteViewModel.ets
// 笔记详情 ViewModel - 连接 UI 与 Service 层
// 支持防抖自动保存、错误回调、文件变更监听、分布式协同编辑

import { fileService, IFileService, FileChangeEvent } from '../services/IFileService';
import { NoteMetadata } from '../services/ApiTypes';
import { CollaborationService } from '../services/CollaborationService';
import {
  CollabOperation,
  CollabOperationType,
  RemoteCursorState
} from '../models/CollaborationTypes';

@Observed
export class NoteViewModel {
  private service: IFileService;
  private collabService: CollaborationService | null = null;
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

  // 协同编辑状态
  isCollaborating: boolean = false;
  collaborationSessionId: string = '';
  remoteCursors: RemoteCursorState[] = [];
  remoteParticipants: string[] = [];

  // 错误回调（UI 层注册，用于 Toast 提示）
  onErrorCallback?: (message: string) => void;
  onSaveCallback?: (success: boolean) => void;
  // 协同状态回调
  onRemoteCursorsChanged?: (cursors: RemoteCursorState[]) => void;

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
      // 协同模式下同步完整快照
      if (this.isCollaborating && this.collabService) {
        this.collabService.saveContentSnapshot(this.content);
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

  // 内容变更时：标记脏数据 + 启动防抖保存 + 广播协同操作
  updateContent(newContent: string): void {
    const oldContent = this.content;
    this.content = newContent;
    this.hasUnsavedChanges = true;
    this.debouncedSave();

    // 协同模式：计算差异并广播
    if (this.isCollaborating && this.collabService) {
      this.broadcastContentChange(oldContent, newContent);
    }
  }

  // 插入文本到光标位置
  insertTextAtCursor(text: string, cursorPos: number): void {
    let newContent: string;
    if (cursorPos < 0) {
      newContent = this.content + text;
    } else {
      const before = this.content.substring(0, cursorPos);
      const after = this.content.substring(cursorPos);
      newContent = before + text + after;
    }
    this.updateContent(newContent);
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

  // ─── 协同编辑方法 ────────────────────────────

  // 设置协同服务实例（由 MainEntry 在初始化时注入）
  setCollaborationService(service: CollaborationService): void {
    this.collabService = service;
  }

  // 创建协同会话（作为主设备）
  async startCollaboration(): Promise<string> {
    if (!this.collabService) return '';

    const session = await this.collabService.createSession(
      this.noteId, this.title, this.content
    );
    this.isCollaborating = true;
    this.collaborationSessionId = session.sessionId;
    this.setupCollaborationListeners();
    return session.sessionId;
  }

  // 加入已有协同会话
  async joinCollaboration(sessionId: string): Promise<void> {
    if (!this.collabService) return;

    const result = await this.collabService.joinSession(sessionId);
    // 以远程内容为基准（简化合并策略）
    this.content = result.content;
    this.hasUnsavedChanges = true;
    this.isCollaborating = true;
    this.collaborationSessionId = result.sessionId;
    this.remoteParticipants = result.participants
      .map((d) => d.deviceName);

    this.setupCollaborationListeners();
    // 立即保存合并后的内容
    this.debouncedSave();
  }

  // 退出协同会话
  async leaveCollaboration(): Promise<void> {
    if (!this.collabService) return;

    this.teardownCollaborationListeners();
    await this.collabService.leaveSession();
    this.isCollaborating = false;
    this.collaborationSessionId = '';
    this.remoteCursors = [];
    this.remoteParticipants = [];
  }

  // 更新光标到协同服务
  updateCollaborationCursor(position: number, selStart: number, selEnd: number): void {
    if (this.isCollaborating && this.collabService) {
      this.collabService.updateCursor(position, selStart, selEnd);
    }
  }

  // ─── 私有协同方法 ────────────────────────────

  private setupCollaborationListeners(): void {
    if (!this.collabService) return;

    this.collabService.onRemoteOperation((op: CollabOperation) => {
      this.applyRemoteOperation(op);
    });

    this.collabService.onRemoteCursorsChanged((cursors: RemoteCursorState[]) => {
      this.remoteCursors = cursors;
      if (this.onRemoteCursorsChanged) {
        this.onRemoteCursorsChanged(cursors);
      }
    });

    this.collabService.onSessionClosed(() => {
      this.isCollaborating = false;
      this.collaborationSessionId = '';
      this.remoteCursors = [];
      this.notifyError('协同会话已结束');
    });
  }

  private teardownCollaborationListeners(): void {
    if (!this.collabService) return;
    this.collabService.onRemoteOperation(() => {});
    this.collabService.onRemoteCursorsChanged(() => {});
    this.collabService.onSessionClosed(() => {});
  }

  // 计算差异并广播
  private broadcastContentChange(oldContent: string, newContent: string): void {
    if (!this.collabService) return;

    // 找到第一个不同的字符位置
    let pos = 0;
    while (pos < oldContent.length && pos < newContent.length &&
           oldContent[pos] === newContent[pos]) {
      pos++;
    }

    if (newContent.length > oldContent.length) {
      // 插入操作
      const inserted = newContent.substring(pos, pos + (newContent.length - oldContent.length));
      this.collabService.applyLocalChange(
        CollabOperationType.INSERT, pos, inserted
      );
    } else if (newContent.length < oldContent.length) {
      // 删除操作
      this.collabService.applyLocalChange(
        CollabOperationType.DELETE, pos, undefined,
        oldContent.length - newContent.length
      );
    } else if (oldContent !== newContent) {
      // 替换操作
      this.collabService.applyLocalChange(
        CollabOperationType.REPLACE, pos,
        newContent.substring(pos, this.findReplaceEnd(oldContent, newContent, pos))
      );
    }
  }

  private findReplaceEnd(oldContent: string, newContent: string, start: number): number {
    let end = start;
    while (end < newContent.length && end < oldContent.length &&
           newContent[end] !== oldContent[end]) {
      end++;
    }
    return end;
  }

  // 应用远端操作到本地内容
  private applyRemoteOperation(op: CollabOperation): void {
    switch (op.type) {
      case CollabOperationType.INSERT:
        if (op.text && op.position <= this.content.length) {
          this.content =
            this.content.substring(0, op.position) +
            op.text +
            this.content.substring(op.position);
          this.hasUnsavedChanges = true;
        }
        break;
      case CollabOperationType.DELETE:
        if (op.length && op.position + op.length <= this.content.length) {
          this.content =
            this.content.substring(0, op.position) +
            this.content.substring(op.position + op.length);
          this.hasUnsavedChanges = true;
        }
        break;
      case CollabOperationType.REPLACE:
        // 简化处理：删除后插入
        if (op.text) {
          this.content =
            this.content.substring(0, op.position) +
            op.text +
            this.content.substring(op.position + (op.length ?? op.text.length));
          this.hasUnsavedChanges = true;
        }
        break;
    }
    // 远端变更触发防抖保存
    this.debouncedSave();
  }

  // ─── 保存策略 ────────────────────────────────

  private debouncedSave(): void {
    if (this.saveTimer !== -1) {
      clearTimeout(this.saveTimer);
    }
    this.saveTimer = setTimeout(() => {
      this.saveTimer = -1;
      this.saveNote();
    }, NoteViewModel.SAVE_DEBOUNCE_MS);
  }

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
    if (this.isCollaborating) {
      this.leaveCollaboration();
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
