// services/ISyncService.ets
// 同步服务 — 管理数据同步状态，支持本地持久化

import { SyncStatus } from './ApiTypes';
import { FileService } from '../utils/FileService';

export interface ISyncService {
  checkConnection(): Promise<boolean>;
  sync(): Promise<SyncStatus>;
  getStatus(): Promise<SyncStatus>;
  configure(remoteUrl: string, token: string, interval?: number): Promise<void>;
  resolveConflict(noteId: string, strategy: 'local' | 'remote' | 'merge'): Promise<void>;
  onStatusChange(callback: (status: SyncStatus) => void): void;
}

export class SyncService implements ISyncService {
  private static readonly STATE_FILE = 'sync_status.json';
  private status: SyncStatus = {
    isSyncing: false,
    lastSyncTime: 0,
    pendingChanges: 0,
    conflictCount: 0,
    remoteUrl: ''
  };
  private changeCallbacks: Array<(status: SyncStatus) => void> = [];
  private fileService: FileService = FileService.getInstance();
  private initialized: boolean = false;

  private async init(): Promise<void> {
    if (this.initialized) return;
    try {
      const baseDir = this.fileService.getBaseDirectory();
      const path = `${baseDir}/${SyncService.STATE_FILE}`;
      const exists = await this.fileService.fileExists(path);
      if (exists) {
        const raw = await this.fileService.readFile(path);
        if (raw) {
          const saved = JSON.parse(raw) as SyncStatus;
          if (saved.isSyncing !== undefined) this.status.isSyncing = saved.isSyncing;
          if (saved.lastSyncTime) this.status.lastSyncTime = saved.lastSyncTime;
          if (saved.pendingChanges !== undefined) this.status.pendingChanges = saved.pendingChanges;
          if (saved.conflictCount !== undefined) this.status.conflictCount = saved.conflictCount;
          if (saved.remoteUrl) this.status.remoteUrl = saved.remoteUrl;
        }
      }
    } catch (e) {
      console.error('SyncService init error: ' + JSON.stringify(e));
    }
    this.initialized = true;
  }

  private async saveState(): Promise<void> {
    try {
      const baseDir = this.fileService.getBaseDirectory();
      const path = `${baseDir}/${SyncService.STATE_FILE}`;
      await this.fileService.writeFile(path, JSON.stringify(this.status));
    } catch (e) {
      console.error('SyncService saveState error: ' + JSON.stringify(e));
    }
  }

  async checkConnection(): Promise<boolean> {
    await this.init();
    return !!this.status.remoteUrl;
  }

  async sync(): Promise<SyncStatus> {
    await this.init();
    this.status.isSyncing = true;
    this.notifyChange();

    // 模拟异步同步操作
    await new Promise<void>((resolve: Function) => {
      setTimeout(() => { resolve(); }, 1500);
    });

    this.status.isSyncing = false;
    this.status.lastSyncTime = Date.now();
    this.status.pendingChanges = 0;
    await this.saveState();
    this.notifyChange();
    return this.status;
  }

  async getStatus(): Promise<SyncStatus> {
    await this.init();
    return this.status;
  }

  async configure(remoteUrl: string, token: string, interval?: number): Promise<void> {
    await this.init();
    this.status.remoteUrl = remoteUrl;
    await this.saveState();
  }

  async resolveConflict(noteId: string, strategy: 'local' | 'remote' | 'merge'): Promise<void> {
    this.status.conflictCount = Math.max(0, this.status.conflictCount - 1);
    await this.saveState();
  }

  onStatusChange(callback: (status: SyncStatus) => void): void {
    this.changeCallbacks.push(callback);
  }

  private notifyChange(): void {
    for (const cb of this.changeCallbacks) {
      cb(this.status);
    }
  }
}

// 单例导出
export const syncService: ISyncService = new SyncService();
