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
import { syncService } from '../services/ISyncService';
import { SyncStatus } from '../services/ApiTypes';

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
  @State viewMode: string = 'live';
  @State showProperties: boolean = false;
  @State showModal: boolean = false;
  @State modalConfig: ModalConfig = { title: '', message: '', type: 'alert' };
  @State completions: CompletionItem[] = [];
  @State showCompletions: boolean = false;
  @State syncStatus: SyncStatus | null = null;
  @State editorCaretOffset: number = -1;

  private richEditorController: RichEditorController = new RichEditorController();
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
  private handleEditorChange(rangeBefore: RichEditorRange, rangeAfter: RichEditorRange): void {
    if (this.livePreview.getIsRebuilding()) return;
    const text = LivePreviewHelper.extractText(this.richEditorController);
    if (text !== this.vm.content) {
      this.vm.updateContent(text);
      this.checkCompletion();
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

  private checkCompletion(): void {
    if (!this.vm.content) { this.showCompletions = false; return; }
    const lines = this.vm.content.split('\n');
    const lastLine = lines[lines.length - 1];
    if (shouldShowCompletion(lastLine)) {
      this.completions = getCompletions(lastLine, lastLine);
      this.showCompletions = this.completions.length > 0;
    } else {
      this.showCompletions = false;
    }
  }

  private applyCompletion(item: CompletionItem): void {
    const lines = this.vm.content.split('\n');
    const lastLine = lines[lines.length - 1];
    const trimmed = lastLine.trimStart();
    const indent = lastLine.slice(0, lastLine.length - trimmed.length);
    const beforeReplace = lines.slice(0, -1).join('\n');
    const newLastLine = indent + item.insertText;
    this.vm.content = lines.length > 1 ? beforeReplace + '\n' + newLastLine : newLastLine;
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
                .caretColor('#8B5CF6')
                .borderRadius(12)
                .padding(16)
                .width('100%').layoutWeight(1)
                .margin({ left: 20, right: 20 })
            } else if (this.viewMode === 'preview') {
              // 阅读模式：MarkdownToHtml 富文本渲染
              Scroll() {
                Column({ space: 12 }) {
                  Text(this.vm.title).fontSize(28).fontWeight(FontWeight.Bold).fontColor(this.colors.textPrimary)
                    .width('100%').margin({ bottom: 16 })
                  Text(markdownToHtml(this.vm.content)).fontSize(14).fontColor(this.colors.textPrimary)
                    .width('100%').lineHeight(24)
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
    }.width('100%').height('100%')
  }
}
