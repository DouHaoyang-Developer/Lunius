// components/statusbar/StatusBar.ets
// 底部状态栏 — 统计信息 + 视图模式切换
// 设计：左侧统计、中间光标位置、右侧同步状态+视图切换

import { LuniusColors, ThemeMode, getColors, Spacing, Radius, Icons, EditorViewMode } from '../../utils/Theme';
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

  private colors(): LuniusColors {
    return getColors(this.themeMode);
  }

  @Builder
  ViewModeButton(mode: string, isFirst: boolean, isLast: boolean) {
    Text(EditorViewMode.LABELS[mode] || mode)
      .fontSize(11)
      .fontColor(this.currentView === mode
        ? this.colors().accent
        : this.colors().textTertiary)
      .fontWeight(this.currentView === mode ? FontWeight.Medium : FontWeight.Regular)
      .height(22)
      .padding({ left: Spacing.SM, right: Spacing.SM })
      .backgroundColor(this.currentView === mode
        ? this.colors().accentSubtle : Color.Transparent)
      .borderRadius({
        topLeft: isFirst ? Radius.XS : 0,
        bottomLeft: isFirst ? Radius.XS : 0,
        topRight: isLast ? Radius.XS : 0,
        bottomRight: isLast ? Radius.XS : 0
      })
      .onClick(() => {
        if (this.onViewChange) {
          this.onViewChange(mode);
        }
      })
  }

  @Builder
  ViewModeSwitcher() {
    Row({ space: 0 }) {
      this.ViewModeButton('source', true, false)
      this.ViewModeButton('live', false, false)
      this.ViewModeButton('preview', false, false)
      this.ViewModeButton('split', false, true)
    }
    .height(22)
    .border({ width: 1, color: this.colors().border })
    .borderRadius(Radius.XS)
    .backgroundColor(this.colors().surface2)
  }

  @Builder
  SyncIndicator() {
    if (this.syncStatus) {
      Row({ space: 4 }) {
        Text(this.syncStatus.isSyncing ? Icons.SYNC
          : this.syncStatus.pendingChanges > 0 ? Icons.PENDING
          : Icons.SYNC_DONE)
          .fontSize(10)
          .fontColor(this.syncStatus.isSyncing
            ? this.colors().accent : this.colors().textTertiary)
        Text(this.syncStatus.isSyncing
          ? '\u540C\u6B65\u4E2D'
          : String(this.syncStatus.pendingChanges) + ' \u5F85\u540C\u6B65')
          .fontSize(11)
          .fontColor(this.colors().textTertiary)
      }
      .margin({ right: Spacing.MD })
    }
  }

  build() {
    Row() {
      // 左侧：统计信息
      Row({ space: Spacing.MD }) {
        Text(String(this.wordCount) + ' \u8BCD')
          .fontSize(11)
          .fontColor(this.colors().textTertiary)
        Text(String(this.charCount) + ' \u5B57\u7B26')
          .fontSize(11)
          .fontColor(this.colors().textTertiary)
        Text('\u7EA6 ' + String(this.readTime) + ' \u5206\u949F')
          .fontSize(11)
          .fontColor(this.colors().textTertiary)
      }

      Blank()

      // 中间：光标位置
      Text('Ln ' + String(this.cursorLine) + ', Col ' + String(this.cursorCol))
        .fontSize(11)
        .fontColor(this.colors().textTertiary)

      Blank()

      // 右侧：同步 + 视图切换
      Row({ space: Spacing.SM }) {
        this.SyncIndicator()
        this.ViewModeSwitcher()
      }
    }
    .width('100%')
    .height(Spacing.STATUS_BAR_HEIGHT)
    .padding({ left: Spacing.LG, right: Spacing.LG })
    .backgroundColor(this.colors().surface1)
    .border({ width: { top: 1 }, color: this.colors().border })
  }
}
