import { LuniusColors, ThemeMode, getColors, Spacing, Radius, Icons } from '../utils/Theme';

@Component
export struct MobileNavBar {
  @StorageLink('themeMode') themeMode: ThemeMode = ThemeMode.DARK;
  @Prop canGoBack: boolean = false;
  @Prop canGoForward: boolean = false;
  @Prop tabCount: number = 0;
  @Prop safeAreaBottom: number = 0;
  onBack?: () => void;
  onForward?: () => void;
  onQuickSwitch?: () => void;
  onShowTabs?: () => void;
  onOpenMenu?: () => void;

  private colors(): LuniusColors {
    return getColors(this.themeMode);
  }

  build() {
    Row() {
      Button({ type: ButtonType.Circle }) {
        Text(Icons.BACK)
          .fontSize(18)
          .fontColor(this.canGoBack ? this.colors().iconPrimary : this.colors().textMuted)
      }
      .width(40)
      .height(40)
      .backgroundColor(Color.Transparent)
      .enabled(this.canGoBack)
      .onClick(() => {
        if (this.onBack) this.onBack();
      })

      Button({ type: ButtonType.Circle }) {
        Text(Icons.FORWARD)
          .fontSize(18)
          .fontColor(this.canGoForward ? this.colors().iconPrimary : this.colors().textMuted)
      }
      .width(40)
      .height(40)
      .backgroundColor(Color.Transparent)
      .enabled(this.canGoForward)
      .onClick(() => {
        if (this.onForward) this.onForward();
      })

      Button({ type: ButtonType.Circle }) {
        Text(Icons.QUICK_SWITCH)
          .fontSize(20)
          .fontColor(this.colors().iconPrimary)
      }
      .width(40)
      .height(40)
      .backgroundColor(Color.Transparent)
      .onClick(() => {
        if (this.onQuickSwitch) this.onQuickSwitch();
      })

      Button({ type: ButtonType.Normal }) {
        Text(String(this.tabCount))
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.colors().textPrimary)
      }
      .height(28)
      .backgroundColor(this.colors().bgTertiary)
      .borderRadius(14)
      .padding({ left: 14, right: 14 })
      .onClick(() => {
        if (this.onShowTabs) this.onShowTabs();
      })

      Button({ type: ButtonType.Circle }) {
        Text(Icons.MENU)
          .fontSize(18)
          .fontColor(this.colors().iconPrimary)
      }
      .width(40)
      .height(40)
      .backgroundColor(Color.Transparent)
      .onClick(() => {
        if (this.onOpenMenu) this.onOpenMenu();
      })
    }
    .width('90%')
    .height(Spacing.MOBILE_NAV_HEIGHT)
    .justifyContent(FlexAlign.SpaceEvenly)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.colors().mobileNavBg)
    .borderRadius(Radius.CAPSULE)
    .shadow(ShadowStyle.OUTER_FLOATING_SM)
  }
}
