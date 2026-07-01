// components/TabBar.ets
// 顶部标签栏 - 从 WorkspaceViewModel 获取真实标签数据

import { LuniusColors, ThemeMode, getColors } from '../utils/Theme';

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
  onTabChange?: (tabId: string) => void;
  onTabClose?: (tabId: string) => void;
  onTabPin?: (tabId: string) => void;

  private colors(): LuniusColors {
    return getColors(this.themeMode);
  }

  build() {
    Row() {
      List({ space: 0 }) {
        ForEach(this.tabs, (tab: TabItem, index: number) => {
          ListItem() {
            Row({ space: 6 }) {
              if (tab.isPinned) {
                Text('📌').fontSize(10)
              }

              Text('📄')
                .fontSize(12)
                .fontColor(tab.isActive ? this.colors().fileIcon : this.colors().iconSecondary)

              Text(tab.title + (tab.isModified ? ' ●' : ''))
                .fontSize(12)
                .fontColor(tab.isActive ? this.colors().textPrimary : this.colors().textMuted)
                .fontWeight(tab.isActive ? FontWeight.Medium : FontWeight.Regular)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })

              Button({ type: ButtonType.Circle }) {
                Text('📌').fontSize(8).fontColor(this.colors().textMuted)
              }
              .width(14).height(14)
              .backgroundColor(Color.Transparent)
              .visibility(tab.isActive ? Visibility.Visible : Visibility.Hidden)
              .onClick(() => {
                if (this.onTabPin) {
                  this.onTabPin(tab.id);
                }
              })

              Button({ type: ButtonType.Circle }) {
                Text('✕')
                  .fontSize(10)
                  .fontColor(this.colors().textMuted)
              }
              .width(16).height(16)
              .backgroundColor(Color.Transparent)
              .visibility(tab.isActive ? Visibility.Visible : Visibility.Hidden)
              .onClick(() => {
                if (this.onTabClose) {
                  this.onTabClose(tab.id);
                }
              })
            }
            .height(36)
            .padding({ left: 12, right: 8 })
            .backgroundColor(tab.isActive ? this.colors().tabActiveBg : this.colors().tabBg)
            .border({
              width: { top: tab.isActive ? 2 : 0, right: 1 },
              color: tab.isActive ? this.colors().accent : this.colors().divider
            })
            .onClick(() => {
              if (this.onTabChange) {
                this.onTabChange(tab.id);
              }
            })
          }
        }, (tab: TabItem) => tab.id)
      }
      .height('100%')
      .layoutWeight(1)
      .listDirection(Axis.Horizontal)
      .scrollBar(BarState.Off)

      Row({ space: 8 }) {
        Button({ type: ButtonType.Circle }) {
          Text('⋯')
            .fontSize(16)
            .fontColor(this.colors().iconSecondary)
        }
        .width(28).height(28).backgroundColor(Color.Transparent)

        Button({ type: ButtonType.Circle }) {
          Text('⇄')
            .fontSize(14)
            .fontColor(this.colors().iconSecondary)
        }
        .width(28).height(28).backgroundColor(Color.Transparent)
      }
      .height('100%')
      .padding({ right: 8 })
    }
    .width('100%')
    .height(40)
    .backgroundColor(this.colors().tabBg)
    .border({ width: { bottom: 1 }, color: this.colors().divider })
  }
}
