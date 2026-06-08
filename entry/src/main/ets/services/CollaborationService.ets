// services/CollaborationService.ets
// 分布式协同服务 — 封装 DistributedKVStore 实现跨设备实时协同编辑

import { distributedKVStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  CollaborationSession,
  CollaborationSessionState,
  CollabOperation,
  CollabOperationType,
  CollaboratorDevice,
  RemoteCursorState,
  DEVICE_CURSOR_COLORS,
  KV_KEY_PREFIX
} from '../models/CollaborationTypes';

const TAG = 'CollaborationService';
const STORE_ID = 'lunius_collab_store';

// joinSession 返回类型
export interface JoinSessionResult {
  sessionId: string;
  noteId: string;
  noteTitle: string;
  hostDeviceId: string;
  participants: CollaboratorDevice[];
  state: CollaborationSessionState;
  createdAt: number;
  lastActivityAt: number;
  content: string;
}

export class CollaborationService {
  private static uiAbilityContext: common.UIAbilityContext | null = null;

  static setContext(context: common.UIAbilityContext): void {
    CollaborationService.uiAbilityContext = context;
  }

  private kvManager: distributedKVStore.KVManager | null = null;
  private kvStore: distributedKVStore.SingleKVStore | null = null;
  private session: CollaborationSession | null = null;
  private deviceId: string;
  private deviceName: string;
  private deviceType: string;
  private seqNumber: number = 0;
  private colorIndex: number = 0;

  private onRemoteOpCallback?: (op: CollabOperation) => void;
  private onRemoteCursorCallback?: (cursors: RemoteCursorState[]) => void;
  private onParticipantsChangedCallback?: (participants: CollaboratorDevice[]) => void;
  private onSessionClosedCallback?: () => void;

  constructor(deviceId: string, deviceName: string, deviceType: string) {
    this.deviceId = deviceId;
    this.deviceName = deviceName;
    this.deviceType = deviceType;
  }

  // ─── KVStore 安全操作封装 ──────────────────

  private async kvPut(key: string, value: string): Promise<void> {
    if (!this.kvStore) return;
    try {
      await this.kvStore.put(key, value);
    } catch (err) {
      hilog.error(0x0000, TAG, 'kvPut failed, key=%{public}s: %{public}s', key, JSON.stringify(err));
    }
  }

  private async kvDelete(key: string): Promise<void> {
    if (!this.kvStore) return;
    try {
      await this.kvStore.delete(key);
    } catch (err) {
      hilog.error(0x0000, TAG, 'kvDelete failed, key=%{public}s: %{public}s', key, JSON.stringify(err));
    }
  }

  private async kvGet(key: string): Promise<string> {
    if (!this.kvStore) return '';
    try {
      const rawValue = await this.kvStore.get(key);
      return typeof rawValue === 'string' ? rawValue : '';
    } catch (err) {
      hilog.error(0x0000, TAG, 'kvGet failed, key=%{public}s: %{public}s', key, JSON.stringify(err));
      return '';
    }
  }

  // ─── 公开方法 ──────────────────────────────

  async init(): Promise<void> {
    const ctx = CollaborationService.uiAbilityContext;
    if (!ctx) {
      hilog.error(0x0000, TAG, 'Context not set. Call CollaborationService.setContext() in EntryAbility first.');
      return;
    }
    try {
      this.kvManager = distributedKVStore.createKVManager({
        context: ctx,
        bundleName: ctx.applicationInfo.name
      });

      this.kvStore = await this.kvManager.getKVStore(STORE_ID, {
        createIfMissing: true,
        encrypt: false,
        backup: true,
        autoSync: true,
        kvStoreType: distributedKVStore.KVStoreType.SINGLE_VERSION,
        securityLevel: distributedKVStore.SecurityLevel.S1
      });

      const store = this.kvStore;
      if (store) {
        store.on('dataChange',
          distributedKVStore.SubscribeType.SUBSCRIBE_TYPE_ALL,
          (data: distributedKVStore.ChangeNotification) => {
            this.handleDataChange(data);
          }
        );
      }

      hilog.info(0x0000, TAG, 'CollaborationService initialized, deviceId: %{public}s', this.deviceId);
    } catch (err) {
      hilog.error(0x0000, TAG, 'Init failed: %{public}s', JSON.stringify(err));
    }
  }

  async createSession(noteId: string, noteTitle: string, content: string): Promise<CollaborationSession> {
    const sessionId = `session-${noteId}-${Date.now()}`;

    const hostDevice: CollaboratorDevice = {
      deviceId: this.deviceId,
      deviceName: this.deviceName,
      deviceType: this.deviceType,
      isHost: true,
      isOnline: true,
      joinedAt: Date.now()
    };

    this.session = {
      sessionId: sessionId,
      noteId: noteId,
      noteTitle: noteTitle,
      hostDeviceId: this.deviceId,
      participants: [hostDevice],
      state: CollaborationSessionState.HOSTING,
      createdAt: Date.now(),
      lastActivityAt: Date.now()
    };

    await this.kvPut(`${KV_KEY_PREFIX.SESSION_META}${sessionId}`, JSON.stringify(this.session));
    await this.kvPut(`${KV_KEY_PREFIX.SESSION_CONTENT}${sessionId}`, content);

    hilog.info(0x0000, TAG, 'Session created: %{public}s for note %{public}s', sessionId, noteId);
    return this.session;
  }

  async joinSession(sessionId: string): Promise<JoinSessionResult> {
    const rawValue = await this.kvGet(`${KV_KEY_PREFIX.SESSION_META}${sessionId}`);
    const metaStr = typeof rawValue === 'string' ? rawValue : '';
    if (!metaStr) {
      throw new Error('Session not found: ' + sessionId);
    }

    const meta = JSON.parse(metaStr) as CollaborationSession;
    const existingIds: string[] = [];
    for (let i = 0; i < meta.participants.length; i++) {
      existingIds.push(meta.participants[i].deviceId);
    }
    if (!existingIds.includes(this.deviceId)) {
      this.colorIndex = existingIds.length % DEVICE_CURSOR_COLORS.length;
      const newParticipant: CollaboratorDevice = {
        deviceId: this.deviceId,
        deviceName: this.deviceName,
        deviceType: this.deviceType,
        isHost: false,
        isOnline: true,
        joinedAt: Date.now()
      };
      meta.participants.push(newParticipant);
      meta.state = CollaborationSessionState.CONNECTED;
      await this.kvPut(`${KV_KEY_PREFIX.SESSION_META}${sessionId}`, JSON.stringify(meta));
    }

    this.session = meta;

    const rawContent = await this.kvGet(`${KV_KEY_PREFIX.SESSION_CONTENT}${sessionId}`);
    const content = typeof rawContent === 'string' ? rawContent : '';

    hilog.info(0x0000, TAG, 'Joined session: %{public}s', sessionId);

    const result: JoinSessionResult = {
      sessionId: meta.sessionId,
      noteId: meta.noteId,
      noteTitle: meta.noteTitle,
      hostDeviceId: meta.hostDeviceId,
      participants: meta.participants,
      state: meta.state,
      createdAt: meta.createdAt,
      lastActivityAt: meta.lastActivityAt,
      content: content
    };
    return result;
  }

  async leaveSession(): Promise<void> {
    if (!this.session) return;

    await this.removeCursor();

    // 手动拷贝 session 属性（ArkTS 不支持对象展开）
    const sessionId = this.session.sessionId;
    const updatedParticipants: CollaboratorDevice[] = [];
    for (let i = 0; i < this.session.participants.length; i++) {
      const d = this.session.participants[i];
      if (d.deviceId !== this.deviceId) {
        updatedParticipants.push(d);
      }
    }

    if (updatedParticipants.length === 0) {
      await this.destroySession(sessionId);
    } else {
      // 构建更新后的 meta
      const updatedMeta: CollaborationSession = {
        sessionId: this.session.sessionId,
        noteId: this.session.noteId,
        noteTitle: this.session.noteTitle,
        hostDeviceId: this.session.hostDeviceId,
        participants: updatedParticipants,
        state: this.session.state,
        createdAt: this.session.createdAt,
        lastActivityAt: this.session.lastActivityAt
      };
      this.session = updatedMeta;
      await this.kvPut(`${KV_KEY_PREFIX.SESSION_META}${sessionId}`, JSON.stringify(updatedMeta));
    }

    this.session = null;
    this.seqNumber = 0;
  }

  // 销毁协同会话
  async destroySession(sessionId: string): Promise<void> {
    if (!this.kvStore) return;
    // 删除所有与会话相关的 key（meta / content / 操作序列 / 光标序列）
    await this.kvDelete(`${KV_KEY_PREFIX.SESSION_META}${sessionId}`);
    await this.kvDelete(`${KV_KEY_PREFIX.SESSION_CONTENT}${sessionId}`);
    // 删除操作序列（按 seqNumber 范围清理）
    for (let i = 0; i <= this.seqNumber; i++) {
      await this.kvDelete(`${KV_KEY_PREFIX.SESSION_OPS}${sessionId}:${i}`);
    }
    // 删除光标条目
    const parts = this.session?.participants ?? [];
    for (let i = 0; i < parts.length; i++) {
      await this.kvDelete(`${KV_KEY_PREFIX.SESSION_CURSOR}${sessionId}:${parts[i].deviceId}`);
    }
  }

  async applyLocalChange(type: CollabOperationType, position: number, text?: string, length?: number): Promise<void> {
    if (!this.session) return;

    const op: CollabOperation = {
      type: type,
      position: position,
      text: text,
      length: length,
      timestamp: Date.now(),
      deviceId: this.deviceId,
      seqNumber: this.seqNumber++
    };

    const key = `${KV_KEY_PREFIX.SESSION_OPS}${this.session.sessionId}:${op.seqNumber}`;
    await this.kvPut(key, JSON.stringify(op));

    // 更新最后活动时间
    this.session.lastActivityAt = Date.now();
    await this.kvPut(
      `${KV_KEY_PREFIX.SESSION_META}${this.session.sessionId}`,
      JSON.stringify(this.session)
    );
  }

  async saveContentSnapshot(content: string): Promise<void> {
    if (!this.session) return;
    await this.kvPut(`${KV_KEY_PREFIX.SESSION_CONTENT}${this.session.sessionId}`, content);
  }

  async updateCursor(position: number, selectionStart: number, selectionEnd: number): Promise<void> {
    if (!this.session) return;

    const cursorState: RemoteCursorState = {
      deviceId: this.deviceId,
      deviceName: this.deviceName,
      position: position,
      selectionStart: selectionStart,
      selectionEnd: selectionEnd,
      color: DEVICE_CURSOR_COLORS[this.colorIndex % DEVICE_CURSOR_COLORS.length],
      timestamp: Date.now()
    };

    await this.kvPut(
      `${KV_KEY_PREFIX.SESSION_CURSOR}${this.session.sessionId}:${this.deviceId}`,
      JSON.stringify(cursorState)
    );
  }

  private async removeCursor(): Promise<void> {
    if (!this.session) return;
    await this.kvDelete(
      `${KV_KEY_PREFIX.SESSION_CURSOR}${this.session.sessionId}:${this.deviceId}`
    );
  }

  getParticipants(): CollaboratorDevice[] {
    return this.session?.participants ?? [];
  }

  getCurrentSession(): CollaborationSession | null {
    return this.session;
  }

  isInSession(): boolean {
    return this.session !== null;
  }

  async discoverSessions(noteId: string): Promise<CollaborationSession[]> {
    const sessions: CollaborationSession[] = [];
    if (!this.kvStore) return sessions;

    const prefix = `${KV_KEY_PREFIX.SESSION_META}session-${noteId}`;
    // 尝试通过已知的 key 范围查找
    const maxAttempts = 50;
    for (let attempt = 0; attempt < maxAttempts; attempt++) {
      // 按时间戳范围尝试读取已知 key（简化实现）
      const rawValue = await this.kvGet(`${prefix}-${attempt}`);
      if (!rawValue) continue;
      const metaStr = typeof rawValue === 'string' ? rawValue : '';
      if (!metaStr) continue;
      const session = JSON.parse(metaStr) as CollaborationSession;
      if (Date.now() - session.lastActivityAt < 30 * 60 * 1000) {
        sessions.push(session);
      }
    }
    return sessions;
  }

  onRemoteOperation(callback: (op: CollabOperation) => void): void {
    this.onRemoteOpCallback = callback;
  }

  onRemoteCursorsChanged(callback: (cursors: RemoteCursorState[]) => void): void {
    this.onRemoteCursorCallback = callback;
  }

  onParticipantsChanged(callback: (participants: CollaboratorDevice[]) => void): void {
    this.onParticipantsChangedCallback = callback;
  }

  onSessionClosed(callback: () => void): void {
    this.onSessionClosedCallback = callback;
  }

  private handleDataChange(data: distributedKVStore.ChangeNotification): void {
    if (!this.session) return;

    const ops: CollabOperation[] = [];
    const cursors: RemoteCursorState[] = [];
    let participantsChanged = false;

    const entries = data.updateEntries;
    for (let i = 0; i < entries.length; i++) {
      const entry = entries[i];
      const key: string = entry.key as string;

      if (key.startsWith(`${KV_KEY_PREFIX.SESSION_OPS}${this.session.sessionId}:`)) {
        const op = JSON.parse(entry.value.value as string) as CollabOperation;
        if (op.deviceId !== this.deviceId) {
          ops.push(op);
        }
      } else if (key.startsWith(`${KV_KEY_PREFIX.SESSION_CURSOR}${this.session.sessionId}:`)) {
        const cursor = JSON.parse(entry.value.value as string) as RemoteCursorState;
        if (cursor.deviceId !== this.deviceId) {
          cursors.push(cursor);
        }
      } else if (key === `${KV_KEY_PREFIX.SESSION_META}${this.session.sessionId}`) {
        const meta = JSON.parse(entry.value.value as string) as CollaborationSession;
        if (meta.participants.length === 0 && this.onSessionClosedCallback) {
          this.onSessionClosedCallback();
          return;
        }
        this.session = meta;
        participantsChanged = true;
      }
    }

    if (ops.length > 0 && this.onRemoteOpCallback) {
      ops.sort((a: CollabOperation, b: CollabOperation): number => a.seqNumber - b.seqNumber);
      for (let j = 0; j < ops.length; j++) {
        this.onRemoteOpCallback!(ops[j]);
      }
    }

    if (cursors.length > 0 && this.onRemoteCursorCallback) {
      this.onRemoteCursorCallback(cursors);
    }

    if (participantsChanged && this.onParticipantsChangedCallback) {
      this.onParticipantsChangedCallback(this.session!.participants);
    }
  }

  async destroy(): Promise<void> {
    if (this.session) {
      await this.leaveSession();
    }
    if (this.kvStore && this.kvManager) {
      try {
        this.kvStore.off('dataChange');
      } catch (err) {
        hilog.error(0x0000, TAG, 'off dataChange failed: %{public}s', JSON.stringify(err));
      }
      const ctx = CollaborationService.uiAbilityContext;
      const appId = ctx?.applicationInfo.name ?? '';
      try {
        await this.kvManager.closeKVStore(appId, STORE_ID);
        await this.kvManager.deleteKVStore(appId, STORE_ID);
      } catch (err) {
        hilog.error(0x0000, TAG, 'Destroy KVStore failed: %{public}s', JSON.stringify(err));
      }
    }
    this.kvStore = null;
    this.kvManager = null;
  }
}
