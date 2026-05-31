// utils/AttachmentManager.ets
// 附件管理 — 管理 attachments/ 目录中的附件文件

import { FileService } from './FileService';

export interface AttachmentInfo {
  name: string;
  path: string;
  type: 'image' | 'pdf' | 'audio' | 'video' | 'other';
  size: number;
}

export class AttachmentManager {
  private static instance: AttachmentManager;
  private fileService: FileService = FileService.getInstance();
  private attachmentsDir: string = '';

  static getInstance(): AttachmentManager {
    if (!AttachmentManager.instance) {
      AttachmentManager.instance = new AttachmentManager();
    }
    return AttachmentManager.instance;
  }

  async init(): Promise<void> {
    this.attachmentsDir = 'attachments';
    await this.fileService.createDirectory(this.attachmentsDir);
  }

  private getBaseDir(): string {
    return this.fileService.getBaseDirectory() + '/' + this.attachmentsDir;
  }

  async listAttachments(): Promise<AttachmentInfo[]> {
    const dir = this.getBaseDir();
    const results: AttachmentInfo[] = [];
    try {
      const files = await this.fileService.getMarkdownFiles();
      // 使用 file 系统列出 attachments 目录
      // 简化版: 仅通过已知路径跟踪
    } catch (e) {
      console.error('AttachmentManager listAttachments error: ' + JSON.stringify(e));
    }
    return results;
  }

  getAttachmentType(fileName: string): 'image' | 'pdf' | 'audio' | 'video' | 'other' {
    const ext = fileName.substring(fileName.lastIndexOf('.')).toLowerCase();
    if (['.png', '.jpg', '.jpeg', '.gif', '.webp', '.bmp', '.svg'].includes(ext)) return 'image';
    if (['.pdf'].includes(ext)) return 'pdf';
    if (['.mp3', '.wav', '.ogg', '.m4a'].includes(ext)) return 'audio';
    if (['.mp4', '.webm', '.mov'].includes(ext)) return 'video';
    return 'other';
  }

  getAttachmentsDir(): string {
    return this.attachmentsDir;
  }
}
