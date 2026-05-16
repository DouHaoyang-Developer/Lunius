// components/MarkdownEditor.ets
// Markdown 编辑器 v3 - 集成 ViewModel、语法高亮、三模式切换、自动补全

import { ObsidianColors, ThemeMode, getColors } from '../utils/Theme';
import { NoteViewModel } from '../viewmodels/NoteViewModel';
import { Breadcrumb } from './breadcrumb/Breadcrumb';
import { StatusBar } from './statusbar/StatusBar';
import { SplitView } from './splitview/SplitView';
import { PropertiesPanel } from './properties/PropertiesPanel';
import { Modal, ModalConfig } from './modal/Modal';
import { markdownToHtml } from '../utils/MarkdownToHtml';
import { getCompletions, shouldShowCompletion, CompletionItem } from '../utils/MarkdownCompleter';
import { syncService } from '../services/ISyncService';
import { SyncStatus } from '../services/ApiTypes';

enum EditorMode {
  EDIT = 'editor',
  PREVIEW = 'preview',
  SPLIT = 'split'
}

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
  @State viewMode: string = 'split';
  @State showProperties: boolean = false;
  @State showModal: boolean = false;
  @State modalConfig: ModalConfig = { title: '', message: '', type: 'alert' };
  @State completions: CompletionItem[] = [];
  @State showCompletions: boolean = false;
  @State syncStatus: SyncStatus | null = null;

  private autoSaveTimer: number = -1;
  private syncPollTimer: number = -1;

  aboutToAppear(): void {
    this.startAutoSave();
    this.loadSyncStatus();
    this.startSyncPoll();
  }

  aboutToDisappear(): void {
    this.stopAutoSave();
    this.stopSyncPoll();
    if (this.vm.hasUnsavedChanges) {
      this.vm.saveNote();
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
    this.syncPollTimer = setInterval(() => {
      this.loadSyncStatus();
    }, 30000);
  }

  private stopSyncPoll(): void {
    if (this.syncPollTimer !== -1) {
      clearInterval(this.syncPollTimer);
      this.syncPollTimer = -1;
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
        name: parts[idx].replace('.md', ''),
        path: '/' + parts.slice(0, idx + 1).join('/'),
        isFile: idx === parts.length - 1
      };
      items.push(item);
    }
    return items;
  }

  private get viewModeLabel(): string {
    switch (this.viewMode) {
      case 'editor': return '编辑';
      case 'preview': return '预览';
      case 'split': return '分屏';
      default: return '编辑';
    }
  }

  private cycleViewMode(): void {
    if (this.viewMode === 'editor') {
      this.viewMode = 'preview';
    } else if (this.viewMode === 'preview') {
      this.viewMode = 'split';
    } else {
      this.viewMode = 'editor';
    }
  }

  private handleSave(): void {
    this.vm.saveNote().then(() => {
      if (this.vm.saveError) {
        const errCfg: ModalConfig = { title: '保存失败', message: this.vm.saveError || '', type: 'alert' };
        this.modalConfig = errCfg;
        this.showModal = true;
      }
    });
  }

  private checkCompletion(): void {
    if (!this.vm.content) {
      this.showCompletions = false;
      return;
    }
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
    const newContent = lines.length > 1
      ? beforeReplace + '\n' + newLastLine
      : newLastLine;
    this.vm.updateContent(newContent);
    this.showCompletions = false;
    this.completions = [];
  }

  private startAutoSave(): void {
    if (this.autoSaveTimer !== -1) return;
    this.autoSaveTimer = setInterval(() => {
      if (this.vm.hasUnsavedChanges) {
        this.vm.saveNote();
      }
    }, 20000);
  }

  private stopAutoSave(): void {
    if (this.autoSaveTimer !== -1) {
      clearInterval(this.autoSaveTimer);
      this.autoSaveTimer = -1;
    }
  }

  build() {
    Stack() {
      Column({ space: 0 }) {
        // 面包屑导航
        Breadcrumb({
          items: this.breadcrumbItems,
          currentFile: this.vm.hasUnsavedChanges ? this.vm.title : ''
        })
        .width('100%')

        // 工具栏
        Row({ space: 8 }) {
          // 模式切换按钮
          Button({ type: ButtonType.Normal }) {
            Text(this.viewModeLabel)
              .fontSize(12)
              .fontColor(this.colors.accent)
              .fontWeight(FontWeight.Medium)
          }
          .backgroundColor(this.colors.bgHover)
          .borderRadius(4)
          .height(28)
          .padding({ left: 8, right: 8 })
          .onClick(() => this.cycleViewMode())

          Divider().vertical(true).height(20).color(this.colors.divider)

          // 格式按钮
          Button({ type: ButtonType.Circle }) {
            Text('B')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.colors.textSecondary)
          }
          .width(28).height(28).backgroundColor(this.colors.bgHover)

          Button({ type: ButtonType.Circle }) {
            Text('I')
              .fontSize(14)
              .fontStyle(FontStyle.Italic)
              .fontColor(this.colors.textSecondary)
          }
          .width(28).height(28).backgroundColor(this.colors.bgHover)

          Button({ type: ButtonType.Circle }) {
            Text('H')
              .fontSize(14)
              .fontColor(this.colors.textSecondary)
          }
          .width(28).height(28).backgroundColor(this.colors.bgHover)

          Divider().vertical(true).height(20).color(this.colors.divider)

          Button({ type: ButtonType.Circle }) {
            Text('🔗')
              .fontSize(14)
              .fontColor(this.colors.textSecondary)
          }
          .width(28).height(28).backgroundColor(this.colors.bgHover)

          Button({ type: ButtonType.Circle }) {
            Text('📷')
              .fontSize(14)
              .fontColor(this.colors.textSecondary)
          }
          .width(28).height(28).backgroundColor(this.colors.bgHover)

          Blank()

          // 属性面板开关
          Button({ type: ButtonType.Circle }) {
            Text('📋')
              .fontSize(14)
              .fontColor(this.showProperties ? this.colors.accent : this.colors.textSecondary)
          }
          .width(28).height(28).backgroundColor(this.colors.bgHover)
          .onClick(() => { this.showProperties = !this.showProperties; })

          // 保存按钮
          Button({ type: ButtonType.Circle }) {
            Text(this.vm.isSaving ? '⟳' : '💾')
              .fontSize(14)
              .fontColor(this.vm.hasUnsavedChanges ? this.colors.accent : this.colors.textSecondary)
          }
          .width(28).height(28).backgroundColor(this.colors.bgHover)
          .onClick(() => this.handleSave())
        }
        .width('100%')
        .height(40)
        .padding({ left: 12, right: 12 })
        .backgroundColor(this.colors.editorBg)
        .border({ width: { bottom: 1 }, color: this.colors.divider })

        // 自动补全面板
        if (this.showCompletions && this.completions.length > 0) {
          Scroll() {
            Row() {
              ForEach(this.completions, (item: CompletionItem) => {
                Button() {
                  Column() {
                    Text(item.label)
                      .fontSize(14).fontColor(this.colors.accent).fontWeight(FontWeight.Medium)
                      .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                    Text(item.description).fontSize(11).fontColor(this.colors.textMuted).maxLines(1)
                  }
                  .alignItems(HorizontalAlign.Start).padding({ left: 10, right: 10 })
                }
                .height(44).backgroundColor(this.colors.bgSecondary).borderRadius(10)
                .border({ width: 1, color: this.colors.divider, style: BorderStyle.Solid })
                .margin({ right: 8 })
                .onClick(() => this.applyCompletion(item))
              }, (item: CompletionItem) => item.label)
            }
            .padding({ left: 4, right: 4 })
          }
          .scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)
          .width('100%').height(52)
          .backgroundColor(this.colors.editorBg)
          .padding({ left: 12, right: 12 })
        }

        // 主体内容区
        Row({ space: 0 }) {
          Column() {
            if (this.viewMode === 'editor') {
              // 编辑模式
              TextArea({ text: this.vm.content })
                .width('100%').height('100%')
                .fontSize(14).fontColor(this.colors.textPrimary)
                .fontFamily('monospace').backgroundColor(this.colors.editorBg)
                .padding(16)
                .onChange((value: string) => {
                  this.vm.updateContent(value);
                  this.checkCompletion();
                })
            } else if (this.viewMode === 'preview') {
              // 预览模式：将 Markdown 转为 HTML 渲染
              Scroll() {
                Column({ space: 12 }) {
                  Text(this.vm.title)
                    .fontSize(28).fontWeight(FontWeight.Bold)
                    .fontColor(this.colors.textPrimary)
                    .width('100%').margin({ bottom: 16 })

                  Text(this.vm.content)
                    .fontSize(14).fontColor(this.colors.textPrimary)
                    .width('100%').lineHeight(24)
                }
                .width('100%').padding(24)
              }
              .width('100%').height('100%')
              .scrollBar(BarState.Auto)
            } else {
              // 分屏模式：左编辑右预览
              SplitView({ vm: this.vm })
                .width('100%').layoutWeight(1)
            }
          }
          .width('100%').layoutWeight(1)

          // 右侧属性面板（可折叠）
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
            .border({ width: { left: 1 }, color: this.colors.divider })
          }
        }
        .width('100%').layoutWeight(1)

        // 底部状态栏
        StatusBar({
          wordCount: this.vm.getWordCount(),
          charCount: this.vm.getCharCount(),
          readTime: this.vm.getReadingTime(),
          cursorLine: 1,
          cursorCol: 1,
          syncStatus: this.syncStatus,
          currentView: this.viewMode,
          onViewChange: (view: string) => this.viewMode = view
        })
        .width('100%')
      }
      .width('100%').height('100%')
      .backgroundColor(this.colors.editorBg)

      // 模态框
      Modal({
        config: this.modalConfig,
        isVisible: this.showModal,
        onConfirm: () => { this.showModal = false; },
        onCancel: () => { this.showModal = false; }
      })
    }
    .width('100%').height('100%')
  }
}
