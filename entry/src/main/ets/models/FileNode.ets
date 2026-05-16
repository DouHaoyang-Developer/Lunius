// models/FileNode.ets
// 文件系统数据模型

export enum NodeType {
  FOLDER = 'folder',
  FILE = 'file',
  VAULT = 'vault'
}

export interface FileNode {
  id: string;
  name: string;
  type: NodeType;
  path: string;
  children?: FileNode[];
  isExpanded?: boolean;
  isActive?: boolean;
  modifiedTime?: string;
  tags?: string[];
  wordCount?: number;
}

// 模拟 Vault 数据
export const MockVaultData: FileNode[] = [
  {
    id: 'root',
    name: 'My Vault',
    type: NodeType.VAULT,
    path: '/',
    isExpanded: true,
    children: [
      {
        id: '01',
        name: '01 项目笔记',
        type: NodeType.FOLDER,
        path: '/01 项目笔记',
        isExpanded: true,
        children: [
          {
            id: '01-1',
            name: 'HarmonyOS 开发规范.md',
            type: NodeType.FILE,
            path: '/01 项目笔记/HarmonyOS 开发规范.md',
            modifiedTime: '2026-05-15',
            tags: ['dev', 'harmonyos'],
            wordCount: 2340
          },
          {
            id: '01-2',
            name: 'ArkTS 性能优化.md',
            type: NodeType.FILE,
            path: '/01 项目笔记/ArkTS 性能优化.md',
            modifiedTime: '2026-05-14',
            tags: ['dev', 'performance'],
            wordCount: 1890
          }
        ]
      },
      {
        id: '02',
        name: '02 学习笔记',
        type: NodeType.FOLDER,
        path: '/02 学习笔记',
        isExpanded: false,
        children: [
          {
            id: '02-1',
            name: '响应式设计原理.md',
            type: NodeType.FILE,
            path: '/02 学习笔记/响应式设计原理.md',
            modifiedTime: '2026-05-10',
            tags: ['design'],
            wordCount: 1560
          },
          {
            id: '02-2',
            name: 'TypeScript 高级类型.md',
            type: NodeType.FILE,
            path: '/02 学习笔记/TypeScript 高级类型.md',
            modifiedTime: '2026-05-08',
            tags: ['ts', 'dev'],
            wordCount: 3200
          }
        ]
      },
      {
        id: '03',
        name: '03 日常记录',
        type: NodeType.FOLDER,
        path: '/03 日常记录',
        isExpanded: false,
        children: [
          {
            id: '03-1',
            name: '2026-05-16 周报.md',
            type: NodeType.FILE,
            path: '/03 日常记录/2026-05-16 周报.md',
            modifiedTime: '2026-05-16',
            tags: ['weekly'],
            wordCount: 890
          }
        ]
      },
      {
        id: '04',
        name: '未分类',
        type: NodeType.FOLDER,
        path: '/未分类',
        isExpanded: false,
        children: [
          {
            id: '04-1',
            name: '灵感碎片.md',
            type: NodeType.FILE,
            path: '/未分类/灵感碎片.md',
            modifiedTime: '2026-05-12',
            tags: ['idea'],
            wordCount: 450
          }
        ]
      },
      {
        id: '05',
        name: 'README.md',
        type: NodeType.FILE,
        path: '/README.md',
        modifiedTime: '2026-05-01',
        tags: ['meta'],
        wordCount: 560
      }
    ]
  }
];

// 大纲节点
export interface OutlineNode {
  level: number;
  title: string;
  line: number;
}

export const MockOutline: OutlineNode[] = [
  { level: 1, title: 'HarmonyOS 开发规范', line: 0 },
  { level: 2, title: '一、ArkTS 语言规范', line: 12 },
  { level: 3, title: '1.1 类型系统', line: 24 },
  { level: 3, title: '1.2 装饰器使用', line: 56 },
  { level: 2, title: '二、ArkUI 布局规范', line: 89 },
  { level: 3, title: '2.1 响应式断点', line: 102 },
  { level: 3, title: '2.2 多设备适配', line: 145 },
  { level: 2, title: '三、性能优化指南', line: 198 },
  { level: 3, title: '3.1 组件复用', line: 210 },
  { level: 3, title: '3.2 懒加载策略', line: 245 }
];

// 反向链接数据
export interface Backlink {
  source: string;
  context: string;
  line: number;
}

export const MockBacklinks: Backlink[] = [
  { source: 'ArkTS 性能优化.md', context: '根据 [[HarmonyOS 开发规范]] 中的建议...', line: 34 },
  { source: '响应式设计原理.md', context: '如 [[HarmonyOS 开发规范]] 所述，断点系统...', line: 78 },
  { source: 'TypeScript 高级类型.md', context: '参考 [[HarmonyOS 开发规范]] 的类型定义...', line: 112 }
];

// 标签数据
export const MockTags: string[] = ['dev', 'harmonyos', 'performance', 'design', 'ts', 'weekly', 'idea', 'meta'];
