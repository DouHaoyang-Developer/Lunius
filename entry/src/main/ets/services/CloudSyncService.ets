// services/CloudSyncService.ets
// 云同步实现 — 基于 Drive Kit REST API 的华为云空间文件同步
// 支持上传/下载/版本历史/增量同步/冲突解决

import { http } from '@kit.NetworkKit';
import { FileService } from '../utils/FileService';
import { ICloudSyncService } from './ICloudSyncService';
import {
  CloudNoteMapping, CloudSyncStatus, CloudSyncResult, CloudHistoryVersion
} from './ApiTypes';

const DRIVE_API_BASE = 'https://driveapis.cloud.huawei.com.cn/drive/v1';

interface DriveFile {
  id: string;
  name: string;
  mimeType: string;
  size: string;
  createdTime: string;
  modifiedTime: string;
  md5Checksum?: string;
}

interface DriveFileList {
  files: DriveFile[];
  nextPageToken?: string;
}

interface DriveAbout {
  quotaBytesUsed: number;
  quotaBytesTotal: number;
  needUpdate: boolean;
}

interface DriveHistoryVersionList {
  items: CloudHistoryVersion[];
  nextCursor?: string;
}

export class CloudSyncService implements ICloudSyncService {
  private static instance: CloudSyncService;
  private fileService: FileService;
  private accessToken: string = '';
  private refreshToken: string = '';
  private mappingStore: Map<string, CloudNoteMapping> = new Map();
  private lastSyncTime: number = 0;
  private isSyncing: boolean = false;

  private static readonly MAPPING_FILE = '.lunius/cloud_mapping.json';
  private static readonly SYNC_INTERVAL_MS = 5 * 60 * 1000; // 5分钟

  private constructor() {
    this.fileService = FileService.getInstance();
  }

  static getInstance(): CloudSyncService {
    if (!CloudSyncService.instance) {
      CloudSyncService.instance = new CloudSyncService();
    }
    return CloudSyncService.instance;
  }

  async init(): Promise<void> {
    const mappingPath = this.getMappingPath();
    const content = await this.fileService.readFile(mappingPath);
    if (content && content.length > 0) {
      try {
        const data = JSON.parse(content) as Record<string, CloudNoteMapping>;
        this.mappingStore = new Map(Object.entries(data));
      } catch (e) {
        console.error('CloudSyncService: failed to parse mapping, resetting');
        this.mappingStore = new Map();
      }
    }
    console.info(`CloudSyncService initialized: ${this.mappingStore.size} mappings`);
  }

  // ─── 认证 ──────────────────────────────────

  async authorize(): Promise<boolean> {
    try {
      const authCode = await this.getAuthCode();
      if (!authCode) {
        return false;
      }

      const tokenResult = await this.exchangeToken(authCode);
      if (!tokenResult) {
        return false;
      }

      this.accessToken = tokenResult.access_token;
      this.refreshToken = tokenResult.refresh_token ?? '';
      return true;
    } catch (e) {
      console.error('CloudSyncService authorize failed:', JSON.stringify(e));
      return false;
    }
  }

  isAuthorized(): boolean {
    return this.accessToken.length > 0;
  }

  async logout(): Promise<void> {
    this.accessToken = '';
    this.refreshToken = '';
    this.mappingStore.clear();
    await this.persistMappings();
  }

  async getQuotaInfo(): Promise<{ used: number; total: number }> {
    try {
      const about = await this.request('GET', '/about?fields=*') as DriveAbout;
      return { used: about.quotaBytesUsed, total: about.quotaBytesTotal };
    } catch {
      return { used: 0, total: 0 };
    }
  }

  // ─── 上传 ──────────────────────────────────

  async uploadNote(noteId: string, content: string): Promise<CloudNoteMapping> {
    const existingMapping = this.mappingStore.get(noteId);
    const contentHash = await this.computeHash(content);

    // 内容未变化，跳过上传
    if (existingMapping && existingMapping.localHash === contentHash) {
      return existingMapping;
    }

    if (existingMapping) {
      return this.updateCloudFile(existingMapping.cloudFileId, noteId, content, contentHash);
    } else {
      return this.createCloudFile(noteId, content, contentHash);
    }
  }

  private async createCloudFile(
    noteId: string, content: string, hash: string
  ): Promise<CloudNoteMapping> {
    const fileName = `${noteId}.md`;
    const metadata = {
      name: fileName,
      mimeType: 'text/markdown',
      parents: ['appDataFolder']
    };

    // 创建文件元数据
    const createResp = await this.request('POST', '/files', metadata) as DriveFile;

    // 上传文件内容
    await this.uploadContent(createResp.id, content);

    const mapping: CloudNoteMapping = {
      localPath: noteId,
      cloudFileId: createResp.id,
      cloudVersionId: createResp.id,
      localHash: hash,
      lastSyncedAt: Date.now()
    };

    this.mappingStore.set(noteId, mapping);
    await this.persistMappings();
    return mapping;
  }

  private async updateCloudFile(
    fileId: string, noteId: string, content: string, hash: string
  ): Promise<CloudNoteMapping> {
    await this.uploadContent(fileId, content);

    const mapping: CloudNoteMapping = {
      localPath: noteId,
      cloudFileId: fileId,
      cloudVersionId: fileId,
      localHash: hash,
      lastSyncedAt: Date.now()
    };

    this.mappingStore.set(noteId, mapping);
    await this.persistMappings();
    return mapping;
  }

  private async uploadContent(fileId: string, content: string): Promise<void> {
    await this.request(
      'PATCH',
      `/files/${fileId}?uploadType=media`,
      content,
      'text/markdown'
    );
  }

  // ─── 下载 ──────────────────────────────────

  async downloadNote(noteId: string): Promise<string> {
    const mapping = this.mappingStore.get(noteId);
    if (!mapping) {
      throw new Error(`No cloud mapping for note: ${noteId}`);
    }
    const content = await this.request(
      'GET',
      `/files/${mapping.cloudFileId}?form=media`,
      undefined,
      undefined,
      'text/plain'
    ) as string;
    return content;
  }

  // ─── 云端版本历史 ──────────────────────────

  async listCloudVersions(cloudFileId: string): Promise<CloudHistoryVersion[]> {
    const resp = await this.request(
      'GET',
      `/files/${cloudFileId}/historyVersions?fields=*`
    ) as DriveHistoryVersionList;
    return resp.items ?? [];
  }

  async getCloudVersion(cloudFileId: string, versionId: string): Promise<string> {
    return await this.request(
      'GET',
      `/files/${cloudFileId}/historyVersions/${versionId}?form=media`,
      undefined,
      undefined,
      'text/plain'
    ) as string;
  }

  async restoreCloudVersion(cloudFileId: string, versionId: string): Promise<void> {
    const content = await this.getCloudVersion(cloudFileId, versionId);
    await this.uploadContent(cloudFileId, content);
  }

  // ─── 同步 ──────────────────────────────────

  async syncAll(): Promise<CloudSyncResult> {
    if (this.isSyncing || !this.isAuthorized()) {
      return { uploaded: 0, downloaded: 0, conflicts: 0 };
    }

    this.isSyncing = true;
    let uploaded = 0;
    let downloaded = 0;
    let conflicts = 0;

    try {
      // 1. 列出云端所有应用文件
      const cloudFiles = await this.listCloudFiles();

      // 2. 上传本地变更
      for (const [noteId, mapping] of this.mappingStore) {
        try {
          const localContent = await this.fileService.readFile(
            `${this.fileService.getBaseDirectory()}/${noteId}.md`
          );
          if (localContent) {
            const hash = await this.computeHash(localContent);
            if (hash !== mapping.localHash) {
              await this.uploadNote(noteId, localContent);
              uploaded++;
            }
          }
        } catch (e) {
          // 本地文件可能已被删除
        }
      }

      // 3. 下载云端变更
      for (const cloudFile of cloudFiles) {
        const noteId = cloudFile.name.replace(/\.md$/, '');
        const existingMapping = this.mappingStore.get(noteId);

        if (!existingMapping) {
          // 新文件：下载并创建本地文件
          const content = await this.request(
            'GET',
            `/files/${cloudFile.id}?form=media`,
            undefined,
            undefined,
            'text/plain'
          ) as string;
          const localPath = `${this.fileService.getBaseDirectory()}/${cloudFile.name}`;
          await this.fileService.writeFile(localPath, content);
          // 创建映射
          const hash = await this.computeHash(content);
          this.mappingStore.set(noteId, {
            localPath: noteId,
            cloudFileId: cloudFile.id,
            cloudVersionId: cloudFile.id,
            localHash: hash,
            lastSyncedAt: Date.now()
          });
          downloaded++;
        } else if (existingMapping.cloudVersionId !== cloudFile.id) {
          // 云端有更新：检查本地是否也有变更
          const localContent = await this.fileService.readFile(
            `${this.fileService.getBaseDirectory()}/${cloudFile.name}`
          );
          const localHash = await this.computeHash(localContent);

          if (localHash !== existingMapping.localHash) {
            // 冲突：本地和云端都有变更
            conflicts++;
            await this.resolveConflict(noteId, cloudFile.id);
          } else {
            // 仅云端有变更：直接下载
            const content = await this.downloadNote(noteId);
            const localPath = `${this.fileService.getBaseDirectory()}/${cloudFile.name}`;
            await this.fileService.writeFile(localPath, content);
            downloaded++;
          }
        }
      }
    } catch (e) {
      console.error('CloudSyncService syncAll error:', JSON.stringify(e));
    }

    this.lastSyncTime = Date.now();
    this.isSyncing = false;
    await this.persistMappings();
    return { uploaded, downloaded, conflicts };
  }

  private async resolveConflict(noteId: string, cloudFileId: string): Promise<void> {
    const localPath = `${this.fileService.getBaseDirectory()}/${noteId}.md`;
    const localContent = await this.fileService.readFile(localPath);
    const cloudContent = await this.request(
      'GET',
      `/files/${cloudFileId}?form=media`,
      undefined,
      undefined,
      'text/plain'
    ) as string;

    // 合并冲突标记
    const mergedContent =
      `<<<<<<<< 本地版本 (${new Date().toISOString()})\n` +
      `${localContent}\n` +
      `========\n` +
      `${cloudContent}\n` +
      `>>>>>>>> 云端版本\n`;

    // 保存合并结果并上传
    await this.fileService.writeFile(localPath, mergedContent);
    await this.uploadNote(noteId, mergedContent);
  }

  private async listCloudFiles(): Promise<DriveFile[]> {
    const resp = await this.request(
      'GET',
      '/files?q=appDataFolder&fields=files(id,name,mimeType,modifiedTime)'
    ) as DriveFileList;
    return resp.files ?? [];
  }

  // ─── 状态 ──────────────────────────────────

  async getStatus(): Promise<CloudSyncStatus> {
    let quotaUsed = 0;
    let quotaTotal = 0;
    let cloudFileCount = 0;

    if (this.isAuthorized()) {
      try {
        const about = await this.request('GET', '/about?fields=*') as DriveAbout;
        quotaUsed = about.quotaBytesUsed;
        quotaTotal = about.quotaBytesTotal;

        const files = await this.listCloudFiles();
        cloudFileCount = files.length;
      } catch (e) {
        // 离线时返回缓存状态
      }
    }

    return {
      isSyncing: this.isSyncing,
      lastSyncTime: this.lastSyncTime,
      pendingUploads: 0,
      pendingDownloads: 0,
      cloudFileCount,
      quotaUsed,
      quotaTotal
    };
  }

  getMapping(noteId: string): Promise<CloudNoteMapping | null> {
    return Promise.resolve(this.mappingStore.get(noteId) ?? null);
  }

  // ─── 私有方法 ──────────────────────────────

  private getMappingPath(): string {
    return `${this.fileService.getBaseDirectory()}/${CloudSyncService.MAPPING_FILE}`;
  }

  private async persistMappings(): Promise<void> {
    const data: Record<string, CloudNoteMapping> = {};
    this.mappingStore.forEach((v: CloudNoteMapping, k: string) => {
      data[k] = v;
    });
    await this.fileService.writeFile(this.getMappingPath(), JSON.stringify(data));
  }

  private async computeHash(content: string): Promise<string> {
    // 简单哈希（生产环境应使用 @kit.CryptoArchitectureKit 的 SHA256）
    let hash = 0;
    for (let i = 0; i < content.length; i++) {
      const char = content.charCodeAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash; // 32-bit
    }
    return `lunius_${Math.abs(hash).toString(16)}`;
  }

  private async getAuthCode(): Promise<string | null> {
    // 使用 @kit.AccountKit 获取华为帐号授权码
    // scope: https://www.huawei.com/auth/drive.appdata
    // 实际集成时需实现 AccountKit 的 authorization 流程
    return null;
  }

  private async exchangeToken(code: string): Promise<{
    access_token: string; refresh_token?: string
  } | null> {
    try {
      const resp = await http.createHttp().request(
        'https://oauth-login.cloud.huawei.com/oauth2/v3/token',
        {
          method: http.RequestMethod.POST,
          header: { 'Content-Type': 'application/x-www-form-urlencoded' },
          extraData: `grant_type=authorization_code&code=${code}`
        }
      );
      return JSON.parse(resp.result as string);
    } catch (e) {
      console.error('CloudSyncService exchangeToken error:', JSON.stringify(e));
      return null;
    }
  }

  private async request(
    method: string,
    path: string,
    body?: object | string,
    contentType: string = 'application/json',
    acceptType: string = 'application/json'
  ): Promise<object | string> {
    const token = this.accessToken;
    const options: http.HttpRequestOptions = {
      method: method as http.RequestMethod,
      header: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': contentType,
        'Accept': acceptType
      }
    };

    if (body !== undefined) {
      options.extraData = typeof body === 'string' ? body : JSON.stringify(body);
    }

    const resp = await http.createHttp().request(`${DRIVE_API_BASE}${path}`, options);

    if (acceptType === 'text/plain') {
      return resp.result as string;
    }
    return JSON.parse(resp.result as string);
  }
}