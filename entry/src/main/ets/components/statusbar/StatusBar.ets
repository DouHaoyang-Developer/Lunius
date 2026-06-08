// components/statusbar/StatusBar.ets
// Obsidian 底部状态栏 - 字数统计、同步状态、视图切换

import { ObsidianColors, ThemeMode, getColors } from '../../utils/Theme';
import { SyncStatus } from '../../services/ApiTypes';

@Component
export struct StatusBar {
  @StorageLink('themeMode') themeMode: ThemeMode = ThemeMode.DARK;
  @Prop wordCount: number = 0;
  @Prop charCount: number = 0;
  @Prop readTime: number = 0;
  @Prop cursorLine: number = 1;
  @Prop cursorCol: number = 1;
  @Prop syncStatus: SyncStatus | null = null;
  @Prop currentView: string = 'live';
  onViewChange?: (view: string) => void;

  private colors(): ObsidianColors {
    return getColors(this.themeMode);
  }

  build() {
    Row() {
      // 左侧：字数统计
      Row({ space: 12 }) {
        Text(`${this.wordCount} 词`)
          .fontSize(11)
          .fontColor(this.colors().textMuted)

        Text(`${this.charCount} 字符`)
          .fontSize(11)
          .fontColor(this.colors().textMuted)

        Text(`约 ${this.readTime} 分钟阅读`)
          .fontSize(11)
          .fontColor(this.colors().textMuted)
      }

      Blank()

      // 中间：光标位置
      Text(`Ln ${this.cursorLine}, Col ${this.cursorCol}`)
        .fontSize(11)
        .fontColor(this.colors().textMuted)

      Blank()

      // 右侧：视图切换 + 同步状态
      Row({ space: 8 }) {
        // 同步指示
        if (this.syncStatus) {
          Row({ space: 4 }) {
            Text(this.syncStatus.isSyncing ? '⟳' : this.syncStatus.pendingChanges > 0 ? '↑' : '✓')
              .fontSize(11)
              .fontColor(this.syncStatus.isSyncing ? this.colors().accent : this.colors().textMuted)
            Text(this.syncStatus.isSyncing ? '同步中...' : `${this.syncStatus.pendingChanges} 待同步`)
              .fontSize(11)
              .fontColor(this.colors().textMuted)
          }
          .margin({ right: 12 })
        }

        // 视图模式切换
        Row({ space: 0 }) {
          Button({ type: ButtonType.Normal }) {
            Text('源码').fontSize(10)
              .fontColor(this.currentView === 'source' ? this.colors().accent : this.colors().textMuted)
          }
          .width(40).height(22)
          .backgroundColor(this.currentView === 'source' ? this.colors().bgActive : Color.Transparent)
          .borderRadius({ topLeft: 3, bottomLeft: 3 })
          .onClick(() => this.onViewChange?.('source'))

          Button({ type: ButtonType.Normal }) {
            Text('实时').fontSize(10)
              .fontColor(this.currentView === 'live' ? this.colors().accent : this.colors().textMuted)
          }
          .width(40).height(22)
          .backgroundColor(this.currentView === 'live' ? this.colors().bgActive : Color.Transparent)
          .onClick(() => this.onViewChange?.('live'))

          Button({ type: ButtonType.Normal }) {
            Text('阅读').fontSize(10)
              .fontColor(this.currentView === 'preview' ? this.colors().accent : this.colors().textMuted)
          }
          .width(40).height(22)
          .backgroundColor(this.currentView === 'preview' ? this.colors().bgActive : Color.Transparent)
          .onClick(() => this.onViewChange?.('preview'))

          Button({ type: ButtonType.Normal }) {
            Text('分屏').fontSize(10)
              .fontColor(this.currentView === 'split' ? this.colors().accent : this.colors().textMuted)
          }
          .width(40).height(22)
          .backgroundColor(this.currentView === 'split' ? this.colors().bgActive : Color.Transparent)
          .borderRadius({ topRight: 3, bottomRight: 3 })
          .onClick(() => this.onViewChange?.('split'))
        }
        .border({ width: 1, color: this.colors().divider })
        .borderRadius(3)
      }
    }
    .width('100%')
    .height(28)
    .padding({ left: 16, right: 16 })
    .backgroundColor(this.colors().editorBg)
    .border({ width: { top: 1 }, color: this.colors().divider })
  }
}
