// components/CloudSyncSettings.ets
// 云同步设置面板 — 华为云空间授权、同步状态、配额管理

import { ObsidianColors, ThemeMode, getColors } from '../utils/Theme';
import { CloudSyncService } from '../services/CloudSyncService';
import { CloudSyncStatus } from '../services/ApiTypes';

@Entry
@Component
struct CloudSyncSettings {
  @StorageLink('themeMode') themeMode: ThemeMode = ThemeMode.DARK;
  @State isAuthorized: boolean = false;
  @State syncStatus: CloudSyncStatus | null = null;
  @State isLoading: boolean = true;
  @State message: string = '';

  private cloudSync: CloudSyncService = CloudSyncService.getInstance();

  private colors(): ObsidianColors {
    return getColors(this.themeMode);
  }

  aboutToAppear(): void {
    this.loadStatus();
  }

  async loadStatus(): Promise<void> {
    this.isLoading = true;
    try {
      this.isAuthorized = this.cloudSync.isAuthorized();
      if (this.isAuthorized) {
        this.syncStatus = await this.cloudSync.getStatus();
      }
    } catch (e) {
      console.error('Failed to load cloud sync status:', JSON.stringify(e));
    } finally {
      this.isLoading = false;
    }
  }

  async authorize(): Promise<void> {
    this.message = '正在授权...';
    try {
      const success = await this.cloudSync.authorize();
      if (success) {
        this.isAuthorized = true;
        this.message = '授权成功';
        await this.loadStatus();
      } else {
        this.message = '授权失败，请重试';
      }
    } catch (e) {
      this.message = '授权异常';
    }
  }

  async logout(): Promise<void> {
    await this.cloudSync.logout();
    this.isAuthorized = false;
    this.syncStatus = null;
    this.message = '已登出';
  }

  async syncNow(): Promise<void> {
    this.message = '正在同步...';
    try {
      const result = await this.cloudSync.syncAll();
      this.message = `同步完成：上传 ${result.uploaded}，下载 ${result.downloaded}，冲突 ${result.conflicts}`;
      await this.loadStatus();
    } catch (e) {
      this.message = '同步失败';
    }
  }

  formatSize(bytes: number): string {
    if (bytes < 1024) return `${bytes}B`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)}KB`;
    if (bytes < 1024 * 1024 * 1024) return `${(bytes / (1024 * 1024)).toFixed(1)}MB`;
    return `${(bytes / (1024 * 1024 * 1024)).toFixed(2)}GB`;
  }

  formatTime(timestamp: number): string {
    if (timestamp === 0) return '从未同步';
    const d = new Date(timestamp);
    const pad = (n: number) => String(n).padStart(2, '0');
    return `${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`;
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

        Text('云同步')
          .fontSize(17).fontWeight(FontWeight.Medium)
          .fontColor(this.colors().textPrimary).layoutWeight(1)
          .textAlign(TextAlign.Center)

        Row().width(36)
      }
      .width('100%').height(52).padding({ left: 12, right: 12 })
      .backgroundColor(this.colors().bgSecondary)
      .border({ width: { bottom: 1 }, color: this.colors().divider })

      if (this.message) {
        Row() {
          Text(this.message)
            .fontSize(12).fontColor(this.colors().accent)
        }
        .width('100%').padding(8).backgroundColor(this.colors().bgSecondary)
        .onClick(() => this.message = '')
      }

      if (this.isLoading) {
        Column() {
          LoadingProgress().width(36).height(36).color(this.colors().accent)
        }
        .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column() {
            // 授权状态
            this.SectionTitle('华为云空间');

            if (!this.isAuthorized) {
              Column({ space: 12 }) {
                Text('登录华为帐号，将笔记同步到云空间')
                  .fontSize(13).fontColor(this.colors().textMuted)
                  .width('100%').padding({ left: 16, right: 16 }).margin({ top: 12 })

                Button('授权登录')
                  .fontSize(14).fontColor('#FFFFFF')
                  .backgroundColor(this.colors().accent).borderRadius(6)
                  .width('calc(100% - 32px)').height(40)
                  .onClick(() => this.authorize())
              }
              .width('100%')
            } else {
              // 已授权：显示同步状态
              Row() {
                Column({ space: 2 }) {
                  Text('已授权')
                    .fontSize(14).fontColor('#50C878')
                  Text(`最后同步: ${this.formatTime(this.syncStatus?.lastSyncTime ?? 0)}`)
                    .fontSize(11).fontColor(this.colors().textMuted)
                }
                .alignItems(HorizontalAlign.Start).layoutWeight(1)

                Button('登出')
                  .fontSize(12).fontColor('#FF6B6B')
                  .backgroundColor(Color.Transparent)
                  .border({ width: 1, color: '#FF6B6B', style: BorderStyle.Solid })
                  .borderRadius(4).padding({ left: 10, right: 10 }).height(28)
                  .onClick(() => this.logout())
              }
              .width('100%').padding(16).backgroundColor(this.colors().bgPrimary)
              .border({ width: { bottom: 1 }, color: this.colors().divider })

              // 同步状态
              this.SectionTitle('同步状态');

              this.InfoRow('云端文件数', `${this.syncStatus?.cloudFileCount ?? 0} 个`)
              this.InfoRow('同步状态', this.syncStatus?.isSyncing ? '同步中...' : '空闲')
              this.InfoRow('待上传', `${this.syncStatus?.pendingUploads ?? 0} 个`)
              this.InfoRow('待下载', `${this.syncStatus?.pendingDownloads ?? 0} 个`)

              // 配额信息
              this.SectionTitle('存储配额');

              this.InfoRow('已用空间', this.formatSize(this.syncStatus?.quotaUsed ?? 0))
              this.InfoRow('总空间', this.formatSize(this.syncStatus?.quotaTotal ?? 0))

              if (this.syncStatus && this.syncStatus.quotaTotal > 0) {
                const percent = (this.syncStatus.quotaUsed / this.syncStatus.quotaTotal * 100).toFixed(1);
                this.InfoRow('使用率', `${percent}%`)
              }

              // 同步操作
              this.SectionTitle('同步操作');

              Button('立即同步')
                .fontSize(14).fontColor('#FFFFFF')
                .backgroundColor(this.colors().accent).borderRadius(6)
                .width('calc(100% - 32px)').height(40).margin(16)
                .onClick(() => this.syncNow())
            }

            // 说明
            this.SectionTitle('说明');

            Text('笔记将同步到华为云空间的应用私有文件夹，不会占用您的个人云盘空间。同步每 5 分钟自动执行一次，也可手动触发。')
              .fontSize(12).fontColor(this.colors().textMuted).lineHeight(18)
              .width('100%').padding({ left: 16, right: 16, top: 8, bottom: 16 })

            Row().height(40)
          }
          .width('100%')
        }
        .width('100%').layoutWeight(1)
        .scrollBar(BarState.Auto)
        .backgroundColor(this.colors().bgPrimary)
      }
    }
    .width('100%').height('100%').backgroundColor(this.colors().bgPrimary)
  }

  @Builder
  SectionTitle(title: string) {
    Text(title)
      .fontSize(12).fontWeight(FontWeight.Medium)
      .fontColor(this.colors().textMuted)
      .margin({ top: 20, bottom: 8, left: 16, right: 16 })
      .letterSpacing(1)
  }

  @Builder
  InfoRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(14).fontColor(this.colors().textPrimary).layoutWeight(1)
      Text(value)
        .fontSize(14).fontColor(this.colors().textMuted)
    }
    .width('100%').height(44).padding({ left: 16, right: 16 })
    .backgroundColor(this.colors().bgPrimary)
    .border({ width: { bottom: 1 }, color: this.colors().divider })
  }
}