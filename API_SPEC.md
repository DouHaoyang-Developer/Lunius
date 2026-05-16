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

*文档版本: v3.0*
*对应前端版本: Obsidian ArkTS v3.0*
