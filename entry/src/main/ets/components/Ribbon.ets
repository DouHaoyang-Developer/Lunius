// components/Ribbon.ets
// 活动栏 — 精炼的左侧导航条
// 设计：48px 宽，图标+悬浮态，底部主题切换

import { LuniusColors, ThemeMode, getColors, Icons, Spacing, Radius, SidebarWidth, Motion } from '../utils/Theme';

interface RibbonItem {
  action: string;
  icon: string;
  label: string;
}

@Component
export struct Ribbon {
  @StorageLink('themeMode') themeMode: ThemeMode = ThemeMode.DARK;
  @Prop isCollapsed: boolean = false;
  @Prop activeTool: string = 'file-explorer';
  @Prop isTablet: boolean = false;
  onToolAction?: (action: string) => void;

  private colors(): LuniusColors {
    return getColors(this.themeMode);
  }

  private items: RibbonItem[] = [
    { action: 'switchToFileExplorer', icon: Icons.FILE_EXPLORER, label: '\u6587\u4EF6' },
    { action: 'switchToSearch', icon: Icons.SEARCH, label: '\u641C\u7D22' },
    { action: 'switchToGraph', icon: Icons.GRAPH, label: '\u56FE\u8C31' },
    { action: 'openDailyNote', icon: Icons.DAILY_NOTE, label: '\u65E5\u8BB0' }
  ];

  private emit(action: string): void {
    if (this.onToolAction) {
      this.onToolAction(action);
    }
  }

  @Builder
  LogoMark() {
    Column() {
      Text('\u25C8')
        .fontSize(20)
        .fontColor(this.colors().accent)
        .fontWeight(FontWeight.Bold)
    }
    .width('100%')
    .height(48)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  ToolButton(item: RibbonItem) {
    Column() {
      Stack() {
        Text(item.icon)
          .fontSize(18)
          .fontColor(item.action === this.activeTool
            ? this.colors().accent
            : this.colors().textTertiary)

        if (item.action === this.activeTool) {
          Row()
            .width(3)
            .height(18)
            .backgroundColor(this.colors().accent)
            .borderRadius(Radius.FULL)
            .position({ x: 0, y: '50%' })
            .translate({ y: '-9px' })
        }
      }
      .width('100%')
      .height(this.isCollapsed ? Spacing.RIBBON_ITEM : Spacing.RIBBON_ITEM_PC)
      .alignContent(Alignment.Center)
      .borderRadius(Radius.MD)
      .onClick(() => {
        if (item.action === 'openSettings') {
          try {
            this.getUIContext().getRouter().pushUrl({ url: 'pages/SettingsPage' });
          } catch (e) {
            console.error('SettingsPage navigate failed');
          }
        } else {
          this.emit(item.action);
        }
      })
    }
    .width('100%')
  }

  @Builder
  SettingsButton() {
    Column() {
      Text(Icons.SETTINGS)
        .fontSize(18)
        .fontColor(this.colors().textTertiary)
    }
    .width('100%')
    .height(this.isCollapsed ? Spacing.RIBBON_ITEM : Spacing.RIBBON_ITEM_PC)
    .justifyContent(FlexAlign.Center)
    .borderRadius(Radius.MD)
    .onClick(() => {
      try {
        this.getUIContext().getRouter().pushUrl({ url: 'pages/SettingsPage' });
      } catch (e) {
        console.error('SettingsPage navigate failed');
      }
    })
  }

  @Builder
  ThemeToggle() {
    Column() {
      Text(Icons.THEME)
        .fontSize(16)
        .fontColor(this.colors().textTertiary)
    }
    .width('100%')
    .height(40)
    .justifyContent(FlexAlign.Center)
    .borderRadius(Radius.MD)
    .onClick(() => {
      this.themeMode = this.themeMode === ThemeMode.DARK
        ? ThemeMode.LIGHT : ThemeMode.DARK;
    })
  }

  build() {
    Column() {
      this.LogoMark()

      List({ space: Spacing.XS }) {
        ForEach(this.items, (item: RibbonItem, _index: number) => {
          ListItem() {
            this.ToolButton(item)
          }
        }, (item: RibbonItem) => item.action)
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ top: Spacing.SM, bottom: Spacing.SM, left: Spacing.XS, right: Spacing.XS })
      .scrollBar(BarState.Off)

      Column({ space: Spacing.XS }) {
        this.SettingsButton()
        this.ThemeToggle()
      }
      .width('100%')
      .padding({ left: Spacing.XS, right: Spacing.XS, bottom: Spacing.SM })
    }
    .width(this.isTablet ? SidebarWidth.RIBBON : SidebarWidth.RIBBON_PC)
    .height('100%')
    .backgroundColor(this.colors().surface1)
    .border({ width: { right: 1 }, color: this.colors().border })
  }
}
