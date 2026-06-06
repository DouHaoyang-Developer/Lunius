// services/Index.ets
// 统一服务导出 — 应用启动时可通过此入口预热所有服务

import { fileService } from './IFileService';
import { graphService } from './IGraphService';
import { syncService } from './ISyncService';
import { vaultIndex } from './VaultIndex';

export { fileService } from './IFileService';
export { graphService } from './IGraphService';
export { syncService } from './ISyncService';
export { vaultIndex } from './VaultIndex';
export { RealFileService } from './RealFileService';
export { RealGraphService } from './RealGraphService';
export { CollaborationService } from './CollaborationService';
export type { IFileService, SearchOptions, FileChangeEvent } from './IFileService';
export type { IGraphService } from './IGraphService';
export type { ISyncService } from './ISyncService';
export type { NoteMetadata, SearchResultItem, GraphData, GraphNodeData, GraphEdgeData, SyncStatus, VaultStats } from './ApiTypes';
export type {
  CollaboratorDevice,
  CollaborationSession,
  CollabOperation,
  RemoteCursorState,
  CollabOperationType,
  CollaborationSessionState
} from '../models/CollaborationTypes';

export async function initAllServices(): Promise<void> {
  console.info('Initializing Lunius services...');
  // 预热文件树
  await fileService.getFileTree();
  // 预热图谱索引
  await graphService.getGraphData();
  // 预热标签索引
  await vaultIndex.ensureBuilt(true);
  // 预热同步状态
  await syncService.getStatus();
  console.info('All Lunius services initialized.');
}
