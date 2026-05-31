// components/MarkdownEditor.ets
// Markdown 编辑器 v5 — RichEditor 驱动的 Obsidian 风格实时阅览

import { promptAction } from '@kit.ArkUI';
import { picker } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { ObsidianColors, ThemeMode, getColors } from '../utils/Theme';
import { NoteViewModel } from '../viewmodels/NoteViewModel';
import { Breadcrumb } from './breadcrumb/Breadcrumb';
import { StatusBar } from './statusbar/StatusBar';
import { SplitView } from './splitview/SplitView';
import { PropertiesPanel } from './properties/PropertiesPanel';
import { Modal, ModalConfig } from './modal/Modal';
import { getCompletions, shouldShowCompletion, CompletionItem } from '../utils/MarkdownCompleter';
import { LivePreviewHelper } from '../utils/LivePreviewHelper';
import { markdownToHtml } from '../utils/MarkdownToHtml';
import { MermaidWebView, extractMermaidBlocks, ContentBlock } from '../utils/MermaidRenderer';
import { fileService } from '../services/IFileService';
import { syncService } from '../services/ISyncService';
import { SyncStatus } from '../services/ApiTypes';
import { LinkPreviewCard, LinkPreviewData } from './LinkPreviewCard';
import { FindReplaceBar, FindMatch } from './FindReplaceBar';

interface BreadcrumbItem {
  name: string;
  path: string;
  isFile: boolean;
}

@Component
export struct MarkdownEditor {
  @StorageLink('themeMode') themeMode: ThemeMode = ThemeMode.DARK;
  @ObjectLink vm: NoteViewModel;
  @Prop isSplitView: boolean = false;
  @Prop canNavigateBack: boolean = false;
  @Prop canNavigateForward: boolean = false;
  @State viewMode: string = 'live';
  @State showProperties: boolean = false;
  @State showModal: boolean = false;
  @State modalConfig: ModalConfig = { title: '', message: '', type: 'alert' };
  @State completions: CompletionItem[] = [];
  @State showCompletions: boolean = false;
  @State syncStatus: SyncStatus | null = null;
  @State editorCaretOffset: number = -1;
  // 悬停预览
  @State showLinkPreview: boolean = false;
  @State linkPreviewData: LinkPreviewData = { title: '', snippet: '', wordCount: 0 };
  // 查找替换
  @State showFindReplace: boolean = false;
  @State findMatches: FindMatch[] = [];
  @State findCurrentIndex: number = 0;
  onNavigateBack?: () => void;
  onNavigateForward?: () => void;

  private richEditorController: RichEditorController = new RichEditorController();
  private linkPreviewTimer: number = -1;
  private livePreview: LivePreviewHelper = new LivePreviewHelper();
  private syncPollTimer: number = -1;

  aboutToAppear(): void {
    this.vm.onErrorCallback = (msg: string) => { this.showToast(msg); };
    this.vm.onSaveCallback = (success: boolean) => {
      if (success) this.showToast('已保存');
    };
    this.vm.startIntervalSave();
    this.loadSyncStatus();
    this.startSyncPoll();
  }

  aboutToDisappear(): void {
    this.stopSyncPoll();
    this.vm.flushToDisk();
    this.vm.stopIntervalSave();
  }

  private buildPreviewBlocks(): ContentBlock[] {
    return extractMermaidBlocks(this.vm.content);
  }

  private showToast(message: string): void {
    try {
      promptAction.showToast({ message: message, duration: 2000 });
    } catch (e) {
      console.error('Toast error: ' + JSON.stringify(e));
    }
  }

  private async loadSyncStatus(): Promise<void> {
    try {
      this.syncStatus = await syncService.getStatus();
    } catch (e) {
      console.error('Sync status load error: ' + JSON.stringify(e));
    }
  }

  private startSyncPoll(): void {
    if (this.syncPollTimer !== -1) return;
    this.syncPollTimer = setInterval(() => { this.loadSyncStatus(); }, 30000);
  }

  private stopSyncPoll(): void {
    if (this.syncPollTimer !== -1) {
      clearInterval(this.syncPollTimer); this.syncPollTimer = -1;
    }
  }

  private get colors(): ObsidianColors {
    return getColors(this.themeMode);
  }

  private get breadcrumbItems(): BreadcrumbItem[] {
    if (!this.vm.metadata) return [];
    const parts: string[] = this.vm.metadata.path.split('/').filter((p: string): boolean => p.length > 0);
    const items: BreadcrumbItem[] = [];
    for (let idx = 0; idx < parts.length; idx++) {
      const item: BreadcrumbItem = {
        name: parts[idx].replace('.md', ''), path: '/' + parts.slice(0, idx + 1).join('/'),
        isFile: idx === parts.length - 1
      };
      items.push(item);
    }
    return items;
  }

  private get viewModeLabel(): string {
    switch (this.viewMode) {
      case 'live': return '实时阅览';
      case 'source': return '源码';
      case 'preview': return '阅读';
      case 'split': return '分屏';
      default: return '实时阅览';
    }
  }

  // ─── 模式切换 ─────────────────────────────────

  private cycleViewMode(): void {
    if (this.viewMode === 'live') {
      this.viewMode = 'source';
    } else if (this.viewMode === 'source') {
      this.viewMode = 'preview';
    } else if (this.viewMode === 'preview') {
      this.viewMode = 'split';
    } else {
      this.viewMode = 'live';
    }
    if (this.viewMode === 'live' || this.viewMode === 'source') {
      this.rebuildEditor();
    }
  }

  // ─── RichEditor 核心逻辑 ──────────────────────

  private initEditor(): void {
    this.rebuildEditor();
  }

  // 内容变更时：提取纯文本 → 更新 VM → 重建 spans
  private async handleEditorChange(rangeBefore: RichEditorRange, rangeAfter: RichEditorRange): Promise<void> {
    if (this.livePreview.getIsRebuilding()) return;
    const text = LivePreviewHelper.extractText(this.richEditorController);
    if (text !== this.vm.content) {
      this.vm.updateContent(text);
      await this.checkCompletion();
    }
    this.rebuildEditor();
  }

  // 光标移动时：跟踪位置，重建 spans（实现光标感知的语法显隐）
  private handleSelectionChange(): void {
    if (this.livePreview.getIsRebuilding()) return;
    try {
      this.editorCaretOffset = this.richEditorController.getCaretOffset();
    } catch (e) {
      this.editorCaretOffset = -1;
    }
    // 仅当光标跨过语法段边界时才重建
    this.rebuildEditor();

    // 悬停预览：检测光标是否在 wikilink 上
    this.scheduleLinkPreview();
  }

  // 500ms 去抖检测光标所在的 wikilink
  private scheduleLinkPreview(): void {
    if (this.linkPreviewTimer !== -1) {
      clearTimeout(this.linkPreviewTimer);
    }
    this.showLinkPreview = false;
    this.linkPreviewTimer = setTimeout(() => {
      this.linkPreviewTimer = -1;
      this.detectAndShowLinkPreview();
    }, 500);
  }

  private async detectAndShowLinkPreview(): Promise<void> {
    const caret = this.editorCaretOffset;
    if (caret < 2) return;
    const text = this.vm.content;
    const textBefore = text.substring(0, caret);

    // 查找光标前的最近 [[
    const openIdx = textBefore.lastIndexOf('[[');
    if (openIdx === -1) return;

    // 查找闭合的 ]]，位置在光标之后
    const closeIdx = text.indexOf(']]', Math.max(caret, openIdx + 2));
    if (closeIdx === -1) return;

    // 提取链接目标
    const linkText = text.substring(openIdx + 2, closeIdx);
    if (!linkText || linkText.includes('\n')) return;

    // 去掉别名（[[target|display]] → target）
    const pipeIdx = linkText.indexOf('|');
    const targetName = pipeIdx !== -1 ? linkText.substring(0, pipeIdx) : linkText;

    // 加载预览数据
    try {
      const result = await fileService.readNote(targetName);
      const lines = result.content.trim().split('\n').filter((l: string) => l.trim());
      const snippet = lines.slice(0, 3).join('\n');
      this.linkPreviewData = {
        title: result.metadata.title || targetName,
        snippet: snippet,
        wordCount: result.metadata.wordCount
      };
      this.showLinkPreview = true;
    } catch (e) {
      // 目标笔记不存在
      this.linkPreviewData = {
        title: targetName + ' (不存在)',
        snippet: '目标笔记未找到',
        wordCount: 0
      };
      this.showLinkPreview = true;
    }
  }

  private rebuildEditor(): void {
    if (this.livePreview.getIsRebuilding()) return;
    if (this.viewMode === 'preview') return;

    const text = this.vm.content;
    const caret = this.editorCaretOffset;

    if (this.viewMode === 'live') {
      this.livePreview.buildSpans(this.richEditorController, text, caret);
      // 重建后恢复光标位置
      if (caret >= 0 && caret <= text.length) {
        this.richEditorController.setCaretOffset(caret);
      }
    } else {
      this.livePreview.buildSourceSpans(this.richEditorController, text);
      if (caret >= 0 && caret <= text.length) {
        this.richEditorController.setCaretOffset(caret);
      }
    }
  }

  // ─── 查找替换 ──────────────────────────────────

  private performFindSearch(query: string, caseSensitive: boolean): void {
    if (!query) {
      this.findMatches = [];
      this.findCurrentIndex = 0;
      return;
    }
    const text = this.vm.content;
    const searchText = caseSensitive ? text : text.toLowerCase();
    const searchQuery = caseSensitive ? query : query.toLowerCase();
    const matches: FindMatch[] = [];
    let lineNum = 0;
    for (let i = 0; i < text.length; i++) {
      if (text[i] === '\n') {
        lineNum++;
      }
      if (searchText.substring(i, i + searchQuery.length) === searchQuery) {
        matches.push({ start: i, end: i + searchQuery.length, line: lineNum + 1 });
      }
    }
    this.findMatches = matches;
    this.findCurrentIndex = matches.length > 0 ? 0 : -1;
    if (matches.length > 0) {
      this.navigateToMatch(0);
    }
  }

  private navigateToMatch(index: number): void {
    if (index < 0 || index >= this.findMatches.length) return;
    this.findCurrentIndex = index;
    const match = this.findMatches[index];
    try {
      this.richEditorController.setCaretOffset(match.start);
    } catch (e) {
      // ignore
    }
  }

  private findNavigate(direction: 'next' | 'prev'): void {
    if (this.findMatches.length === 0) return;
    let newIdx: number;
    if (direction === 'next') {
      newIdx = (this.findCurrentIndex + 1) % this.findMatches.length;
    } else {
      newIdx = this.findCurrentIndex <= 0
        ? this.findMatches.length - 1
        : this.findCurrentIndex - 1;
    }
    this.navigateToMatch(newIdx);
  }

  private replaceCurrent(replacement: string): void {
    if (this.findMatches.length === 0) return;
    const match = this.findMatches[this.findCurrentIndex];
    const text = this.vm.content;
    const newContent = text.substring(0, match.start) + replacement + text.substring(match.end);
    this.vm.content = newContent;
    this.vm.hasUnsavedChanges = true;
    this.rebuildEditor();
    this.performFindSearch(this.findMatches.length > 0 ? '' : '', false);
  }

  private replaceAll(replacement: string): void {
    if (this.findMatches.length === 0) return;
    let text = this.vm.content;
    const sorted = [...this.findMatches].sort((a: FindMatch, b: FindMatch) => b.start - a.start);
    for (const match of sorted) {
      text = text.substring(0, match.start) + replacement + text.substring(match.end);
    }
    this.vm.content = text;
    this.vm.hasUnsavedChanges = true;
    this.rebuildEditor();
    this.findMatches = [];
    this.findCurrentIndex = 0;
  }

  // ─── 图片 / 附件选择 ──────────────────────────

  private async handleInsertImage(): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const documentPicker = new picker.DocumentViewPicker(context);
      const options = new picker.DocumentSelectOptions();
      options.maxSelectNumber = 1;
      options.fileSuffixFilters = ['图片|.png,.jpg,.jpeg,.gif,.webp,.bmp'];
      documentPicker.select(options).then((uris: string[]) => {
        if (uris.length > 0) {
          const uri: string = uris[0];
          const fileName = uri.substring(uri.lastIndexOf('/') + 1);
          const mdImage = '![' + fileName + '](' + uri + ')';
          // 在光标处插入
          const caret = this.richEditorController.getCaretOffset();
          const txt = LivePreviewHelper.extractText(this.richEditorController);
          const before = txt.substring(0, caret);
          const after = txt.substring(caret);
          this.vm.content = before + mdImage + after;
          this.vm.hasUnsavedChanges = true;
          this.rebuildEditor();
          this.richEditorController.setCaretOffset(caret + mdImage.length);
          this.showToast('图片已插入');
        }
      }).catch((err: Error) => {
        this.showToast('选择图片失败');
      });
    } catch (e) {
      this.showToast('文件选择器不可用');
    }
  }

  private async handleInsertAttachment(): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const documentPicker = new picker.DocumentViewPicker(context);
      const options = new picker.DocumentSelectOptions();
      options.maxSelectNumber = 1;
      documentPicker.select(options).then((uris: string[]) => {
        if (uris.length > 0) {
          const uri: string = uris[0];
          const fileName = uri.substring(uri.lastIndexOf('/') + 1);
          const mdLink = '[' + fileName + '](' + uri + ')';
          const caret = this.richEditorController.getCaretOffset();
          const txt = LivePreviewHelper.extractText(this.richEditorController);
          const before = txt.substring(0, caret);
          const after = txt.substring(caret);
          this.vm.content = before + mdLink + after;
          this.vm.hasUnsavedChanges = true;
          this.rebuildEditor();
          this.richEditorController.setCaretOffset(caret + mdLink.length);
          this.showToast('附件已插入');
        }
      }).catch((err: Error) => {
        this.showToast('选择附件失败');
      });
    } catch (e) {
      this.showToast('文件选择器不可用');
    }
  }

  // ─── 自动补全 ──────────────────────────────────

  private noteNamesCache: string[] = [];

  private async checkCompletion(): Promise<void> {
    if (!this.vm.content) { this.showCompletions = false; return; }

    // 获取光标所在行
    const caret = this.editorCaretOffset >= 0
      ? this.editorCaretOffset
      : this.vm.content.length;
    const textBeforeCursor = this.vm.content.substring(0, caret);
    const linesBefore = textBeforeCursor.split('\n');
    const currentLine = linesBefore[linesBefore.length - 1];

    // 确定需要哪些补全数据
    let noteNames: string[] | undefined = undefined;
    if (currentLine.trimStart().startsWith('[[')) {
      // 加载笔记名缓存
      try {
        if (this.noteNamesCache.length === 0) {
          this.noteNamesCache = await fileService.getAllNoteFileNames();
        }
        noteNames = this.noteNamesCache;
      } catch (e) {
        noteNames = [];
      }
    }

    if (shouldShowCompletion(currentLine)) {
      this.completions = getCompletions(currentLine, currentLine, noteNames);
      this.showCompletions = this.completions.length > 0;
    } else {
      this.showCompletions = false;
    }
  }

  private applyCompletion(item: CompletionItem): void {
    const caret = this.editorCaretOffset >= 0
      ? this.editorCaretOffset
      : this.vm.content.length;
    const textBeforeCursor = this.vm.content.substring(0, caret);
    const textAfterCursor = this.vm.content.substring(caret);

    // 检查是否是 wikilink 补全（光标前有 [[）
    const wikiMatch = textBeforeCursor.match(/\[\[([^\]]*)$/);
    if (wikiMatch) {
      // 替换 [[partial 为 [[completed]]
      const beforeWiki = textBeforeCursor.substring(0, textBeforeCursor.length - wikiMatch[0].length);
      this.vm.content = beforeWiki + item.insertText + textAfterCursor;
      this.vm.hasUnsavedChanges = true;
      this.showCompletions = false;
      this.completions = [];
      this.noteNamesCache = [];
      this.rebuildEditor();
      // 光标定位到 ]] 之后
      const newCaret = beforeWiki.length + item.insertText.length;
      if (newCaret <= this.vm.content.length) {
        this.richEditorController.setCaretOffset(newCaret);
      }
      return;
    }

    // 常规补全：替换当前行的触发文本
    const lines = this.vm.content.split('\n');
    const linesBeforeCaret = textBeforeCursor.split('\n');
    const cursorLineIndex = linesBeforeCaret.length - 1;
    const lastLine = lines[cursorLineIndex];
    const trimmed = lastLine.trimStart();
    const indent = lastLine.slice(0, lastLine.length - trimmed.length);
    const newLine = indent + item.insertText;
    lines[cursorLineIndex] = newLine;
    this.vm.content = lines.join('\n');
    this.vm.hasUnsavedChanges = true;
    this.showCompletions = false;
    this.completions = [];
    this.rebuildEditor();
  }

  build() {
    Stack() {
      Column({ space: 0 }) {
        Breadcrumb({
          items: this.breadcrumbItems,
          currentFile: this.vm.hasUnsavedChanges ? this.vm.title : ''
        }).width('100%')

        // 工具栏
        Row({ space: 8 }) {
          // 历史导航
          Button({ type: ButtonType.Circle }) {
            Text('←').fontSize(14).fontColor(this.colors.iconSecondary)
          }
          .width(28).height(28).backgroundColor(this.colors.bgHover)
          .onClick(() => { if (this.onNavigateBack) this.onNavigateBack(); })

          Button({ type: ButtonType.Circle }) {
            Text('→').fontSize(14).fontColor(this.colors.iconSecondary)
          }
          .width(28).height(28).backgroundColor(this.colors.bgHover)
          .onClick(() => { if (this.onNavigateForward) this.onNavigateForward(); })

          Divider().vertical(true).height(20).color(this.colors.divider)

          Button({ type: ButtonType.Normal }) {
            Text(this.viewModeLabel)
              .fontSize(12).fontColor(this.colors.accent).fontWeight(FontWeight.Medium)
          }
          .backgroundColor(this.colors.bgHover).borderRadius(4).height(28).padding({ left: 8, right: 8 })
          .onClick(() => this.cycleViewMode())

          Divider().vertical(true).height(20).color(this.colors.divider)

          Button({ type: ButtonType.Circle }) {
            Text('B').fontSize(14).fontWeight(FontWeight.Bold).fontColor(this.colors.textSecondary)
          }.width(28).height(28).backgroundColor(this.colors.bgHover)
          Button({ type: ButtonType.Circle }) {
            Text('I').fontSize(14).fontStyle(FontStyle.Italic).fontColor(this.colors.textSecondary)
          }.width(28).height(28).backgroundColor(this.colors.bgHover)
          Button({ type: ButtonType.Circle }) {
            Text('H').fontSize(14).fontColor(this.colors.textSecondary)
          }.width(28).height(28).backgroundColor(this.colors.bgHover)

          Divider().vertical(true).height(20).color(this.colors.divider)

          Button({ type: ButtonType.Circle }) {
            Text('🖼').fontSize(14).fontColor(this.colors.textSecondary)
          }.width(28).height(28).backgroundColor(this.colors.bgHover).onClick(() => this.handleInsertImage())
          Button({ type: ButtonType.Circle }) {
            Text('📎').fontSize(14).fontColor(this.colors.textSecondary)
          }.width(28).height(28).backgroundColor(this.colors.bgHover).onClick(() => this.handleInsertAttachment())

          Blank()

          Button({ type: ButtonType.Circle }) {
            Text('📋').fontSize(14).fontColor(this.showProperties ? this.colors.accent : this.colors.textSecondary)
          }.width(28).height(28).backgroundColor(this.colors.bgHover).onClick(() => { this.showProperties = !this.showProperties; })
          Button({ type: ButtonType.Circle }) {
            Text(this.vm.isSaving ? '⟳' : '💾').fontSize(14)
              .fontColor(this.vm.hasUnsavedChanges ? this.colors.accent : this.colors.textSecondary)
          }.width(28).height(28).backgroundColor(this.colors.bgHover).onClick(() => this.vm.saveNote())
        }
        .width('100%').height(40).padding({ left: 12, right: 12 })
        .backgroundColor(this.colors.editorBg).border({ width: { bottom: 1 }, color: this.colors.divider })

        // 自动补全面板
        if (this.showCompletions && this.completions.length > 0) {
          Scroll() {
            Row() {
              ForEach(this.completions, (item: CompletionItem) => {
                Button() {
                  Column() {
                    Text(item.label).fontSize(14).fontColor(this.colors.accent).fontWeight(FontWeight.Medium)
                      .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                    Text(item.description).fontSize(11).fontColor(this.colors.textMuted).maxLines(1)
                  }.alignItems(HorizontalAlign.Start).padding({ left: 10, right: 10 })
                }
                .height(44).backgroundColor(this.colors.bgSecondary).borderRadius(10)
                .border({ width: 1, color: this.colors.divider, style: BorderStyle.Solid }).margin({ right: 8 })
                .onClick(() => this.applyCompletion(item))
              }, (item: CompletionItem) => item.label)
            }.padding({ left: 4, right: 4 })
          }
          .scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)
          .width('100%').height(52).backgroundColor(this.colors.editorBg).padding({ left: 12, right: 12 })
        }

        // 查找替换栏
        if (this.showFindReplace) {
          FindReplaceBar({
            matchCount: this.findMatches.length,
            currentIndex: this.findCurrentIndex,
            onSearch: (query: string, caseSensitive: boolean) => {
              this.performFindSearch(query, caseSensitive);
            },
            onNavigate: (direction: 'next' | 'prev') => {
              this.findNavigate(direction);
            },
            onReplace: (replacement: string) => {
              this.replaceCurrent(replacement);
            },
            onReplaceAll: (replacement: string) => {
              this.replaceAll(replacement);
            },
            onClose: () => {
              this.showFindReplace = false;
            }
          })
        }

        // 主体内容区
        Row({ space: 0 }) {
          Column() {
            if (this.viewMode === 'live' || this.viewMode === 'source') {
              // LIVE / SOURCE 共用 RichEditor
              RichEditor({ controller: this.richEditorController })
                .onReady(() => { this.initEditor(); })
                .onDidChange((rangeBefore: RichEditorRange, rangeAfter: RichEditorRange) => {
                  this.handleEditorChange(rangeBefore, rangeAfter);
                })
                .onSelectionChange((range: RichEditorRange) => {
                  this.handleSelectionChange();
                })
                .onKeyEvent((event: KeyEvent) => {
                  const KEYCODE_ESCAPE = 2070;
                  const KEYCODE_ENTER = 2054;
                  const KEYCODE_F = 2023;

                  // Ctrl+F 或 仅F 打开查找
                  if (event.type === KeyType.Down && event.keyCode === KEYCODE_F) {
                    this.showFindReplace = !this.showFindReplace;
                    return true;
                  }
                  // Esc 关闭查找栏或补全
                  if (event.type === KeyType.Down && event.keyCode === KEYCODE_ESCAPE) {
                    if (this.showCompletions && this.completions.length > 0) {
                      this.showCompletions = false;
                      this.completions = [];
                      return true;
                    }
                    if (this.showFindReplace) {
                      this.showFindReplace = false;
                      return true;
                    }
                  }
                  // Enter 导航下一个匹配
                  if (event.type === KeyType.Down && event.keyCode === KEYCODE_ENTER && this.showFindReplace && this.findMatches.length > 0) {
                    this.findNavigate('next');
                    return true;
                  }
                  return false;
                })
                .caretColor('#8B5CF6')
                .borderRadius(12)
                .padding(16)
                .width('100%').layoutWeight(1)
                .margin({ left: 20, right: 20 })
            } else if (this.viewMode === 'preview') {
              // 阅读模式：MarkdownToHtml + Mermaid WebView 混合渲染
              Scroll() {
                Column({ space: 12 }) {
                  Text(this.vm.title).fontSize(28).fontWeight(FontWeight.Bold).fontColor(this.colors.textPrimary)
                    .width('100%').margin({ bottom: 16 })
                  // 按块渲染：Markdown 文本 + Mermaid 图表交替
                  ForEach(this.buildPreviewBlocks(), (block: ContentBlock) => {
                    if (block.type === 'mermaid') {
                      MermaidWebView({ mermaidCode: block.content, themeMode: this.themeMode })
                        .width('100%')
                    } else {
                      Text(markdownToHtml(block.content)).fontSize(14).fontColor(this.colors.textPrimary)
                        .width('100%').lineHeight(24)
                    }
                  }, (block: ContentBlock, index: number): string => index.toString())
                }.width('100%').padding(24)
              }.width('100%').height('100%').scrollBar(BarState.Auto)
            } else {
              // 分屏模式：左编辑右预览
              SplitView({ vm: this.vm })
                .width('100%').layoutWeight(1)
            }
          }.width('100%').layoutWeight(1)

          if (this.showProperties && this.vm.metadata) {
            PropertiesPanel({
              metadata: this.vm.metadata,
              onUpdate: (key: string, value: string | number | boolean | string[]) => {
                this.vm.updateFrontmatter(key, value);
              },
              onAddProperty: (key: string, value: string | number | boolean | string[]) => {
                this.vm.updateFrontmatter(key, value);
              }
            }).width(240).height('100%').border({ width: { left: 1 }, color: this.colors.divider })
          }
        }.width('100%').layoutWeight(1)

        StatusBar({
          wordCount: this.vm.getWordCount(), charCount: this.vm.getCharCount(),
          readTime: this.vm.getReadingTime(), cursorLine: 1, cursorCol: 1,
          syncStatus: this.syncStatus, currentView: this.viewMode,
          onViewChange: (view: string) => this.viewMode = view
        }).width('100%')
      }
      .width('100%').height('100%').backgroundColor(this.colors.editorBg)

      Modal({
        config: this.modalConfig, isVisible: this.showModal,
        onConfirm: () => { this.showModal = false; },
        onCancel: () => { this.showModal = false; }
      })

      // 链接预览卡片
      LinkPreviewCard({
        data: this.linkPreviewData,
        visible: this.showLinkPreview,
        onOpenNote: () => {
          // 在当前标签页打开
          const targetName = this.linkPreviewData.title;
          // 通知父组件打开笔记的逻辑由 onOpenNote 处理
          this.showLinkPreview = false;
        },
        onClose: () => {
          this.showLinkPreview = false;
          if (this.linkPreviewTimer !== -1) {
            clearTimeout(this.linkPreviewTimer);
            this.linkPreviewTimer = -1;
          }
        }
      }).position({ x: 20, y: 60 })
    }.width('100%').height('100%')
  }
}
