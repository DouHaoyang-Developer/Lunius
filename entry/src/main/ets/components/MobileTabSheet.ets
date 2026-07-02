import { LuniusColors, ThemeMode, getColors, Spacing, Radius, Icons } from '../utils/Theme';
import { TabItem } from './TabBar';

@Component
export struct MobileTabSheet {
  @StorageLink('themeMode') themeMode: ThemeMode = ThemeMode.DARK;
  @Prop tabs: TabItem[] = [];
  @Prop activeTabId: string = '';
  onSwitchTab: (tabId: string) => void = () => {};
  onCloseTab: (tabId: string) => void = () => {};
  onNewTab: () => void = () => {};
  onClose: () => void = () => {};

  private colors(): LuniusColors {
    return getColors(this.themeMode);
  }

  build() {
    Column() {
      Row() {
        Text('\u6253\u5F00\u7684\u6807\u7B7E')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.colors().textPrimary)
          .layoutWeight(1)

        Text(String(this.tabs.length))
          .fontSize(12)
          .fontColor(this.colors().textMuted)
          .backgroundColor(this.colors().bgTertiary)
          .padding({ left: Spacing.SM, right: Spacing.SM, top: 2, bottom: 2 })
          .borderRadius(10)

        Button({ type: ButtonType.Circle }) {
          Text(Icons.CLOSE)
            .fontSize(14)
            .fontColor(this.colors().textMuted)
        }
        .width(32)
        .height(32)
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          this.onClose();
        })
      }
      .width('100%')
      .height(48)
      .padding({ left: Spacing.LG, right: Spacing.SM })
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(VerticalAlign.Center)

      List({ space: 0 }) {
        ForEach(this.tabs, (tab: TabItem) => {
          ListItem() {
            Row({ space: Spacing.SM }) {
              Text('\uD83D\uDCC4')
                .fontSize(14)
                .fontColor(tab.isActive ? this.colors().accent : this.colors().iconSecondary)

              Text(tab.title + (tab.isModified ? ' \u25CF' : ''))
                .fontSize(14)
                .fontColor(tab.isActive ? this.colors().textPrimary : this.colors().textSecondary)
                .fontWeight(tab.isActive ? FontWeight.Medium : FontWeight.Regular)
                .layoutWeight(1)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })

              if (tab.isActive) {
                Row()
                  .width(2)
                  .height(16)
                  .backgroundColor(this.colors().accent)
                  .borderRadius(1)
              }

              Button({ type: ButtonType.Circle }) {
                Text(Icons.CLOSE)
                  .fontSize(12)
                  .fontColor(this.colors().textMuted)
              }
              .width(28)
              .height(28)
              .backgroundColor(Color.Transparent)
              .onClick(() => {
                this.onCloseTab(tab.id);
              })
            }
            .width('100%')
            .height(48)
            .padding({ left: Spacing.LG, right: Spacing.SM })
            .backgroundColor(tab.isActive ? this.colors().bgActive : Color.Transparent)
            .borderRadius(Radius.SM)
            .onClick(() => {
              this.onSwitchTab(tab.id);
              this.onClose();
            })
          }
        }, (tab: TabItem) => tab.id)
      }
      .width('100%')
      .constraintSize({ maxHeight: 320 })
      .scrollBar(BarState.Auto)

      Row() {
        Button({ type: ButtonType.Normal }) {
          Row({ space: Spacing.SM }) {
            Text(Icons.PLUS)
              .fontSize(16)
              .fontColor(this.colors().accent)
            Text('\u65B0\u5EFA\u7B14\u8BB0')
              .fontSize(14)
              .fontColor(this.colors().accent)
          }
        }
        .backgroundColor(this.colors().bgHover)
        .borderRadius(Radius.MD)
        .height(40)
        .padding({ left: Spacing.XL, right: Spacing.XL })
        .onClick(() => {
          this.onNewTab();
          this.onClose();
        })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ top: Spacing.MD, bottom: Spacing.XL })
    }
    .width('100%')
    .borderRadius({ topLeft: Radius.SHEET, topRight: Radius.SHEET })
    .backgroundColor(this.colors().frostedBgThick)
    .backgroundBlurStyle(BlurStyle.BACKGROUND_THICK, { colorMode: ThemeColorMode.SYSTEM })
    .backgroundBrightness({
      rate: this.colors().ambientGlowRate,
      lightUpDegree: this.colors().ambientGlowDegree
    })
    .shadow(ShadowStyle.OUTER_FLOATING_MD)
  }
}
