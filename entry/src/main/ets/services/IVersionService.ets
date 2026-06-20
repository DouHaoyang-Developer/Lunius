// services/IVersionService.ets
// 版本控制接口定义 — 本地版本快照管理

import { VersionEntry, VersionDetail, VersionCompareResult, VersionStats } from './ApiTypes';

export interface IVersionService {
  /** 初始化版本服务（加载索引） */
  init(): Promise<void>;

  /** 创建版本快照（在 saveNote 时自动调用） */
  createVersion(noteId: string, content: string): Promise<VersionEntry>;

  /** 获取版本列表 */
  listVersions(noteId: string, limit?: number, offset?: number): Promise<VersionEntry[]>;

  /** 获取版本详情（含完整内容） */
  getVersion(noteId: string, versionId: string): Promise<VersionDetail>;

  /** 恢复到指定版本（创建新版本，内容为旧版本内容） */
  restoreVersion(noteId: string, versionId: string): Promise<VersionEntry>;

  /** 对比两个版本 */
  compareVersions(
    noteId: string, oldVersionId: string, newVersionId: string
  ): Promise<VersionCompareResult>;

  /** 清理旧版本（保留策略：最近 N 个 + 手动检查点） */
  cleanupVersions(noteId: string, keepRecent: number): Promise<number>;

  /** 获取版本统计 */
  getVersionStats(): Promise<VersionStats>;

  /** 添加手动检查点标记 */
  markCheckpoint(noteId: string, versionId: string, message?: string): Promise<void>;
}