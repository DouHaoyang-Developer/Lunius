# Obsidian ArkTS 后端 API 规范

## 基础信息

- **协议**: HTTPS / HTTP（开发环境）
- **格式**: JSON
- **认证**: Bearer Token（请求头 `Authorization: Bearer <token>`）
- **Base URL**: `https://api.your-domain.com/v1`

---

## 1. 文件系统接口

### GET /vault/tree
获取 Vault 完整目录树

**Response:**
```json
{
  "id": "root",
  "name": "My Vault",
  "type": "vault",
  "path": "/",
  "children": [
    {
      "id": "01",
      "name": "01 项目笔记",
      "type": "folder",
      "path": "/01 项目笔记",
      "children": [
        {
          "id": "01-1",
          "name": "HarmonyOS 开发规范.md",
          "type": "file",
          "path": "/01 项目笔记/HarmonyOS 开发规范.md",
          "modifiedTime": "2026-05-15T08:30:00Z",
          "tags": ["dev", "harmonyos"],
          "wordCount": 2340
        }
      ]
    }
  ]
}
```

### GET /notes/{noteId}
读取笔记内容与元数据

**Response:**
```json
{
  "content": "# HarmonyOS 开发规范\n\n> 本文档定义了...",
  "metadata": {
    "id": "01-1",
    "title": "HarmonyOS 开发规范",
    "path": "/01 项目笔记/HarmonyOS 开发规范.md",
    "createdAt": 1715761800000,
    "updatedAt": 1716352800000,
    "tags": ["dev", "harmonyos"],
    "aliases": ["HOS规范"],
    "wordCount": 2340,
    "charCount": 15600,
    "links": ["ArkTS 性能优化.md", "响应式设计原理.md"],
    "backlinks": [],
    "attachments": [],
    "frontmatter": {
      "author": "Team A",
      "priority": "high",
      "status": "draft"
    }
  }
}
```

### PUT /notes/{noteId}
保存笔记

**Request:**
```json
{
  "content": "# 更新后的内容...",
  "metadata": {
    "updatedAt": 1716352800000,
    "tags": ["dev", "harmonyos", "updated"]
  }
}
```

**Response:** `204 No Content`

### POST /notes
创建新笔记

**Request:**
```json
{
  "path": "/03 日常记录",
  "title": "新笔记标题",
  "template": "# 新笔记标题\n\n创建时间: {{date}}"
}
```

**Response:**
```json
{
  "id": "note-1716352800000",
  "title": "新笔记标题",
  "path": "/03 日常记录/新笔记标题.md",
  "createdAt": 1716352800000,
  "updatedAt": 1716352800000,
  "tags": [],
  "aliases": [],
  "wordCount": 0,
  "charCount": 0,
  "links": [],
  "backlinks": [],
  "attachments": [],
  "frontmatter": {}
}
```

### DELETE /notes/{noteId}
删除笔记

**Response:** `204 No Content`

### POST /notes/{noteId}/move
移动/重命名笔记

**Request:**
```json
{
  "newPath": "/02 学习笔记/新名称.md"
}
```

### GET /notes/search?q={query}&includeContent=true&scope=vault
搜索笔记

**Response:**
```json
{
  "results": [
    {
      "noteId": "01-1",
      "title": "HarmonyOS 开发规范",
      "path": "/01 项目笔记/HarmonyOS 开发规范.md",
      "matches": [
        {
          "line": 12,
          "text": "HarmonyOS 应用开发标准",
          "start": 10,
          "end": 32
        }
      ],
      "score": 0.95
    }
  ]
}
```

### PUT /notes/{noteId}/frontmatter
更新 YAML Frontmatter

**Request:**
```json
{
  "frontmatter": {
    "priority": "low",
    "reviewed": true
  }
}
```

### WebSocket /ws/files
实时文件变更推送

**Event:**
```json
{
  "type": "modify",
  "nodeId": "01-1",
  "path": "/01 项目笔记/HarmonyOS 开发规范.md",
  "timestamp": 1716352800000
}
```

---

## 2. 关系图谱接口

### GET /graph
获取全局图谱数据

**Response:**
```json
{
  "nodes": [
    {
      "id": "n1",
      "label": "HarmonyOS 开发规范",
      "x": 0,
      "y": 0,
      "radius": 30,
      "color": "#7B68EE",
      "group": "project"
    }
  ],
  "edges": [
    {
      "source": "n1",
      "target": "n2",
      "strength": 0.8
    }
  ]
}
```

### GET /graph/local?center={noteId}&depth=2
获取局部图谱

---

## 3. 同步接口

### GET /sync/status
获取同步状态

**Response:**
```json
{
  "isSyncing": false,
  "lastSyncTime": 1716352800000,
  "pendingChanges": 3,
  "conflictCount": 0,
  "remoteUrl": "https://sync.example.com/vault"
}
```

### POST /sync
执行同步

**Response:**
```json
{
  "isSyncing": false,
  "lastSyncTime": 1716352800000,
  "pendingChanges": 0,
  "conflictCount": 0,
  "remoteUrl": "https://sync.example.com/vault"
}
```

### POST /sync/configure
配置同步

**Request:**
```json
{
  "remoteUrl": "https://sync.example.com/vault",
  "token": "your-access-token",
  "interval": 300
}
```

---

## 4. 前端 Service 替换步骤

```typescript
// 1. 创建 RealFileService.ts
import { IFileService, FileChangeEvent } from './ApiTypes';
import { http } from '@kit.NetworkKit';

const BASE_URL = 'https://api.your-domain.com/v1';

export class RealFileService implements IFileService {
  private token: string;

  constructor(token: string) {
    this.token = token;
  }

  private async request<T>(method: string, path: string, body?: object): Promise<T> {
    const response = await http.request(`${BASE_URL}${path}`, {
      method,
      header: {
        'Authorization': `Bearer ${this.token}`,
        'Content-Type': 'application/json'
      },
      body: body ? JSON.stringify(body) : undefined
    });
    return JSON.parse(response);
  }

  async getFileTree(): Promise<FileNode[]> {
    return this.request('GET', '/vault/tree');
  }

  async readNote(noteId: string): Promise<{ content: string; metadata: NoteMetadata }> {
    return this.request('GET', `/notes/${noteId}`);
  }

  async writeNote(noteId: string, content: string, metadata?: Partial<NoteMetadata>): Promise<void> {
    await this.request('PUT', `/notes/${noteId}`, { content, metadata });
  }

  // ... 实现其他方法

  onFileChange(callback: (event: FileChangeEvent) => void): void {
    // WebSocket 连接
    const ws = new WebSocket(`wss://api.your-domain.com/v1/ws/files?token=${this.token}`);
    ws.onmessage = (msg) => callback(JSON.parse(msg.data));
  }
}

// 2. 替换单例
export const fileService: IFileService = new RealFileService('your-token');
```

---

## 5. 分布式协同接口（Lunius v4.0+）

### 5.1 协同会话管理

基于 HarmonyOS DistributedKVStore 的 P2P 实时协同。

**会话生命周期：**

```
createSession → [invite devices] → joinSession → [real-time ops] → leaveSession → destroySession
```

**KVStore Key 空间设计：**

| Key | 用途 | 内容示例 |
|-----|------|---------|
| `session:meta:{sessionId}` | 会话元信息 | `{ noteId, hostDeviceId, participants[], createdAt, lastActivityAt }` |
| `session:content:{sessionId}` | 笔记内容快照 | Markdown 全文（≤4MB） |
| `session:ops:{sessionId}:{seq}` | 增量操作 | `{ type: 'insert'\|'delete'\|'replace', position, text?, length?, timestamp, deviceId, seqNumber }` |
| `session:cursor:{sessionId}:{deviceId}` | 设备光标 | `{ deviceId, deviceName, position, selectionStart, selectionEnd, color, timestamp }` |

### 5.2 OT 操作类型

```typescript
interface CollabOperation {
  type: 'insert' | 'delete' | 'replace';
  position: number;
  text?: string;
  length?: number;
  timestamp: number;
  deviceId: string;
  seqNumber: number;
}
```

### 5.3 冲突解决策略

- **默认策略**：LWW（Last Writer Wins），基于操作时间戳
- **冲突检测**：seqNumber 跳跃 > 50 时触发全量快照同步
- **合并粒度**：以 2s 防抖窗口为最小同步单位
- **降级方案**：检测到多设备冲突时回退到完整内容快照同步

### 5.4 碰一碰分享

通过 Share Kit 实现设备间笔记快速分享：

```typescript
// 发送端
harmonyShare.on('knockShare', (target) => {
  target.share(new systemShare.SharedData({
    utd: utd.UniformDataType.HYPERLINK,
    content: `https://lunius.drcn.agconnect.link/edit?noteId=${noteId}`,
    title: `Lunius 笔记: ${title}`,
    description: `字数: ${wordCount}`
  }));
});

// 接收端：通过 App Linking 深度链接自动打开
// EntryAbility.handleDeepLink() → AppStorage → MainEntry.handlePendingShareAction()
```

### 5.5 跨端迁移

通过 HarmonyOS Continuation 实现编辑任务在设备间无缝迁移：

```typescript
// module.json5 配置
"continuable": true,
"continuationType": "local"

// 源设备保存状态
onContinue(wantParam: Record<string, Object>): OnContinueResult {
  wantParam.noteId = currentNoteId;
  wantParam.noteContent = currentContent;
  return OnContinueResult.AGREE;
}

// 目标设备恢复
onCreate(want: Want): void {
  const noteId = want.parameters?.noteId as string;
  // 打开笔记并恢复编辑状态
}
```

---

*文档版本: v4.0*
*对应前端版本: Lunius v4.0 — 分布式协同版（SDK 6.1.1(24) / API 12+）*
