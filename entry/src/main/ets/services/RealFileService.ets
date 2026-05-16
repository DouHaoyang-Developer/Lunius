// services/RealFileService.ets
// 真实文件服务 — 实现 IFileService，提供本地文件 I/O + 反向链接

import { IFileService, SearchOptions, FileChangeEvent } from './IFileService';
import { NoteMetadata, SearchResultItem, FrontmatterValue } from './ApiTypes';
import { FileNode, NodeType } from '../models/FileNode';
import { FileService } from '../utils/FileService';

const TAG = 'RealFileService';

export class RealFileService implements IFileService {
  private fileService: FileService = FileService.getInstance();
  private noteIdToPath: Map<string, string> = new Map();
  private changeCallbacks: Array<(event: FileChangeEvent) => void> = [];

  // 链接索引缓存
  private linkIndex: Map<string, Set<string>> = new Map();
  private backlinkIndex: Map<string, Set<string>> = new Map();
  private indexDirty: boolean = true;

  // ─── 链接缓存 ─────────────────────────────────

  private async rebuildLinkIndex(): Promise<void> {
    if (!this.indexDirty) return;
    this.linkIndex.clear();
    this.backlinkIndex.clear();

    const files = await this.fileService.getMarkdownFiles();
    for (const filePath of files) {
      const noteId = this.getNoteIdFromPath(filePath);
      try {
        const raw = await this.fileService.readFile(filePath);
        const result = this.parseFrontmatter(raw);
        const content: string = result[1] as string;
        const links = this.extractLinks(content);

        if (!this.linkIndex.has(noteId)) {
          this.linkIndex.set(noteId, new Set());
        }
        const linkSet = this.linkIndex.get(noteId)!;

        for (const linkName of links) {
          const targetId = this.resolveLinkName(linkName, files);
          if (targetId) {
            linkSet.add(targetId);
            if (!this.backlinkIndex.has(targetId)) {
              this.backlinkIndex.set(targetId, new Set());
            }
            this.backlinkIndex.get(targetId)!.add(noteId);
          }
        }
      } catch (e) {
        // file may not exist yet
      }
    }
    this.indexDirty = false;
  }

  private resolveLinkName(linkName: string, allFiles: string[]): string | null {
    const clean = linkName.replace('.md', '');
    for (const fp of allFiles) {
      const fileName = fp.substring(fp.lastIndexOf('/') + 1);
      const nameWithoutExt = fileName.replace('.md', '');
      if (nameWithoutExt === clean || fileName === linkName) {
        return nameWithoutExt;
      }
    }
    return null;
  }

  getLinkIndex(): Map<string, Set<string>> { return this.linkIndex; }
  getBacklinkIndex(): Map<string, Set<string>> { return this.backlinkIndex; }

  // ─── 内部映射 ─────────────────────────────────

  private getNoteIdFromPath(filePath: string): string {
    const fileName = filePath.substring(filePath.lastIndexOf('/') + 1);
    return fileName.replace('.md', '');
  }

  private getPathFromNoteId(noteId: string): string {
    const cached = this.noteIdToPath.get(noteId);
    if (cached) return cached;
    const baseDir = this.fileService.getBaseDirectory();
    return `${baseDir}/${noteId}.md`;
  }

  private async refreshIdMapping(): Promise<void> {
    const files = await this.fileService.getMarkdownFiles();
    this.noteIdToPath.clear();
    for (const fp of files) {
      const id = this.getNoteIdFromPath(fp);
      this.noteIdToPath.set(id, fp);
    }
  }

  // ─── YAML Frontmatter 解析（纯字符串操作） ────

  private parseFrontmatter(raw: string): [Map<string, FrontmatterValue>, string] {
    const fm = new Map<string, FrontmatterValue>();
    const lines = raw.split('\n');
    if (lines.length === 0 || lines[0].trim() !== '---') {
      return [fm, raw];
    }
    let endIdx = -1;
    for (let i = 1; i < lines.length; i++) {
      if (lines[i].trim() === '---') {
        endIdx = i;
        break;
      }
    }
    if (endIdx === -1) {
      return [fm, raw];
    }
    for (let i = 1; i < endIdx; i++) {
      const line = lines[i];
      const colonIdx = line.indexOf(':');
      if (colonIdx === -1) continue;
      const key = line.substring(0, colonIdx).trim();
      let value: string = line.substring(colonIdx + 1).trim();
      if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'"))) {
        value = value.substring(1, value.length - 1);
      }
      if (value.startsWith('[') && value.endsWith(']')) {
        const inner = value.substring(1, value.length - 1);
        const arr = inner.split(',').map((s: string) => s.trim().replace(/^["']|["']$/g, ''));
        fm.set(key, arr);
      } else if (value === 'true') {
        fm.set(key, true);
      } else if (value === 'false') {
        fm.set(key, false);
      } else {
        const num = Number(value);
        if (!isNaN(num) && value !== '') {
          fm.set(key, num);
        } else {
          fm.set(key, value);
        }
      }
    }
    const content = lines.slice(endIdx + 1).join('\n');
    return [fm, content];
  }

  private buildFileWithFrontmatter(content: string, fm: Map<string, FrontmatterValue>): string {
    if (fm.size === 0) return content;
    const lines: string[] = [];
    lines.push('---');
    const keys = Array.from(fm.keys());
    for (let i = 0; i < keys.length; i++) {
      const key = keys[i];
      const val = fm.get(key);
      if (Array.isArray(val)) {
        lines.push(key + ': [' + val.map((v: string) => '"' + v + '"').join(', ') + ']');
      } else if (typeof val === 'string') {
        lines.push(key + ': "' + val + '"');
      } else {
        lines.push(key + ': ' + String(val));
      }
    }
    lines.push('---');
    lines.push('');
    lines.push(content);
    return lines.join('\n');
  }

  private extractLinks(content: string): string[] {
    const links: string[] = [];
    const regex = /\[\[([^\]]+)\]\]/g;
    let m: RegExpExecArray | null;
    while ((m = regex.exec(content)) !== null) {
      links.push(m[1]);
    }
    return links;
  }

  // ─── IFileService 实现 ─────────────────────────

  async getFileTree(): Promise<FileNode[]> {
    await this.refreshIdMapping();
    this.indexDirty = true;
    const files = await this.fileService.getMarkdownFiles();
    const vault: FileNode = {
      id: 'root',
      name: 'My Vault',
      type: NodeType.VAULT,
      path: '/',
      isExpanded: true,
      children: []
    };

    for (const filePath of files) {
      const fileName = filePath.substring(filePath.lastIndexOf('/') + 1);
      const id = this.getNoteIdFromPath(filePath);
      try {
        const raw = await this.fileService.readFile(filePath);
        const result = this.parseFrontmatter(raw);
        const fm: Map<string, FrontmatterValue> = result[0];
        const content: string = result[1] as string;
        const tags: string[] = fm.get('tags') ? (Array.isArray(fm.get('tags')) ? fm.get('tags') as string[] : []) : [];
        const wordCount = content.split(/\s+/).filter((w: string) => w.length > 0).length;
        vault.children!.push({
          id, name: fileName, type: NodeType.FILE, path: '/' + fileName,
          tags: tags, wordCount: wordCount
        });
      } catch (e) {
        vault.children!.push({
          id, name: fileName, type: NodeType.FILE, path: '/' + fileName, wordCount: 0
        });
      }
    }

    return [vault];
  }

  async readNote(noteId: string): Promise<{ content: string; metadata: NoteMetadata }> {
    const filePath = this.getPathFromNoteId(noteId);
    const raw = await this.fileService.readFile(filePath);
    const result = this.parseFrontmatter(raw);
    const fm: Map<string, FrontmatterValue> = result[0];
    const content: string = result[1] as string;
    const fileName = filePath.substring(filePath.lastIndexOf('/') + 1);

    const tagsVal = fm.get('tags');
    const tags: string[] = tagsVal && Array.isArray(tagsVal) ? tagsVal as string[] : [];
    const aliasesVal = fm.get('aliases');
    const aliases: string[] = aliasesVal && Array.isArray(aliasesVal) ? aliasesVal as string[] : [];
    const links = this.extractLinks(content);
    const wordCount = content.split(/\s+/).filter((w: string) => w.length > 0).length;

    // 反向链接
    await this.rebuildLinkIndex();
    const backlinkSet = this.backlinkIndex.get(noteId);
    const backlinks = backlinkSet ? Array.from(backlinkSet).map((id: string): string => id + '.md') : [];

    const metadata: NoteMetadata = {
      id: noteId,
      title: fileName.replace('.md', ''),
      path: '/' + fileName,
      createdAt: Date.now(),
      updatedAt: Date.now(),
      tags: tags,
      aliases: aliases,
      wordCount: wordCount,
      charCount: content.length,
      links: links,
      backlinks: backlinks,
      attachments: [],
      frontmatter: fm
    };

    return { content, metadata };
  }

  async writeNote(noteId: string, content: string, metadata?: Partial<NoteMetadata>): Promise<void> {
    const filePath = this.getPathFromNoteId(noteId);
    const fm = new Map<string, FrontmatterValue>();
    if (metadata) {
      if (metadata.tags) fm.set('tags', metadata.tags);
    }
    const fullContent = this.buildFileWithFrontmatter(content, fm);
    await this.fileService.writeFile(filePath, fullContent);
    this.indexDirty = true;
  }

  async createNote(path: string, title: string, template?: string): Promise<NoteMetadata> {
    const fileName = await this.fileService.generateUniqueFileName(title || '未命名', 'md');
    const filePath = await this.fileService.createFile(fileName);
    const content = template || '# ' + title + '\n\n';
    await this.fileService.writeFile(filePath, content);

    const noteId = this.getNoteIdFromPath(filePath);
    this.noteIdToPath.set(noteId, filePath);
    this.indexDirty = true;

    return {
      id: noteId, title, path: '/' + fileName,
      createdAt: Date.now(), updatedAt: Date.now(),
      tags: [], aliases: [], wordCount: title.split(/\s+/).length,
      charCount: content.length, links: [], backlinks: [],
      attachments: [], frontmatter: new Map<string, FrontmatterValue>()
    };
  }

  async deleteNote(noteId: string): Promise<void> {
    const filePath = this.getPathFromNoteId(noteId);
    try {
      const exists = await this.fileService.fileExists(filePath);
      if (exists) {
        await this.fileService.writeFile(filePath, '');
      }
      this.noteIdToPath.delete(noteId);
      this.indexDirty = true;
    } catch (e) {
      console.error(TAG + ' deleteNote error: ' + JSON.stringify(e));
    }
  }

  async moveNote(noteId: string, newPath: string): Promise<void> {
    const filePath = this.getPathFromNoteId(noteId);
    const baseDir = this.fileService.getBaseDirectory();
    const newFilePath = baseDir + newPath;
    await this.fileService.renameFile(filePath, newFilePath);
    const newId = this.getNoteIdFromPath(newFilePath);
    this.noteIdToPath.set(newId, newFilePath);
    if (newId !== noteId) {
      this.noteIdToPath.delete(noteId);
    }
    this.indexDirty = true;
  }

  async searchNotes(query: string, options?: SearchOptions): Promise<SearchResultItem[]> {
    const files = await this.fileService.getMarkdownFiles();
    const results: SearchResultItem[] = [];

    for (const filePath of files) {
      const fileName = filePath.substring(filePath.lastIndexOf('/') + 1);
      const noteId = this.getNoteIdFromPath(filePath);

      if (options?.scope === 'vault' || options?.scope === undefined) {
        const content = await this.fileService.readFile(filePath);
        const lowerContent = options?.caseSensitive ? content : content.toLowerCase();
        const lowerQuery = options?.caseSensitive ? query : query.toLowerCase();

        if (lowerContent.includes(lowerQuery)) {
          const matches: Array<{ line: number; text: string; start: number; end: number }> = [];
          const lines = content.split('\n');
          for (let i = 0; i < lines.length; i++) {
            const line = options?.caseSensitive ? lines[i] : lines[i].toLowerCase();
            const idx = line.indexOf(lowerQuery);
            if (idx !== -1) {
              matches.push({ line: i + 1, text: lines[i], start: idx, end: idx + query.length });
            }
          }
          results.push({
            noteId,
            title: fileName.replace('.md', ''),
            path: '/' + fileName,
            matches: matches.slice(0, 5),
            score: matches.length
          });
        }
      }
    }

    return results.sort((a: SearchResultItem, b: SearchResultItem) => b.score - a.score);
  }

  async getMetadata(noteId: string): Promise<NoteMetadata> {
    const result = await this.readNote(noteId);
    return result.metadata;
  }

  async updateFrontmatterField(noteId: string, key: string, value: FrontmatterValue): Promise<void> {
    const filePath = this.getPathFromNoteId(noteId);
    const raw = await this.fileService.readFile(filePath);
    const result = this.parseFrontmatter(raw);
    const fm: Map<string, FrontmatterValue> = result[0];
    const content: string = result[1] as string;
    fm.set(key, value);
    const fullContent = this.buildFileWithFrontmatter(content, fm);
    await this.fileService.writeFile(filePath, fullContent);
    this.indexDirty = true;
  }

  onFileChange(callback: (event: FileChangeEvent) => void): void {
    this.changeCallbacks.push(callback);
  }
}
