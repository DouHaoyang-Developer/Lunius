// components/ContextMenu.ets
// 可复用的右键/长按上下文菜单组件

import { ObsidianColors, ThemeMode, getColors } from '../utils/Theme';

export interface ContextMenuAction {
  id: string;
  label: string;
  icon?: string;
  danger?: boolean;
  children?: ContextMenuAction[];
}

@Component
export struct ContextMenu {
  @StorageLink('themeMode') themeMode: ThemeMode = ThemeMode.DARK;
  @Prop actions: ContextMenuAction[] = [];
  @Prop visible: boolean = false;
  @Prop x: number = 0;
  @Prop y: number = 0;
  onAction?: (actionId: string) => void;
  onClose?: () => void;

  private colors(): ObsidianColors {
    return getColors(this.themeMode);
  }

  build() {
    if (this.visible && this.actions.length > 0) {
      Stack() {
        Column({ space: 0 }) {
          ForEach(this.actions, (action: ContextMenuAction) => {
            Row({ space: 8 }) {
              if (action.icon) {
                Text(action.icon)
                  .fontSize(13)
                  .width(20)
              }
              Text(action.label)
                .fontSize(13)
                .fontColor(action.danger ? '#E53935' : this.colors().textPrimary)
                .layoutWeight(1)
            }
            .width('100%')
            .height(36)
            .padding({ left: 12, right: 12 })
            .backgroundColor(Color.Transparent)
            .onClick(() => {
              if (this.onAction) {
                this.onAction(action.id);
              }
              if (this.onClose) {
                this.onClose();
              }
            })
          }, (action: ContextMenuAction) => action.id)
        }
        .width(160)
        .backgroundColor(this.colors().bgSecondary)
        .borderRadius(6)
        .border({ width: 1, color: this.colors().divider })
        .shadow({ radius: 8, color: 'rgba(0,0,0,0.2)', offsetX: 2, offsetY: 2 })
        .position({ x: this.x, y: this.y })
        .zIndex(300)
      }
      .width('100%')
      .height('100%')
      .zIndex(300)
      .onClick(() => {
        if (this.onClose) {
          this.onClose();
        }
      })
    }
  }
}
