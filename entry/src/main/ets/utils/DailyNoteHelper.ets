// utils/DailyNoteHelper.ets
// 每日笔记辅助 — 自动创建/打开当天日期的笔记

import { fileService } from '../services/IFileService';
import { FileService } from './FileService';

export interface DailyNoteResult {
  noteId: string;
  title: string;
  isNew: boolean;
}

export class DailyNoteHelper {
  static getDateString(date: Date): string {
    const y = date.getFullYear().toString();
    const m = (date.getMonth() + 1).toString().padStart(2, '0');
    const d = date.getDate().toString().padStart(2, '0');
    return y + '-' + m + '-' + d;
  }

  static getFileName(): string {
    return DailyNoteHelper.getDateString(new Date()) + '.md';
  }

  static getNoteId(): string {
    return DailyNoteHelper.getDateString(new Date());
  }

  static async openOrCreateDailyNote(): Promise<DailyNoteResult> {
    const noteId = DailyNoteHelper.getNoteId();
    const fileName = DailyNoteHelper.getFileName();
    const baseDir = FileService.getInstance().getBaseDirectory();
    const filePath = baseDir + '/' + fileName;

    // 检查文件是否已存在
    const exists = await FileService.getInstance().fileExists(filePath);
    if (exists) {
      return { noteId: noteId, title: fileName, isNew: false } as DailyNoteResult;
    }

    // 不存在则创建
    const dateStr = DailyNoteHelper.getDateString(new Date());
    const template = '# ' + dateStr + '\n\n## 待办\n\n- [ ] \n\n## 笔记\n\n';
    await fileService.createNote('/', dateStr, template);
    return { noteId: noteId, title: fileName, isNew: true } as DailyNoteResult;
  }
}
