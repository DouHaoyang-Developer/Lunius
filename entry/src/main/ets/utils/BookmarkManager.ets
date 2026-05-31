// utils/BookmarkManager.ets
// 书签管理 — 笔记/标题/块级别的书签持久化

import { FileService } from './FileService';

export interface Bookmark {
  id: string;
  noteId: string;
  title: string;
  type: 'note' | 'heading' | 'block';
  anchor: string;
  createdAt: number;
}

export class BookmarkManager {
  private static instance: BookmarkManager;
  private bookmarks: Bookmark[] = [];
  private fileService: FileService = FileService.getInstance();
  private initialized: boolean = false;

  static getInstance(): BookmarkManager {
    if (!BookmarkManager.instance) {
      BookmarkManager.instance = new BookmarkManager();
    }
    return BookmarkManager.instance;
  }

  async init(): Promise<void> {
    if (this.initialized) return;
    const path = this.getStatePath();
    try {
      const exists = await this.fileService.fileExists(path);
      if (exists) {
        const data = await this.fileService.readFile(path);
        if (data) {
          this.bookmarks = JSON.parse(data) as Bookmark[];
        }
      }
    } catch (e) {
      console.error('BookmarkManager init error: ' + JSON.stringify(e));
    }
    this.initialized = true;
  }

  async addBookmark(noteId: string, title: string, type: 'note' | 'heading' | 'block', anchor?: string): Promise<void> {
    await this.init();
    const bm: Bookmark = {
      id: 'bm-' + Date.now().toString(36),
      noteId, title, type,
      anchor: anchor || '',
      createdAt: Date.now()
    };
    this.bookmarks.push(bm);
    await this.persist();
  }

  async removeBookmark(id: string): Promise<void> {
    await this.init();
    this.bookmarks = this.bookmarks.filter((b: Bookmark) => b.id !== id);
    await this.persist();
  }

  getBookmarks(): Bookmark[] {
    return [...this.bookmarks].sort((a: Bookmark, b: Bookmark) => b.createdAt - a.createdAt);
  }

  isBookmarked(noteId: string): boolean {
    return this.bookmarks.some((b: Bookmark) => b.noteId === noteId);
  }

  private getStatePath(): string {
    return this.fileService.getBaseDirectory() + '/bookmarks.json';
  }

  private async persist(): Promise<void> {
    try {
      await this.fileService.writeFile(this.getStatePath(), JSON.stringify(this.bookmarks));
    } catch (e) {
      console.error('BookmarkManager persist error: ' + JSON.stringify(e));
    }
  }
}
