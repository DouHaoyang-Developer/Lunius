import { LuniusColors, ThemeMode, getColors, Spacing } from '../../utils/Theme';
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

  build() {
    Row() {
      Row({ space: Spacing.MD }) {
        Text(String(this.wordCount) + ' \u8BCD')
          .fontSize(11)
          .fontColor(this.colors().textMuted)
        Text(String(this.charCount) + ' \u5B57\u7B26')
          .fontSize(11)
          .fontColor(this.colors().textMuted)
        Text('\u7EA6 ' + String(this.readTime) + ' \u5206\u949F')
          .fontSize(11)
          .fontColor(this.colors().textMuted)
      }

      Blank()

      Text('Ln ' + String(this.cursorLine) + ', Col ' + String(this.cursorCol))
        .fontSize(11)
        .fontColor(this.colors().textMuted)

      Blank()

      Row({ space: Spacing.SM }) {
        if (this.syncStatus) {
          Row({ space: 4 }) {
            Text(this.syncStatus.isSyncing ? '\u27F3'
              : this.syncStatus.pendingChanges > 0 ? '\u2191'
              : '\u2713')
              .fontSize(11)
              .fontColor(this.syncStatus.isSyncing
                ? this.colors().accent : this.colors().textMuted)
            Text(this.syncStatus.isSyncing
              ? '\u540C\u6B65\u4E2D...'
              : String(this.syncStatus.pendingChanges) + ' \u5F85\u540C\u6B65')
              .fontSize(11)
              .fontColor(this.colors().textMuted)
          }
          .margin({ right: Spacing.MD })
        }

        Row({ space: 0 }) {
          Button({ type: ButtonType.Normal }) {
            Text('\u6E90\u7801')
              .fontSize(10)
              .fontColor(this.currentView === 'source'
                ? this.colors().accent : this.colors().textMuted)
          }
          .width(38).height(22)
          .backgroundColor(this.currentView === 'source'
            ? this.colors().bgActive : Color.Transparent)
          .borderRadius({ topLeft: 3, bottomLeft: 3 })
          .onClick(() => {
            if (this.onViewChange) {
              this.onViewChange('source');
            }
          })

          Button({ type: ButtonType.Normal }) {
            Text('\u5B9E\u65F6')
              .fontSize(10)
              .fontColor(this.currentView === 'live'
                ? this.colors().accent : this.colors().textMuted)
          }
          .width(38).height(22)
          .backgroundColor(this.currentView === 'live'
            ? this.colors().bgActive : Color.Transparent)
          .onClick(() => {
            if (this.onViewChange) {
              this.onViewChange('live');
            }
          })

          Button({ type: ButtonType.Normal }) {
            Text('\u9605\u8BFB')
              .fontSize(10)
              .fontColor(this.currentView === 'preview'
                ? this.colors().accent : this.colors().textMuted)
          }
          .width(38).height(22)
          .backgroundColor(this.currentView === 'preview'
            ? this.colors().bgActive : Color.Transparent)
          .onClick(() => {
            if (this.onViewChange) {
              this.onViewChange('preview');
            }
          })

          Button({ type: ButtonType.Normal }) {
            Text('\u5206\u5C4F')
              .fontSize(10)
              .fontColor(this.currentView === 'split'
                ? this.colors().accent : this.colors().textMuted)
          }
          .width(38).height(22)
          .backgroundColor(this.currentView === 'split'
            ? this.colors().bgActive : Color.Transparent)
          .borderRadius({ topRight: 3, bottomRight: 3 })
          .onClick(() => {
            if (this.onViewChange) {
              this.onViewChange('split');
            }
          })
        }
        .border({ width: 1, color: this.colors().divider })
        .borderRadius(3)
      }
    }
    .width('100%')
    .height(28)
    .padding({ left: Spacing.LG, right: Spacing.LG })
    .backgroundColor(this.colors().editorBg)
    .border({ width: { top: 1 }, color: this.colors().divider })
  }
}
