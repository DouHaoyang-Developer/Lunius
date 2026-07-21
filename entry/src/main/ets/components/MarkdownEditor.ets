import { picker } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { LuniusColors, ThemeMode, getColors, Spacing, Radius, Icons } from '../utils/Theme';
import { NoteViewModel } from '../viewmodels/NoteViewModel';
import { Breadcrumb, BreadcrumbItem } from './breadcrumb/Breadcrumb';
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
import { RemoteCursorState } from '../models/CollaborationTypes';

interface CursorPos {
  line: number;
  col: number;
}

@Component
export struct MarkdownEditor {
  @StorageLink('themeMode') themeMode: ThemeMode = ThemeMode.DARK;
  @ObjectLink vm: NoteViewModel;
  @Prop isSplitView: boolean = false;
  @Prop canNavigateBack: boolean = false;
  @Prop canNavigateForward: boolean = false;
  @Prop isMobileMode: boolean = false;
  @State viewMode: string = 'live';
  @State showProperties: boolean = false;
  @State showModal: boolean = false;
  @State modalConfig: ModalConfig = { title: '', message: '', type: 'alert' };
  @State completions: CompletionItem[] = [];
  @State showCompletions: boolean = false;
  @State syncStatus: SyncStatus | null = null;
  @State editorCaretOffset: number = -1;
  @State showLinkPreview: boolean = false;
  @State linkPreviewData: LinkPreviewData = { title: '', snippet: '', wordCount: 0 };
  @State showFindReplace: boolean = false;
  @State findMatches: FindMatch[] = [];
  @State findCurrentIndex: number = 0;
  @State remoteCursors: RemoteCursorState[] = [];
  @State previewBlocks: ContentBlock[] = [];
  onNavigateBack?: () => void;
  onNavigateForward?: () => void;

  private richEditorController: RichEditorController = new RichEditorController();
  private linkPreviewTimer: number = -1;
  private livePreview: LivePreviewHelper = new LivePreviewHelper();
  private syncPollTimer: number = -1;
  private noteNamesCache: string[] = [];

  aboutToAppear(): void {
    this.vm.onErrorCallback = (msg: string) => { this.showToast(msg); };
    this.vm.onSaveCallback = (_success: boolean) => { this.showToast('\u5DF2\u4FDD\u5B58'); };
    this.vm.onRemoteCursorsChanged = (cursors: RemoteCursorState[]) => {
      this.remoteCursors = cursors;
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

  private colors(): LuniusColors {
    return getColors(this.themeMode);
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({
        message: message, duration: 2000
      });
    } catch (e) {
      console.error('Toast error');
    }
  }

  private async loadSyncStatus(): Promise<void> {
    try {
      this.syncStatus = await syncService.getStatus();
    } catch (e) {
      // offline
    }
  }

  private startSyncPoll(): void {
    if (this.syncPollTimer !== -1) return;
    this.syncPollTimer = setInterval(() => { this.loadSyncStatus(); }, 30000);
  }

  private stopSyncPoll(): void {
    if (this.syncPollTimer !== -1) {
      clearInterval(this.syncPollTimer);
      this.syncPollTimer = -1;
    }
  }

  private breadcrumbItems(): BreadcrumbItem[] {
    if (!this.vm.metadata) return [];
    const parts = this.vm.metadata.path.split('/').filter((p: string) => p.length > 0);
    const items: BreadcrumbItem[] = [];
    for (let idx = 0; idx < parts.length; idx++) {
      items.push({
        name: parts[idx].replace('.md', ''),
        path: '/' + parts.slice(0, idx + 1).join('/'),
        isFile: idx === parts.length - 1
      });
    }
    return items;
  }

  private async buildPreviewBlocks(): Promise<void> {
    const blocks = extractMermaidBlocks(this.vm.content);
    for (let i = 0; i < blocks.length; i++) {
      if (blocks[i].type === 'markdown') {
        const b = blocks[i];
        b.rendered = await markdownToHtml(b.content);
      }
    }
    this.previewBlocks = blocks;
  }

  // ─── View mode cycling ─────────────────────

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
    if (this.viewMode === 'preview') {
      this.buildPreviewBlocks();
    }
  }

  private viewModeLabel(): string {
    if (this.viewMode === 'live') return '\u5B9E\u65F6\u9605\u89C8';
    if (this.viewMode === 'source') return '\u6E90\u7801';
    if (this.viewMode === 'preview') return '\u9605\u8BFB';
    return '\u5206\u5C4F';
  }

  // ─── Cursor → line:col conversion ─────────

  private cursorLineCol(): CursorPos {
    const caret = this.editorCaretOffset;
    if (caret < 0 || !this.vm.content) {
      const defaultPos: CursorPos = { line: 1, col: 1 };
      return defaultPos;
    }
    const text = this.vm.content.substring(0, caret);
    const lines = text.split('\n');
    const result: CursorPos = { line: lines.length, col: lines[lines.length - 1].length + 1 };
    return result;
  }

  // ─── Editor change handling ────────────────

  private async handleEditorChange(
    _rangeBefore: RichEditorRange, _rangeAfter: RichEditorRange
  ): Promise<void> {
    if (this.livePreview.getIsRebuilding()) return;
    const text = LivePreviewHelper.extractText(this.richEditorController);
    if (text !== this.vm.content) {
      this.vm.updateContent(text);
      await this.checkCompletion();
    }
    if (this.viewMode !== 'preview') {
      this.rebuildSpans();
    }
  }

  private handleSelectionChange(): void {
    if (this.livePreview.getIsRebuilding()) return;
    try {
      this.editorCaretOffset = this.richEditorController.getCaretOffset();
    } catch (e) {
      this.editorCaretOffset = -1;
    }
    this.scheduleLinkPreview();
  }

  private rebuildSpans(): void {
    if (this.livePreview.getIsRebuilding()) return;
    const text = this.vm.content;
    const caret = this.editorCaretOffset;
    if (this.viewMode === 'live') {
      this.livePreview.buildSpans(this.richEditorController, text, caret);
    } else {
      this.livePreview.buildSourceSpans(this.richEditorController, text);
    }
    if (caret >= 0 && caret <= text.length) {
      this.richEditorController.setCaretOffset(caret);
    }
  }

  // ─── Link preview ──────────────────────────

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
    const openIdx = textBefore.lastIndexOf('[[');
    if (openIdx === -1) return;
    const closeIdx = text.indexOf(']]', Math.max(caret, openIdx + 2));
    if (closeIdx === -1) return;
    const linkText = text.substring(openIdx + 2, closeIdx);
    if (!linkText || linkText.includes('\n')) return;
    const pipeIdx = linkText.indexOf('|');
    const targetName = pipeIdx !== -1 ? linkText.substring(0, pipeIdx) : linkText;

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
      this.linkPreviewData = {
        title: targetName + ' (\u4E0D\u5B58\u5728)',
        snippet: '\u76EE\u6807\u7B14\u8BB0\u672A\u627E\u5230',
        wordCount: 0
      };
      this.showLinkPreview = true;
    }
  }

  // ─── Find / Replace ────────────────────────

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
      if (text[i] === '\n') { lineNum++; }
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
        ? this.findMatches.length - 1 : this.findCurrentIndex - 1;
    }
    this.navigateToMatch(newIdx);
  }

  private replaceCurrent(replacement: string): void {
    if (this.findMatches.length === 0) return;
    const match = this.findMatches[this.findCurrentIndex];
    const text = this.vm.content;
    const newContent = text.substring(0, match.start) + replacement
      + text.substring(match.end);
    this.vm.content = newContent;
    this.vm.hasUnsavedChanges = true;
    this.rebuildSpans();
    this.performFindSearch('', false);
  }

  private replaceAll(replacement: string): void {
    if (this.findMatches.length === 0) return;
    let text = this.vm.content;
    const sorted = [...this.findMatches].sort(
      (a: FindMatch, b: FindMatch) => b.start - a.start
    );
    for (const match of sorted) {
      text = text.substring(0, match.start) + replacement
        + text.substring(match.end);
    }
    this.vm.content = text;
    this.vm.hasUnsavedChanges = true;
    this.rebuildSpans();
    this.findMatches = [];
    this.findCurrentIndex = 0;
  }

  // ─── Completions ───────────────────────────

  private async checkCompletion(): Promise<void> {
    if (!this.vm.content) { this.showCompletions = false; return; }
    const caret = this.editorCaretOffset >= 0
      ? this.editorCaretOffset : this.vm.content.length;
    const textBeforeCursor = this.vm.content.substring(0, caret);
    const linesBefore = textBeforeCursor.split('\n');
    const currentLine = linesBefore[linesBefore.length - 1];

    let noteNames: string[] | undefined = undefined;
    if (currentLine.trimStart().startsWith('[[')) {
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
      ? this.editorCaretOffset : this.vm.content.length;
    const textBeforeCursor = this.vm.content.substring(0, caret);
    const textAfterCursor = this.vm.content.substring(caret);

    const wikiMatch = textBeforeCursor.match(/\[\[([^\]]*)$/);
    if (wikiMatch) {
      const beforeWiki = textBeforeCursor.substring(0,
        textBeforeCursor.length - wikiMatch[0].length);
      this.vm.content = beforeWiki + item.insertText + textAfterCursor;
      this.vm.hasUnsavedChanges = true;
      this.showCompletions = false;
      this.completions = [];
      this.noteNamesCache = [];
      this.rebuildSpans();
      const newCaret = beforeWiki.length + item.insertText.length;
      if (newCaret <= this.vm.content.length) {
        this.richEditorController.setCaretOffset(newCaret);
      }
      return;
    }

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
    this.rebuildSpans();
  }

  // ─── Image / Attachment insertion ──────────

  private async handleInsertImage(): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const documentPicker = new picker.DocumentViewPicker(context);
      const options = new picker.DocumentSelectOptions();
      options.maxSelectNumber = 1;
      options.fileSuffixFilters = ['\u56FE\u7247|.png,.jpg,.jpeg,.gif,.webp,.bmp'];
      documentPicker.select(options).then((uris: string[]) => {
        if (uris.length > 0) {
          const uri = uris[0];
          const fileName = uri.substring(uri.lastIndexOf('/') + 1);
          const mdImage = '![' + fileName + '](' + uri + ')';
          const caret = this.richEditorController.getCaretOffset();
          const txt = LivePreviewHelper.extractText(this.richEditorController);
          this.vm.content = txt.substring(0, caret) + mdImage + txt.substring(caret);
          this.vm.hasUnsavedChanges = true;
          this.rebuildSpans();
          this.richEditorController.setCaretOffset(caret + mdImage.length);
          this.showToast('\u56FE\u7247\u5DF2\u63D2\u5165');
        }
      }).catch(() => { this.showToast('\u9009\u62E9\u56FE\u7247\u5931\u8D25'); });
    } catch (e) {
      this.showToast('\u6587\u4EF6\u9009\u62E9\u5668\u4E0D\u53EF\u7528');
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
          const uri = uris[0];
          const fileName = uri.substring(uri.lastIndexOf('/') + 1);
          const mdLink = '[' + fileName + '](' + uri + ')';
          const caret = this.richEditorController.getCaretOffset();
          const txt = LivePreviewHelper.extractText(this.richEditorController);
          this.vm.content = txt.substring(0, caret) + mdLink + txt.substring(caret);
          this.vm.hasUnsavedChanges = true;
          this.rebuildSpans();
          this.richEditorController.setCaretOffset(caret + mdLink.length);
          this.showToast('\u9644\u4EF6\u5DF2\u63D2\u5165');
        }
      }).catch(() => { this.showToast('\u9009\u62E9\u9644\u4EF6\u5931\u8D25'); });
    } catch (e) {
      this.showToast('\u6587\u4EF6\u9009\u62E9\u5668\u4E0D\u53EF\u7528');
    }
  }

  build() {
    Stack() {
      Column({ space: 0 }) {
        if (!this.isMobileMode) {
          Breadcrumb({
            items: this.breadcrumbItems(),
            hasModified: this.vm.hasUnsavedChanges
          }).width('100%')
        }

        if (!this.isMobileMode) {
          Row({ space: Spacing.SM }) {
            // 导航组
            Column() {
              Text(Icons.BACK)
                .fontSize(13)
                .fontColor(this.canNavigateBack
                  ? this.colors().textSecondary : this.colors().textDisabled)
            }
            .width(28).height(28)
            .justifyContent(FlexAlign.Center)
            .borderRadius(Radius.SM)
            .onClick(() => { if (this.onNavigateBack) this.onNavigateBack(); })

            Column() {
              Text(Icons.FORWARD)
                .fontSize(13)
                .fontColor(this.canNavigateForward
                  ? this.colors().textSecondary : this.colors().textDisabled)
            }
            .width(28).height(28)
            .justifyContent(FlexAlign.Center)
            .borderRadius(Radius.SM)
            .onClick(() => { if (this.onNavigateForward) this.onNavigateForward(); })

            // 分隔线
            Divider().vertical(true).height(16).color(this.colors().border)

            // 视图模式切换
            Row({ space: 0 }) {
              Text(this.viewModeLabel())
                .fontSize(12)
                .fontColor(this.colors().accent)
                .fontWeight(FontWeight.Medium)
            }
            .height(28)
            .padding({ left: Spacing.SM, right: Spacing.SM })
            .backgroundColor(this.colors().surface2)
            .borderRadius(Radius.SM)
            .onClick(() => this.cycleViewMode())

            // 分隔线
            Divider().vertical(true).height(16).color(this.colors().border)

            // 格式化按钮组
            Column() {
              Text('B')
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.colors().textSecondary)
            }
            .width(28).height(28)
            .justifyContent(FlexAlign.Center)
            .borderRadius(Radius.SM)

            Column() {
              Text('I')
                .fontSize(14)
                .fontStyle(FontStyle.Italic)
                .fontColor(this.colors().textSecondary)
            }
            .width(28).height(28)
            .justifyContent(FlexAlign.Center)
            .borderRadius(Radius.SM)

            Column() {
              Text('H')
                .fontSize(14)
                .fontColor(this.colors().textSecondary)
            }
            .width(28).height(28)
            .justifyContent(FlexAlign.Center)
            .borderRadius(Radius.SM)

            // 分隔线
            Divider().vertical(true).height(16).color(this.colors().border)

            // 插入组
            Column() {
              Text(Icons.IMAGE)
                .fontSize(13)
                .fontColor(this.colors().textSecondary)
            }
            .width(28).height(28)
            .justifyContent(FlexAlign.Center)
            .borderRadius(Radius.SM)
            .onClick(() => this.handleInsertImage())

            Column() {
              Text(Icons.ATTACHMENT)
                .fontSize(13)
                .fontColor(this.colors().textSecondary)
            }
            .width(28).height(28)
            .justifyContent(FlexAlign.Center)
            .borderRadius(Radius.SM)
            .onClick(() => this.handleInsertAttachment())

            Blank()

            // 属性面板 + 保存
            Column() {
              Text(Icons.PROPERTIES)
                .fontSize(13)
                .fontColor(this.showProperties
                  ? this.colors().accent : this.colors().textSecondary)
            }
            .width(28).height(28)
            .justifyContent(FlexAlign.Center)
            .borderRadius(Radius.SM)
            .backgroundColor(this.showProperties
              ? this.colors().accentSubtle : Color.Transparent)
            .onClick(() => { this.showProperties = !this.showProperties; })

            Column() {
              Text(this.vm.isSaving ? Icons.LOADING : Icons.SAVE)
                .fontSize(13)
                .fontColor(this.vm.hasUnsavedChanges
                  ? this.colors().accent : this.colors().textSecondary)
            }
            .width(28).height(28)
            .justifyContent(FlexAlign.Center)
            .borderRadius(Radius.SM)
            .onClick(() => this.vm.saveNote())
          }
          .width('100%').height(40)
          .padding({ left: Spacing.MD, right: Spacing.MD })
          .backgroundColor(this.colors().surface0)
          .border({ width: { bottom: 1 }, color: this.colors().border })
        }

        if (this.showCompletions && this.completions.length > 0) {
          Scroll() {
            Row() {
              ForEach(this.completions, (item: CompletionItem) => {
                Button() {
                  Column() {
                    Text(item.label)
                      .fontSize(14).fontColor(this.colors().accent)
                      .fontWeight(FontWeight.Medium)
                      .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                    Text(item.description)
                      .fontSize(11).fontColor(this.colors().textTertiary).maxLines(1)
                  }.alignItems(HorizontalAlign.Start)
                    .padding({ left: 10, right: 10 })
                }
                .height(44).backgroundColor(this.colors().surface2)
                .borderRadius(Radius.MD)
                .border({ width: 1, color: this.colors().border })
                .margin({ right: Spacing.SM })
                .onClick(() => this.applyCompletion(item))
              }, (item: CompletionItem) => item.label)
            }.padding({ left: Spacing.XS, right: Spacing.XS })
          }
          .scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)
          .width('100%').height(52)
          .backgroundColor(this.colors().surface0)
          .padding({ left: Spacing.MD, right: Spacing.MD })
        }

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
            onClose: () => { this.showFindReplace = false; }
          })
        }

        Row({ space: 0 }) {
          Column() {
            if (this.viewMode === 'live' || this.viewMode === 'source') {
              RichEditor({ controller: this.richEditorController })
                .onReady(() => { this.rebuildSpans(); })
                .onDidChange((
                  rangeBefore: RichEditorRange, rangeAfter: RichEditorRange
                ) => {
                  this.handleEditorChange(rangeBefore, rangeAfter);
                })
                .onSelectionChange(() => {
                  this.handleSelectionChange();
                })
                .onKeyEvent((event: KeyEvent) => {
                  const KEY_F = 2023;
                  const KEY_ESC = 2070;
                  const KEY_ENTER = 2054;

                  if (event.type === KeyType.Down && event.keyCode === KEY_F) {
                    this.showFindReplace = !this.showFindReplace;
                    return true;
                  }
                  if (event.type === KeyType.Down && event.keyCode === KEY_ESC) {
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
                  if (event.type === KeyType.Down && event.keyCode === KEY_ENTER
                      && this.showFindReplace && this.findMatches.length > 0) {
                    this.findNavigate('next');
                    return true;
                  }
                  return false;
                })
                .caretColor(this.colors().accent)
                .borderRadius(Radius.LG)
                .padding(Spacing.LG)
                .width('100%').layoutWeight(1)
                .margin({ left: 20, right: 20 })
            } else if (this.viewMode === 'preview') {
              Scroll() {
                Column({ space: Spacing.MD }) {
                  Text(this.vm.title)
                    .fontSize(28).fontWeight(FontWeight.Bold)
                    .fontColor(this.colors().textPrimary)
                    .width('100%').margin({ bottom: Spacing.LG })

                  ForEach(this.previewBlocks, (block: ContentBlock) => {
                    if (block.type === 'mermaid') {
                      MermaidWebView({
                        mermaidCode: block.content,
                        themeMode: this.themeMode
                      }).width('100%')
                    } else {
                      Text(block.rendered)
                        .fontSize(14).fontColor(this.colors().textPrimary)
                        .width('100%').lineHeight(24)
                    }
                  }, (block: ContentBlock, index: number): string =>
                    String(index))
                }.width('100%').padding(Spacing.XL)
              }.width('100%').height('100%').scrollBar(BarState.Auto)
            } else {
              SplitView({ vm: this.vm })
                .width('100%').layoutWeight(1)
            }
          }.width('100%').layoutWeight(1)

          if (this.vm.isCollaborating && this.remoteCursors.length > 0) {
            Row({ space: 0 }) {
              ForEach(this.remoteCursors, (cursor: RemoteCursorState) => {
                Row({ space: 6 }) {
                  Circle({ width: 6, height: 6 }).fill(cursor.color)
                  Text(cursor.deviceName)
                    .fontSize(10).fontColor(cursor.color).maxLines(1)
                }
                .padding({ left: Spacing.SM, right: Spacing.SM, top: 3, bottom: 3 })
                .backgroundColor(this.colors().surface1)
                .borderRadius(Radius.SM)
                .margin({ left: Spacing.XS })
              }, (cursor: RemoteCursorState) => cursor.deviceId)
            }
            .width('100%').height(24)
            .padding({ left: Spacing.SM, right: Spacing.SM })
            .backgroundColor(this.colors().surface2)
            .border({ width: { top: 1 }, color: this.colors().border })
          }

          if (this.showProperties && this.vm.metadata) {
            PropertiesPanel({
              metadata: this.vm.metadata,
              onUpdate: (key: string, value: string | number | boolean | string[]) => {
                this.vm.updateFrontmatter(key, value);
              },
              onAddProperty: (key: string, value: string | number | boolean | string[]) => {
                this.vm.updateFrontmatter(key, value);
              }
            })
            .width(240).height('100%')
            .border({ width: { left: 1 }, color: this.colors().border })
          }
        }.width('100%').layoutWeight(1)

        if (!this.isMobileMode) {
          StatusBar({
            wordCount: this.vm.getWordCount(),
            charCount: this.vm.getCharCount(),
            readTime: this.vm.getReadingTime(),
            cursorLine: this.cursorLineCol().line,
            cursorCol: this.cursorLineCol().col,
            syncStatus: this.syncStatus,
            currentView: this.viewMode,
            onViewChange: (view: string) => { this.viewMode = view; }
          }).width('100%')
        }
      }
      .width('100%').height('100%')
      .backgroundColor(this.colors().surface0)

      Modal({
        config: this.modalConfig,
        isVisible: this.showModal,
        onConfirm: () => { this.showModal = false; },
        onCancel: () => { this.showModal = false; }
      })

      LinkPreviewCard({
        data: this.linkPreviewData,
        visible: this.showLinkPreview,
        onOpenNote: () => { this.showLinkPreview = false; },
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
