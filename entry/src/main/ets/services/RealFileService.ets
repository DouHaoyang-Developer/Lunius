// services/RealFileService.ets
// 真实文件服务 — 实现 IFileService，提供本地文件 I/O + 反向链接

import { IFileService, SearchOptions, FileChangeEvent } from './IFileService';
import { NoteMetadata, SearchResultItem, SearchMatch, NoteReadResult, FrontmatterValue } from './ApiTypes';
import { FileNode, NodeType } from '../models/FileNode';
import { FileService } from '../utils/FileService';
import { parseSearchQuery } from '../utils/SearchQueryParser';
import { renderTemplate, makeTemplateContext } from '../utils/TemplateEngine';

const TAG = 'RealFileService';

export interface UnlinkedMention {
  source: string;
  context: string;
  line: number;
}

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
    const baseDir = this.fileService.getBaseDirectory();

    for (const fp of allFiles) {
      // 检查裸文件名匹配（向后兼容旧版 [[note]] 格式）
      const fileName = fp.substring(fp.lastIndexOf('/') + 1);
      const nameWithoutExt = fileName.replace('.md', '');
      if (nameWithoutExt === clean || fileName === linkName) {
        return this.getNoteIdFromPath(fp);
      }

      // 检查相对路径匹配（新版 [[folder/note]] 格式）
      let relativePath = fp;
      if (fp.startsWith(baseDir + '/')) {
        relativePath = fp.substring(baseDir.length + 1);
      } else if (fp.startsWith(baseDir)) {
        relativePath = fp.substring(baseDir.length);
      }
      const relativeId = relativePath.replace('.md', '');
      if (relativeId === clean) {
        return relativeId;
      }

      // 检查仅文件名匹配（允许忽略文件夹差异）
      if (nameWithoutExt === clean) {
        return this.getNoteIdFromPath(fp);
      }
    }
    return null;
  }

  getLinkIndex(): Map<string, Set<string>> { return this.linkIndex; }
  getBacklinkIndex(): Map<string, Set<string>> { return this.backlinkIndex; }

  // ─── 内部映射 ─────────────────────────────────

  private getNoteIdFromPath(filePath: string): string {
    const baseDir = this.fileService.getBaseDirectory();
    let relativePath = filePath;
    if (filePath.startsWith(baseDir + '/')) {
      relativePath = filePath.substring(baseDir.length + 1);
    } else if (filePath.startsWith(baseDir)) {
      relativePath = filePath.substring(baseDir.length);
    }
    return relativePath.replace('.md', '');
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
    // 匹配 [[link]] [[link|display]] [[link#heading]] [[link#^block]] ![[embed]]
    const regex = /!?\[\[([^\]#|]+)(?:[#|]([^\]]+))?\]\]/g;
    let m: RegExpExecArray | null;
    while ((m = regex.exec(content)) !== null) {
      const target = m[1].trim();
      const anchor = m[2] ? m[2].trim() : '';
      links.push(anchor ? target + '#' + anchor : target);
    }
    return links;
  }

  // ─── IFileService 实现 ─────────────────────────

  async getFileTree(): Promise<FileNode[]> {
    await this.refreshIdMapping();
    this.indexDirty = true;
    const files = await this.fileService.getMarkdownFiles();
    const baseDir = this.fileService.getBaseDirectory();

    const vault: FileNode = {
      id: 'root',
      name: 'My Vault',
      type: NodeType.VAULT,
      path: '/',
      isExpanded: true,
      children: []
    };

    const folderMap = new Map<string, FileNode>();
    folderMap.set('', vault);

    files.sort();

    for (const filePath of files) {
      let relativePath = filePath;
      if (filePath.startsWith(baseDir + '/')) {
        relativePath = filePath.substring(baseDir.length + 1);
      } else if (filePath.startsWith(baseDir)) {
        relativePath = filePath.substring(baseDir.length);
      }

      const fileName = relativePath.substring(relativePath.lastIndexOf('/') + 1);
      const dirPath = relativePath.includes('/')
        ? relativePath.substring(0, relativePath.lastIndexOf('/'))
        : '';

      // 确保所有父文件夹节点存在
      const parts = dirPath ? dirPath.split('/') : [];
      let currentPath = '';
      for (const part of parts) {
        const prevPath = currentPath;
        currentPath = currentPath ? currentPath + '/' + part : part;

        if (!folderMap.has(currentPath)) {
          const folderNode: FileNode = {
            id: 'folder-' + currentPath.replace(/\//g, '-'),
            name: part,
            type: NodeType.FOLDER,
            path: '/' + currentPath,
            isExpanded: true,
            children: []
          };
          folderMap.set(currentPath, folderNode);

          const parentFolder = folderMap.get(prevPath) || vault;
          if (!parentFolder.children) {
            parentFolder.children = [];
          }
          parentFolder.children.push(folderNode);
        }
      }

      // 添加文件节点
      const id = this.getNoteIdFromPath(filePath);
      const fileNode: FileNode = {
        id,
        name: fileName,
        type: NodeType.FILE,
        path: '/' + relativePath
      };

      try {
        const raw = await this.fileService.readFile(filePath);
        const result = this.parseFrontmatter(raw);
        const fm: Map<string, FrontmatterValue> = result[0];
        const content: string = result[1] as string;
        const tags: string[] = fm.get('tags')
          ? (Array.isArray(fm.get('tags')) ? fm.get('tags') as string[] : [])
          : [];
        const wordCount = content.split(/\s+/).filter((w: string) => w.length > 0).length;
        fileNode.tags = tags;
        fileNode.wordCount = wordCount;
      } catch (e) {
        fileNode.wordCount = 0;
      }

      const targetParent = folderMap.get(dirPath) || vault;
      if (!targetParent.children) {
        targetParent.children = [];
      }
      targetParent.children.push(fileNode);
    }

    return [vault];
  }

  async readNote(noteId: string): Promise<NoteReadResult> {
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

    const relativePath = noteId + '.md';
    const metadata: NoteMetadata = {
      id: noteId,
      title: fileName.replace('.md', ''),
      path: '/' + relativePath,
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

    const noteResult: NoteReadResult = { content: content, metadata: metadata };
    return noteResult;
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
    let subDir: string | undefined = undefined;
    if (path && path !== '/') {
      subDir = path.startsWith('/') ? path.substring(1) : path;
    }

    const fileName = await this.fileService.generateUniqueFileName(title || '未命名', 'md', subDir);
    const filePath = await this.fileService.createFileInDir(fileName, subDir);
    const ctx = makeTemplateContext(title || '未命名', subDir);
    const rawContent = template || '# {{title}}\n\n创建时间: {{date}}\n\n';
    const content = renderTemplate(rawContent, ctx);
    await this.fileService.writeFile(filePath, content);

    const noteId = this.getNoteIdFromPath(filePath);
    this.noteIdToPath.set(noteId, filePath);
    this.indexDirty = true;

    let displayPath = fileName;
    if (subDir) {
      displayPath = subDir + '/' + fileName;
    }

    return {
      id: noteId, title, path: '/' + displayPath,
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

    // 确保目标目录存在
    const sepIdx = newPath.lastIndexOf('/');
    if (sepIdx > 0) {
      const targetDir = newPath.substring(0, sepIdx);
      await this.fileService.createDirectory(targetDir);
    }

    await this.fileService.renameFile(filePath, newFilePath);
    const newId = this.getNoteIdFromPath(newFilePath);
    this.noteIdToPath.set(newId, newFilePath);
    if (newId !== noteId) {
      this.noteIdToPath.delete(noteId);
    }

    // 自动更新全 Vault 的 [[引用]]
    if (newId !== noteId) {
      await this.replaceLinksInVault(noteId, newId);
    }

    this.indexDirty = true;
  }

  private async replaceLinksInVault(oldId: string, newId: string): Promise<void> {
    const files = await this.fileService.getMarkdownFiles();
    const oldName = oldId.includes('/') ? oldId.substring(oldId.lastIndexOf('/') + 1) : oldId;
    const newName = newId.includes('/') ? newId.substring(newId.lastIndexOf('/') + 1) : newId;

    for (const fp of files) {
      const content = await this.fileService.readFile(fp);
      let changed = false;
      let updated = content;

      // 替换 [[旧名]] → [[新名]]
      const fullOld = `[[${oldId}]]`;
      if (updated.includes(fullOld)) {
        updated = updated.replace(new RegExp(this.escapeRegex(fullOld), 'g'), `[[${newId}]]`);
        changed = true;
      }

      // 替换 [[旧文件名]] → [[新文件名]]（裸文件名形式）
      if (oldName !== newName && oldName !== oldId) {
        const bareOld = `[[${oldName}]]`;
        if (updated.includes(bareOld)) {
          updated = updated.replace(new RegExp(this.escapeRegex(bareOld), 'g'), `[[${newName}]]`);
          changed = true;
        }
      }

      if (changed) {
        await this.fileService.writeFile(fp, updated);
        console.info(TAG + ' replaceLinksInVault updated: ' + fp);
      }
    }
  }

  async searchNotes(query: string, options?: SearchOptions): Promise<SearchResultItem[]> {
    const files = await this.fileService.getMarkdownFiles();
    const results: SearchResultItem[] = [];
    const parsed = parseSearchQuery(query);
    const hasFilters = parsed.tags.length > 0 || parsed.paths.length > 0 ||
      parsed.files.length > 0 || parsed.notTags.length > 0;
    const textSearch = parsed.textTerms.join(' ');

    for (const filePath of files) {
      const fileName = filePath.substring(filePath.lastIndexOf('/') + 1);
      const noteId = this.getNoteIdFromPath(filePath);

      // 过滤：tag: 运算符
      if (parsed.tags.length > 0) {
        const meta = await this.getMetadata(noteId);
        const noteTags = meta.tags || [];
        let hasAll = true;
        for (const t of parsed.tags) {
          if (!noteTags.includes(t)) { hasAll = false; break; }
        }
        if (!hasAll) continue;
      }

      // 过滤：-tag: 排除运算符
      if (parsed.notTags.length > 0) {
        const meta = await this.getMetadata(noteId);
        const noteTags = meta.tags || [];
        let hasAny = false;
        for (const t of parsed.notTags) {
          if (noteTags.includes(t)) { hasAny = true; break; }
        }
        if (hasAny) continue;
      }

      // 过滤：path: 运算符
      if (parsed.paths.length > 0) {
        let matchesPath = false;
        for (const p of parsed.paths) {
          if (noteId.toLowerCase().includes(p.toLowerCase())) {
            matchesPath = true;
            break;
          }
        }
        if (!matchesPath) continue;
      }

      // 过滤：file: 运算符
      if (parsed.files.length > 0) {
        let matchesFile = false;
        for (const f of parsed.files) {
          if (fileName.toLowerCase().includes(f.toLowerCase())) {
            matchesFile = true;
            break;
          }
        }
        if (!matchesFile) continue;
      }

      if (options?.scope === 'vault' || options?.scope === undefined) {
        const content = await this.fileService.readFile(filePath);
        const searchTarget = textSearch || query;
        const lowerContent = options?.caseSensitive ? content : content.toLowerCase();
        const lowerQuery = options?.caseSensitive ? searchTarget : searchTarget.toLowerCase();
        const useRegex = options?.regex === true;

        let matched = false;
        let matches: SearchMatch[] = [];

        if (useRegex && searchTarget) {
          try {
            const regex = new RegExp(searchTarget, options?.caseSensitive ? 'g' : 'gi');
            let rm: RegExpExecArray | null;
            while ((rm = regex.exec(content)) !== null) {
              matched = true;
              matches.push({ line: 0, text: content.substring(Math.max(0, rm.index - 20), rm.index + rm[0].length + 20), start: rm.index, end: rm.index + rm[0].length });
            }
          } catch (e) {
            // invalid regex falls through
          }
        }

        if (!matched && searchTarget) {
          if (lowerContent.includes(lowerQuery)) {
            matched = true;
            const lines = content.split('\n');
            for (let i = 0; i < lines.length; i++) {
              const line = options?.caseSensitive ? lines[i] : lines[i].toLowerCase();
              const idx = line.indexOf(lowerQuery);
              if (idx !== -1) {
                const m: SearchMatch = { line: i + 1, text: lines[i], start: idx, end: idx + searchTarget.length };
                matches.push(m);
              }
            }
          }
        }

        // 如果仅有运算符（无文本搜索词），过滤后直接返回
        if (!textSearch && hasFilters) {
          matched = true;
          matches = [{ line: 1, text: fileName, start: 0, end: fileName.length }];
        }

        if (matched) {
          results.push({
            noteId,
            title: fileName.replace('.md', ''),
            path: '/' + noteId + '.md',
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

  private escapeRegex(str: string): string {
    return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  }

  onFileChange(callback: (event: FileChangeEvent) => void): void {
    this.changeCallbacks.push(callback);
  }

  async findUnlinkedMentions(noteId: string): Promise<UnlinkedMention[]> {
    const meta = await this.getMetadata(noteId);
    const title = meta.title;
    if (!title) return [];
    const allFiles = await this.fileService.getMarkdownFiles();
    const backlinkSet = this.backlinkIndex.get(noteId);
    const mentions: UnlinkedMention[] = [];

    for (const fp of allFiles) {
      const sourceId = this.getNoteIdFromPath(fp);
      if (sourceId === noteId) continue;
      if (backlinkSet && backlinkSet.has(sourceId)) continue;

      const content = await this.fileService.readFile(fp);
      const lowerContent = content.toLowerCase();
      const lowerTitle = title.toLowerCase();

      if (!lowerContent.includes(lowerTitle)) continue;

      const lines = content.split('\n');
      for (let i = 0; i < lines.length; i++) {
        const lowerLine = lines[i].toLowerCase();
        if (lowerLine.includes(lowerTitle)) {
          // 确认不在 [[...]] 内
          if (!lines[i].match(new RegExp(`\\[\\[.*${this.escapeRegex(title)}.*\\]\\]`, 'i'))) {
            const mention: UnlinkedMention = { source: sourceId, context: lines[i].trim(), line: i + 1 };
            mentions.push(mention);
            if (mentions.length >= 10) break;
          }
        }
      }
      if (mentions.length >= 10) break;
    }
    return mentions;
  }

  async getAllNoteFileNames(): Promise<string[]> {
    const files = await this.fileService.getMarkdownFiles();
    const names: string[] = [];
    for (const fp of files) {
      const id = this.getNoteIdFromPath(fp);
      if (id) {
        names.push(id);
      }
    }
    return names;
  }
}
