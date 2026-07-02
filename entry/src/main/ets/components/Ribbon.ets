import { LuniusColors, ThemeMode, getColors, Icons, Spacing, Radius, SidebarWidth } from '../utils/Theme';

interface RibbonItem {
  action: string;
  icon: string;
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
    { action: 'switchToFileExplorer', icon: Icons.FILE_EXPLORER },
    { action: 'switchToSearch', icon: Icons.SEARCH },
    { action: 'switchToGraph', icon: Icons.GRAPH },
    { action: 'openDailyNote', icon: Icons.DAILY_NOTE },
    { action: 'openSettings', icon: Icons.SETTINGS }
  ];

  private emit(action: string): void {
    if (this.onToolAction) {
      this.onToolAction(action);
    }
  }

  build() {
    Column() {
      Column() {
        Text('\u25C8')
          .fontSize(22)
          .fontColor(this.colors().accent)
          .fontWeight(FontWeight.Bold)
      }
      .width('100%')
      .height(52)
      .justifyContent(FlexAlign.Center)

      List({ space: 2 }) {
        ForEach(this.items, (item: RibbonItem, _index: number) => {
          ListItem() {
            Column() {
              Text(item.icon)
                .fontSize(20)
                .fontColor(item.action === this.activeTool
                  ? this.colors().accent
                  : this.colors().iconSecondary)
            }
            .width('100%')
            .height(this.isCollapsed ? 44 : 52)
            .justifyContent(FlexAlign.Center)
            .backgroundColor(item.action === this.activeTool
              ? this.colors().bgActive
              : Color.Transparent)
            .borderRadius(Radius.SM)
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
        }, (item: RibbonItem) => item.action)
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ top: Spacing.SM, bottom: Spacing.SM })
      .scrollBar(BarState.Off)

      Column() {
        Button({ type: ButtonType.Circle }) {
          Text(this.themeMode === ThemeMode.DARK ? Icons.THEME : '\u2600\uFE0F')
            .fontSize(18)
        }
        .width(36)
        .height(36)
        .backgroundColor(this.colors().bgHover)
        .onClick(() => {
          this.themeMode = this.themeMode === ThemeMode.DARK
            ? ThemeMode.LIGHT : ThemeMode.DARK;
        })
      }
      .width('100%')
      .padding(Spacing.SM)
    }
    .width(this.isTablet ? SidebarWidth.RIBBON : SidebarWidth.RIBBON_PC)
    .height('100%')
    .backgroundColor(this.colors().frostedBg)
    .backgroundBlurStyle(BlurStyle.BACKGROUND_THIN, { colorMode: ThemeColorMode.SYSTEM })
    .border({ width: { right: 1 }, color: this.colors().divider })
  }
}
