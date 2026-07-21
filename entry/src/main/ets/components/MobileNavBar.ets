// components/MobileNavBar.ets
// 移动端导航栏 — 悬浮胶囊式导航
// 设计：5 按钮均匀分布，毛玻璃背景，圆角胶囊

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

  @Builder
  NavButton(icon: string, enabled: boolean, action?: () => void) {
    Column() {
      Text(icon)
        .fontSize(18)
        .fontColor(enabled ? this.colors().textPrimary : this.colors().textDisabled)
    }
    .width(44)
    .height(44)
    .justifyContent(FlexAlign.Center)
    .borderRadius(Radius.FULL)
    .onClick(() => {
      if (enabled && action) action();
    })
  }

  @Builder
  TabCountBadge() {
    if (this.tabCount > 0) {
      Column() {
        Text(String(this.tabCount))
          .fontSize(9)
          .fontColor(this.colors().onAccent)
          .fontWeight(FontWeight.Medium)
      }
      .width(16)
      .height(16)
      .backgroundColor(this.colors().accent)
      .borderRadius(Radius.FULL)
      .justifyContent(FlexAlign.Center)
      .position({ x: 28, y: 6 })
    }
  }

  build() {
    Row() {
      this.NavButton(Icons.BACK, this.canGoBack, this.onBack)
      this.NavButton(Icons.FORWARD, this.canGoForward, this.onForward)
      this.NavButton(Icons.SEARCH, true, this.onQuickSwitch)

      Stack() {
        this.NavButton(Icons.TAB, true, this.onShowTabs)
        this.TabCountBadge()
      }
      .width(44)
      .height(44)

      this.NavButton(Icons.MENU, true, this.onOpenMenu)
    }
    .width('92%')
    .height(Spacing.MOBILE_NAV_HEIGHT)
    .justifyContent(FlexAlign.SpaceEvenly)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.colors().mobileNavBg)
    .borderRadius(Radius.CAPSULE)
    .shadow({ radius: 12, color: 'rgba(0,0,0,0.15)', offsetX: 0, offsetY: 4 })
  }
}
