// components/VersionHistoryPanel.ets
// 版本历史面板 — 查看、对比、恢复笔记的版本快照

import { LuniusColors, ThemeMode, getColors, Spacing, Radius, Icons } from '../utils/Theme';
import { VersionService } from '../services/VersionService';
import { VersionEntry, VersionDetail, VersionCompareResult } from '../services/ApiTypes';

@Entry
@Component
struct VersionHistoryPanel {
  @StorageLink('themeMode') themeMode: ThemeMode = ThemeMode.DARK;
  @State versions: VersionEntry[] = [];
  @State isLoading: boolean = true;
  @State selectedVersion: VersionDetail | null = null;
  @State compareResult: VersionCompareResult | null = null;
  @State showDiff: boolean = false;
  @State message: string = '';

  private noteId: string = '';
  private versionService: VersionService = VersionService.getInstance();

  private colors(): LuniusColors {
    return getColors(this.themeMode);
  }

  aboutToAppear(): void {
    // 从 AppStorage 获取当前笔记 ID
    const id = AppStorage.get<string>('currentNoteId');
    if (id) {
      this.noteId = id;
      this.loadVersions();
    }
  }

  async loadVersions(): Promise<void> {
    this.isLoading = true;
    try {
      this.versions = await this.versionService.listVersions(this.noteId, 50);
    } catch (e) {
      console.error('Failed to load versions:', JSON.stringify(e));
    } finally {
      this.isLoading = false;
    }
  }

  async selectVersion(versionId: string): Promise<void> {
    try {
      this.selectedVersion = await this.versionService.getVersion(this.noteId, versionId);
      this.compareResult = null;
      this.showDiff = false;
    } catch (e) {
      this.message = '加载版本详情失败';
    }
  }

  async compareWithCurrent(versionId: string): Promise<void> {
    try {
      const versions = this.versions;
      const latestVersion = versions[versions.length - 1];
      if (latestVersion) {
        this.compareResult = await this.versionService.compareVersions(
          this.noteId, versionId, latestVersion.versionId
        );
        this.showDiff = true;
      }
    } catch (e) {
      this.message = '版本对比失败';
    }
  }

  async restoreVersion(versionId: string): Promise<void> {
    try {
      await this.versionService.restoreVersion(this.noteId, versionId);
      this.message = '已恢复版本，新版本已创建';
      await this.loadVersions();
    } catch (e) {
      this.message = '恢复版本失败';
    }
  }

  async markCheckpoint(versionId: string): Promise<void> {
    try {
      await this.versionService.markCheckpoint(this.noteId, versionId);
      this.message = '已标记为检查点';
      await this.loadVersions();
    } catch (e) {
      this.message = '标记检查点失败';
    }
  }

  async cleanupVersions(): Promise<void> {
    try {
      const deleted = await this.versionService.cleanupVersions(this.noteId, 20);
      this.message = `已清理 ${deleted} 个旧版本`;
      await this.loadVersions();
    } catch (e) {
      this.message = '清理版本失败';
    }
  }

  formatTime(timestamp: number): string {
    const d = new Date(timestamp);
    const pad = (n: number) => String(n).padStart(2, '0');
    return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`;
  }

  formatSize(bytes: number): string {
    if (bytes < 1024) return `${bytes}B`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)}KB`;
    return `${(bytes / (1024 * 1024)).toFixed(1)}MB`;
  }

  build() {
    Column() {
      // 顶部导航
      Row() {
        Button({ type: ButtonType.Circle }) {
          Text('←')
            .fontSize(18).fontColor(this.colors().textPrimary)
        }
        .width(36).height(36).backgroundColor(Color.Transparent)
        .onClick(() => {
          try { this.getUIContext().getRouter().back(); } catch (e) {}
        })

        Text('版本历史')
          .fontSize(17).fontWeight(FontWeight.Medium)
          .fontColor(this.colors().textPrimary).layoutWeight(1)
          .textAlign(TextAlign.Center)

        Button() {
          Text('清理')
            .fontSize(12).fontColor(this.colors().textTertiary)
        }
        .height(28).backgroundColor(Color.Transparent)
        .onClick(() => this.cleanupVersions())
      }
      .width('100%').height(52).padding({ left: 12, right: 12 })
      .backgroundColor(this.colors().surface2)
      .border({ width: { bottom: 1 }, color: this.colors().border })

      if (this.message) {
        Row() {
          Text(this.message)
            .fontSize(12).fontColor(this.colors().accent)
        }
        .width('100%').padding(8).backgroundColor(this.colors().surface2)
        .onClick(() => this.message = '')
      }

      if (this.isLoading) {
        Column() {
          LoadingProgress().width(36).height(36).color(this.colors().accent)
          Text('加载中...').fontSize(13).fontColor(this.colors().textTertiary).margin({ top: 8 })
        }
        .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (this.showDiff && this.compareResult) {
        this.DiffView()
      } else if (this.selectedVersion) {
        this.VersionDetailView()
      } else {
        this.VersionListView()
      }
    }
    .width('100%').height('100%').backgroundColor(this.colors().surface0)
  }

  @Builder
  VersionListView() {
    Scroll() {
      Column() {
        if (this.versions.length === 0) {
          Text('暂无版本历史')
            .fontSize(14).fontColor(this.colors().textTertiary)
            .width('100%').textAlign(TextAlign.Center).margin({ top: 40 })
        } else {
          ForEach(this.versions, (version: VersionEntry) => {
            Row() {
              Column({ space: 2 }) {
                Row({ space: 6 }) {
                  if (version.isCheckpoint) {
                    Text('★').fontSize(14).fontColor(this.colors().accent)
                  }
                  Text(`v${version.versionNumber}`)
                    .fontSize(14).fontWeight(FontWeight.Medium)
                    .fontColor(this.colors().textPrimary)
                }
                Text(this.formatTime(version.timestamp))
                  .fontSize(11).fontColor(this.colors().textTertiary)
              }
              .alignItems(HorizontalAlign.Start).layoutWeight(1)

              Text(this.formatSize(version.contentSize))
                .fontSize(12).fontColor(this.colors().textTertiary)
            }
            .width('100%').padding({ left: 16, right: 16, top: 10, bottom: 10 })
            .backgroundColor(this.colors().surface0)
            .border({ width: { bottom: 1 }, color: this.colors().border })
            .onClick(() => this.selectVersion(version.versionId))
          }, (version: VersionEntry) => version.versionId)
        }
      }
      .width('100%')
    }
    .width('100%').layoutWeight(1)
    .scrollBar(BarState.Auto)
  }

  @Builder
  VersionDetailView() {
    Column() {
      // 版本详情头
      Row() {
        Button('← 返回列表')
          .fontSize(13).fontColor(this.colors().accent)
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            this.selectedVersion = null;
          })
      }
      .width('100%').padding(12)

      Row({ space: 8 }) {
        Text(`v${this.selectedVersion!.versionNumber}`)
          .fontSize(16).fontWeight(FontWeight.Medium).fontColor(this.colors().textPrimary)
        Text(this.formatTime(this.selectedVersion!.timestamp))
          .fontSize(12).fontColor(this.colors().textTertiary)
        Text(this.formatSize(this.selectedVersion!.contentSize))
          .fontSize(12).fontColor(this.colors().textTertiary)
      }
      .width('100%').padding({ left: 16, right: 16 })

      Row({ space: 8 }) {
        Button('恢复此版本')
          .fontSize(13).fontColor('#FFFFFF').backgroundColor(this.colors().accent)
          .borderRadius(4).padding({ left: 12, right: 12 })
          .onClick(() => this.restoreVersion(this.selectedVersion!.versionId))

        Button('对比当前')
          .fontSize(13).fontColor(this.colors().accent)
          .backgroundColor(Color.Transparent)
          .border({ width: 1, color: this.colors().accent, style: BorderStyle.Solid })
          .borderRadius(4).padding({ left: 12, right: 12 })
          .onClick(() => this.compareWithCurrent(this.selectedVersion!.versionId))

        Button('标记检查点')
          .fontSize(13).fontColor(this.colors().textTertiary)
          .backgroundColor(Color.Transparent)
          .border({ width: 1, color: this.colors().border, style: BorderStyle.Solid })
          .borderRadius(4).padding({ left: 12, right: 12 })
          .onClick(() => this.markCheckpoint(this.selectedVersion!.versionId))
      }
      .width('100%').padding(16)

      Divider().color(this.colors().border)

      // 版本内容预览
      Scroll() {
        Text(this.selectedVersion!.content)
          .fontSize(13).fontColor(this.colors().textPrimary)
          .fontFamily('monospace')
          .width('100%').padding(16)
      }
      .width('100%').layoutWeight(1)
      .scrollBar(BarState.Auto)
      .backgroundColor(this.colors().surface0)
    }
    .width('100%').layoutWeight(1)
  }

  @Builder
  DiffView() {
    Column() {
      Row() {
        Button('← 返回版本')
          .fontSize(13).fontColor(this.colors().accent)
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            this.showDiff = false;
          })
      }
      .width('100%').padding(12)

      Row({ space: 8 }) {
        Text(`v${this.compareResult!.oldVersion.versionNumber}`)
          .fontSize(14).fontColor(this.colors().textTertiary)
        Text('→')
          .fontSize(14).fontColor(this.colors().textTertiary)
        Text(`v${this.compareResult!.newVersion.versionNumber}`)
          .fontSize(14).fontWeight(FontWeight.Medium).fontColor(this.colors().textPrimary)
      }
      .width('100%').padding({ left: 16, right: 16 })

      Row({ space: 16 }) {
        Text(`+${this.compareResult!.additions}`)
          .fontSize(12).fontColor('#50C878')
        Text(`-${this.compareResult!.deletions}`)
          .fontSize(12).fontColor('#FF6B6B')
      }
      .width('100%').padding({ left: 16, right: 16, bottom: 8 })

      Divider().color(this.colors().border)

      // Diff 内容
      Scroll() {
        Text(this.compareResult!.unifiedDiff)
          .fontSize(12).fontColor(this.colors().textPrimary)
          .fontFamily('monospace')
          .width('100%').padding(16)
      }
      .width('100%').layoutWeight(1)
      .scrollBar(BarState.Auto)
      .backgroundColor(this.colors().surface0)
    }
    .width('100%').layoutWeight(1)
  }
}