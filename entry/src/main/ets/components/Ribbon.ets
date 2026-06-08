// components/Ribbon.ets
// Obsidian 左侧 Ribbon 工具栏 - 支持页面跳转与视图切换

import { ObsidianColors, ThemeMode, getColors } from '../utils/Theme';

interface RibbonAction {
  icon: string;
  label: string;
  action: 'toggleSidebar' | 'openSearch' | 'openGraph' | 'openSettings' | 'openDailyNote' | 'toggleTheme';
  isActive?: boolean;
}

@Component
export struct Ribbon {
  @StorageLink('themeMode') themeMode: ThemeMode = ThemeMode.DARK;
  @Prop isCollapsed: boolean = false;
  @Prop activeTool: string = 'file-explorer';
  onToolAction?: (action: string) => void;

  private colors(): ObsidianColors {
    return getColors(this.themeMode);
  }

  private tools: RibbonAction[] = [
    { icon: '📁', label: 'file-explorer', action: 'toggleSidebar', isActive: true },
    { icon: '🔍', label: 'search', action: 'openSearch' },
    { icon: '📊', label: 'graph', action: 'openGraph' },
    { icon: '📅', label: 'daily-note', action: 'openDailyNote' },
    { icon: '⚙️', label: 'settings', action: 'openSettings' }
  ];

  private handleAction(tool: RibbonAction): void {
    switch (tool.action) {
      case 'openSettings':
        try {
          this.getUIContext().getRouter().pushUrl({
            url: 'pages/SettingsPage'
          });
        } catch (e) {
          console.error('navigate error:', JSON.stringify(e));
        }
        break;
      case 'openSearch':
        // 通知主页面切换到搜索 Tab
        if (this.onToolAction) {
          this.onToolAction('switchToSearch');
        }
        break;
      case 'openGraph':
        if (this.onToolAction) {
          this.onToolAction('switchToGraph');
        }
        break;
      case 'openDailyNote':
        if (this.onToolAction) {
          this.onToolAction('openDailyNote');
        }
        break;
      default:
        if (this.onToolAction) {
          this.onToolAction(tool.label);
        }
    }
  }

  build() {
    Column() {
      // 顶部 Logo 区域
      Column() {
        Text('◈')
          .fontSize(24)
          .fontColor(this.colors().accent)
          .fontWeight(FontWeight.Bold)
      }
      .width('100%')
      .height(56)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(this.colors().ribbonBg)

      // 工具按钮列表
      List({ space: 4 }) {
        ForEach(this.tools, (tool: RibbonAction, index: number) => {
          ListItem() {
            Column() {
              Text(tool.icon)
                .fontSize(20)
                .fontColor(tool.label === this.activeTool || tool.isActive 
                  ? this.colors().accent 
                  : this.colors().iconSecondary)
              if (!this.isCollapsed) {
                Text(tool.label === 'file-explorer' ? '文件' : 
                     tool.label === 'search' ? '搜索' :
                     tool.label === 'graph' ? '图谱' :
                     tool.label === 'daily-note' ? '日记' : '设置')
                  .fontSize(10)
                  .fontColor(this.colors().textMuted)
                  .margin({ top: 2 })
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
            }
            .width('100%')
            .height(this.isCollapsed ? 44 : 60)
            .justifyContent(FlexAlign.Center)
            .backgroundColor(tool.label === this.activeTool 
              ? this.colors().bgActive 
              : Color.Transparent)
            .borderRadius(6)
            .onClick(() => {
              this.handleAction(tool);
            })
          }
        }, (tool: RibbonAction) => tool.label)
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ top: 8, bottom: 8 })
      .scrollBar(BarState.Off)

      // 底部操作区
      Column({ space: 8 }) {
        Button({ type: ButtonType.Circle }) {
          Text('🌓')
            .fontSize(18)
        }
        .width(36)
        .height(36)
        .backgroundColor(this.colors().bgHover)
        .onClick(() => {
          this.themeMode = this.themeMode === ThemeMode.DARK 
            ? ThemeMode.LIGHT 
            : ThemeMode.DARK;
        })

        Button({ type: ButtonType.Circle }) {
          Text('?')
            .fontSize(16)
            .fontColor(this.colors().textSecondary)
        }
        .width(36)
        .height(36)
        .backgroundColor(this.colors().bgHover)
      }
      .width('100%')
      .padding(8)
      .backgroundColor(this.colors().ribbonBg)
    }
    .width(this.isCollapsed ? 56 : 72)
    .height('100%')
    .backgroundColor(this.colors().ribbonBg)
    .border({ width: { right: 1 }, color: this.colors().divider })
  }
}
