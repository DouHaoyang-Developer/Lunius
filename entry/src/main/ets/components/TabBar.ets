import { LuniusColors, ThemeMode, getColors, Spacing, Icons } from '../utils/Theme';

export interface TabItem {
  id: string;
  title: string;
  isModified?: boolean;
  isActive?: boolean;
  isPinned?: boolean;
}

@Component
export struct TabBar {
  @StorageLink('themeMode') themeMode: ThemeMode = ThemeMode.DARK;
  @Prop tabs: TabItem[] = [];
  @Prop activeTabId: string = '';
  @Prop compact: boolean = false;
  onTabChange?: (tabId: string) => void;
  onTabClose?: (tabId: string) => void;
  onTabPin?: (tabId: string) => void;
  onNewTab?: () => void;

  private colors(): LuniusColors {
    return getColors(this.themeMode);
  }

  build() {
    Row() {
      List({ space: 0 }) {
        ForEach(this.tabs, (tab: TabItem, _index: number) => {
          ListItem() {
            Row({ space: 6 }) {
              if (tab.isPinned) {
                Text(Icons.PIN)
                  .fontSize(9)
                  .fontColor(this.colors().accent)
              }

              Text('\uD83D\uDCC4')
                .fontSize(12)
                .fontColor(tab.isActive ? this.colors().fileIcon : this.colors().iconSecondary)

              Text(tab.title + (tab.isModified ? ' \u25CF' : ''))
                .fontSize(this.compact ? 11 : 12)
                .fontColor(tab.isActive ? this.colors().textPrimary : this.colors().textMuted)
                .fontWeight(tab.isActive ? FontWeight.Medium : FontWeight.Regular)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })

              Button({ type: ButtonType.Circle }) {
                Text(Icons.PIN)
                  .fontSize(8)
                  .fontColor(tab.isPinned ? this.colors().accent : this.colors().textMuted)
              }
              .width(14).height(14)
              .backgroundColor(Color.Transparent)
              .visibility(tab.isActive ? Visibility.Visible : Visibility.Hidden)
              .onClick(() => {
                if (this.onTabPin) this.onTabPin(tab.id);
              })

              Button({ type: ButtonType.Circle }) {
                Text(Icons.CLOSE)
                  .fontSize(10)
                  .fontColor(this.colors().textMuted)
              }
              .width(16).height(16)
              .backgroundColor(Color.Transparent)
              .visibility(tab.isActive ? Visibility.Visible : Visibility.Hidden)
              .onClick(() => {
                if (this.onTabClose) this.onTabClose(tab.id);
              })
            }
            .height(this.compact ? 32 : 36)
            .padding({ left: Spacing.MD, right: Spacing.SM })
            .backgroundColor(tab.isActive ? this.colors().tabActiveBg : this.colors().tabBg)
            .border({
              width: { top: tab.isActive ? 2 : 0, right: 1 },
              color: tab.isActive ? this.colors().accent : this.colors().divider
            })
            .onClick(() => {
              if (this.onTabChange) this.onTabChange(tab.id);
            })
          }
        }, (tab: TabItem) => tab.id)
      }
      .height('100%')
      .layoutWeight(1)
      .listDirection(Axis.Horizontal)
      .scrollBar(BarState.Off)

      Button({ type: ButtonType.Circle }) {
        Text(Icons.NEW_TAB)
          .fontSize(14)
          .fontColor(this.colors().iconSecondary)
      }
      .width(28).height(28)
      .backgroundColor(Color.Transparent)
      .margin({ right: Spacing.SM })
      .onClick(() => {
        if (this.onNewTab) this.onNewTab();
      })
    }
    .width('100%')
    .height(this.compact ? 36 : 40)
    .backgroundColor(this.colors().frostedBg)
    .backgroundBlurStyle(BlurStyle.BACKGROUND_THIN, { colorMode: ThemeColorMode.SYSTEM })
    .border({ width: { bottom: 1 }, color: this.colors().divider })
  }
}
