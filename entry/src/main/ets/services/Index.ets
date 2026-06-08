// services/Index.ets
// 统一服务导出 — 应用启动时可通过此入口预热所有服务

import { fileService } from './IFileService';
import { graphService } from './IGraphService';
import { syncService } from './ISyncService';
import { vaultIndex } from './VaultIndex';
import { pluginManager } from './PluginManager';
import { createPluginAPI } from './PluginAPI';
import { bookmarkPlugin } from '../plugins/BookmarkPlugin';

export { fileService } from './IFileService';
export { graphService } from './IGraphService';
export { syncService } from './ISyncService';
export { vaultIndex } from './VaultIndex';
export { pluginManager, createPluginAPI } from './PluginAPI';
export type { LuniusPlugin } from '../models/PluginTypes';
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
  await fileService.getFileTree();
  await graphService.getGraphData();
  await vaultIndex.ensureBuilt(true);
  await syncService.getStatus();
  console.info('All Lunius services initialized.');
}

export function initAllPlugins(basePath: string): void {
  // 设置 PluginManager 路径
  pluginManager.setBasePath(basePath);

  // 创建 PluginAPI 并注入
  const api = createPluginAPI();
  pluginManager.setAPI(api);

  // 注册内置插件
  pluginManager.register(bookmarkPlugin);

  // 恢复启用状态
  pluginManager.restore();

  console.info('Plugin system initialized.');
}
