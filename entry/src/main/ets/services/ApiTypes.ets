// services/ApiTypes.ets
// 前后端交互的数据接口定义

// Frontmatter 值类型
export type FrontmatterValue = string | number | boolean | string[];

export interface NoteReadResult {
  content: string;
  metadata: NoteMetadata;
}

export interface NoteMetadata {
  id: string;
  title: string;
  path: string;
  createdAt: number;
  updatedAt: number;
  tags: string[];
  aliases: string[];
  wordCount: number;
  charCount: number;
  links: string[];
  backlinks: string[];
  attachments: string[];
  frontmatter: Map<string, FrontmatterValue>;
}

export interface VaultStats {
  totalNotes: number;
  totalWords: number;
  totalLinks: number;
  totalTags: number;
  oldestNote: number;
  latestNote: number;
}

export interface SearchMatch {
  line: number;
  text: string;
  start: number;
  end: number;
}

export interface SearchResultItem {
  noteId: string;
  title: string;
  path: string;
  matches: SearchMatch[];
  score: number;
}

export interface GraphNodeData {
  id: string;
  label: string;
  x: number;
  y: number;
  radius: number;
  color: string;
  group: string;
}

export interface GraphEdgeData {
  source: string;
  target: string;
  strength: number;
}

export interface GraphData {
  nodes: GraphNodeData[];
  edges: GraphEdgeData[];
}

export interface LinkStats {
  outgoing: number;
  incoming: number;
  missing: number;
}

export interface SyncStatus {
  isSyncing: boolean;
  lastSyncTime: number;
  pendingChanges: number;
  conflictCount: number;
  remoteUrl: string;
}

export interface PluginManifest {
  id: string;
  name: string;
  version: string;
  description: string;
  author: string;
  isEnabled: boolean;
}

// ─── Properties 增强类型 ──────────────────

export enum PropertyType {
  TEXT = 'text',
  NUMBER = 'number',
  CHECKBOX = 'checkbox',
  DATE = 'date',
  TAGS = 'tags',
  LIST = 'list'
}

export interface PropertySchema {
  key: string;
  type: PropertyType;
  label: string;
  default?: FrontmatterValue;
  options?: string[];
  required: boolean;
}

export interface PropertyUsage {
  key: string;
  type: PropertyType;
  count: number;
  values: FrontmatterValue[];
}
