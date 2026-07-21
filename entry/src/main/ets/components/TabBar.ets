// components/TabBar.ets
// 标签页栏 — Obsidian 风格的紧凑标签
// 设计：文件图标+标题+修改指示器，悬停显示关闭/固定按钮

import { LuniusColors, ThemeMode, getColors, Spacing, Radius, Icons } from '../utils/Theme';

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

  @Builder
  TabContent(tab: TabItem) {
    Row({ space: 6 }) {
      // 固定指示器
      if (tab.isPinned) {
        Row()
          .width(3)
          .height(12)
          .backgroundColor(this.colors().accent)
          .borderRadius(Radius.FULL)
      }

      // 文件图标
      Text(Icons.FILE)
        .fontSize(11)
        .fontColor(tab.isActive ? this.colors().fileIcon : this.colors().textTertiary)

      // 标题
      Text(tab.title)
        .fontSize(this.compact ? 11 : 12)
        .fontColor(tab.isActive ? this.colors().textPrimary : this.colors().textSecondary)
        .fontWeight(tab.isActive ? FontWeight.Medium : FontWeight.Regular)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)

      // 修改指示器（未保存）
      if (tab.isModified && !tab.isActive) {
        Row()
          .width(6)
          .height(6)
          .backgroundColor(this.colors().textTertiary)
          .borderRadius(Radius.FULL)
      }

      // 操作按钮（仅 active 显示）
      if (tab.isActive) {
        Row({ space: 2 }) {
          // 固定按钮
          Column() {
            Text(Icons.PIN)
              .fontSize(8)
              .fontColor(tab.isPinned ? this.colors().accent : this.colors().textTertiary)
          }
          .width(18)
          .height(18)
          .justifyContent(FlexAlign.Center)
          .borderRadius(Radius.XS)
          .onClick(() => {
            if (this.onTabPin) this.onTabPin(tab.id);
          })

          // 关闭按钮
          Column() {
            Text(Icons.CLOSE)
              .fontSize(10)
              .fontColor(this.colors().textTertiary)
          }
          .width(18)
          .height(18)
          .justifyContent(FlexAlign.Center)
          .borderRadius(Radius.XS)
          .onClick(() => {
            if (this.onTabClose) this.onTabClose(tab.id);
          })
        }
      }
    }
    .height(this.compact ? Spacing.TAB_HEIGHT_COMPACT : Spacing.TAB_HEIGHT)
    .padding({ left: Spacing.MD, right: Spacing.SM })
    .backgroundColor(tab.isActive ? this.colors().surface0 : Color.Transparent)
    .border({
      width: { top: tab.isActive ? 2 : 0, right: 0.5 },
      color: tab.isActive ? this.colors().accent : this.colors().border
    })
    .onClick(() => {
      if (this.onTabChange) this.onTabChange(tab.id);
    })
  }

  @Builder
  NewTabButton() {
    Column() {
      Text(Icons.PLUS)
        .fontSize(16)
        .fontColor(this.colors().textTertiary)
    }
    .width(32)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      if (this.onNewTab) this.onNewTab();
    })
  }

  build() {
    Row() {
      List({ space: 0 }) {
        ForEach(this.tabs, (tab: TabItem, _index: number) => {
          ListItem() {
            this.TabContent(tab)
          }
        }, (tab: TabItem) => tab.id)
      }
      .height('100%')
      .layoutWeight(1)
      .listDirection(Axis.Horizontal)
      .scrollBar(BarState.Off)

      this.NewTabButton()
    }
    .width('100%')
    .height(this.compact ? Spacing.TAB_HEIGHT_COMPACT : Spacing.TAB_HEIGHT)
    .backgroundColor(this.colors().surface1)
    .border({ width: { bottom: 1 }, color: this.colors().border })
  }
}
