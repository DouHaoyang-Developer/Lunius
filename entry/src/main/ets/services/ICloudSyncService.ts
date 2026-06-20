// services/ICloudSyncService.ts
// 云同步接口定义 — 基于 Drive Kit REST API

import { CloudNoteMapping, CloudSyncStatus, CloudSyncResult, CloudHistoryVersion } from './ApiTypes';

export interface ICloudSyncService {
  /** 初始化云同步服务（加载本地映射） */
  init(): Promise<void>;

  /** 授权华为帐号登录 */
  authorize(): Promise<boolean>;

  /** 检查是否已授权 */
  isAuthorized(): boolean;

  /** 获取用户配额信息 */
  getQuotaInfo(): Promise<{ used: number; total: number }>;

  /** 上传单个笔记到云端 */
  uploadNote(noteId: string, content: string): Promise<CloudNoteMapping>;

  /** 从云端下载单个笔记 */
  downloadNote(noteId: string): Promise<string>;

  /** 全量同步（上传本地变更 + 下载云端变更） */
  syncAll(): Promise<CloudSyncResult>;

  /** 获取云端文件的历史版本列表 */
  listCloudVersions(cloudFileId: string): Promise<CloudHistoryVersion[]>;

  /** 获取云端文件的历史版本内容 */
  getCloudVersion(cloudFileId: string, versionId: string): Promise<string>;

  /** 恢复云端文件到指定历史版本 */
  restoreCloudVersion(cloudFileId: string, versionId: string): Promise<void>;

  /** 获取同步状态 */
  getStatus(): Promise<CloudSyncStatus>;

  /** 获取笔记的云端映射 */
  getMapping(noteId: string): Promise<CloudNoteMapping | null>;

  /** 登出并清除授权 */
  logout(): Promise<void>;
}