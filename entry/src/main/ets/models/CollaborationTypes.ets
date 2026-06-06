// models/CollaborationTypes.ets
// 分布式协同功能相关类型定义

// 协同设备信息
export interface CollaboratorDevice {
  deviceId: string;
  deviceName: string;
  deviceType: string;       // 'phone' | 'tablet' | '2in1'
  isHost: boolean;
  isOnline: boolean;
  joinedAt: number;
}

// 协同会话状态
export enum CollaborationSessionState {
  IDLE = 'idle',
  HOSTING = 'hosting',         // 作为主设备
  JOINING = 'joining',         // 正在加入
  CONNECTED = 'connected',     // 已连接
  DISCONNECTED = 'disconnected'
}

// 协同会话
export interface CollaborationSession {
  sessionId: string;
  noteId: string;
  noteTitle: string;
  hostDeviceId: string;
  participants: CollaboratorDevice[];
  state: CollaborationSessionState;
  createdAt: number;
  lastActivityAt: number;
}

// 协同操作类型
export enum CollabOperationType {
  INSERT = 'insert',
  DELETE = 'delete',
  REPLACE = 'replace'
}

// 协同操作（OT 操作单元）
export interface CollabOperation {
  type: CollabOperationType;
  position: number;
  text?: string;
  length?: number;
  timestamp: number;
  deviceId: string;
  seqNumber: number;
}

// 远程光标状态
export interface RemoteCursorState {
  deviceId: string;
  deviceName: string;
  position: number;
  selectionStart: number;
  selectionEnd: number;
  color: string;
  timestamp: number;
}

// 分享意图数据
export interface ShareIntentData {
  action: 'openSharedNote' | 'joinCollaboration' | 'openNote';
  noteId?: string;
  collaborationSessionId?: string;
  content?: string;
  title?: string;
}

// 分布式 KVStore 的 Key 前缀接口
export interface KVKeyPrefix {
  SESSION_META: string;
  SESSION_CONTENT: string;
  SESSION_OPS: string;
  SESSION_CURSOR: string;
}

// 分布式 KVStore 的 Key 常量
export const KV_KEY_PREFIX: KVKeyPrefix = {
  SESSION_META: 'session:meta:',
  SESSION_CONTENT: 'session:content:',
  SESSION_OPS: 'session:ops:',
  SESSION_CURSOR: 'session:cursor:',
};

// 设备光标颜色（最多支持 8 台设备）
export const DEVICE_CURSOR_COLORS: string[] = [
  '#FF6B6B', '#4ECDC4', '#45B7D1', '#96CEB4',
  '#FFEAA7', '#DDA0DD', '#98D8C8', '#F7DC6F'
];
