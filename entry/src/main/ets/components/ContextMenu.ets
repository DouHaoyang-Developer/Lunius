// components/ContextMenu.ets
// Lunius-style floating context menu at pointer position with backdrop dismiss

import { LuniusColors, ThemeMode, getColors, Spacing, Radius } from '../../utils/Theme';

export interface ContextMenuAction {
  id: string;
  label: string;
  icon: string;
  isDanger: boolean;
}

@Component
export struct ContextMenu {
  @StorageLink('themeMode') themeMode: ThemeMode = ThemeMode.DARK;
  @Prop actions: ContextMenuAction[] = [];
  @Prop visible: boolean = false;
  @Prop x: number = 0;
  @Prop y: number = 0;
  onAction: (id: string) => void = () => {};
  onClose: () => void = () => {};

  private colors(): LuniusColors {
    return getColors(this.themeMode);
  }

  private handleAction(actionId: string): void {
    this.onAction(actionId);
    this.onClose();
  }

  private handleDismiss(): void {
    this.onClose();
  }

  build() {
    if (this.visible && this.actions.length > 0) {
      Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.12)')
        .onClick(() => { this.handleDismiss(); })

      Column() {
        ForEach(this.actions, (action: ContextMenuAction, index: number) => {
          Row() {
            if (action.icon.length > 0) {
              Text(action.icon)
                .fontSize(13)
                .width(22)
                .textAlign(TextAlign.Center)
                .fontColor(action.isDanger ? '#E53935' : this.colors().textSecondary)
            }

            Text(action.label)
              .fontSize(12)
              .fontColor(action.isDanger ? '#E53935' : this.colors().textPrimary)
              .layoutWeight(1)
              .padding({ left: action.icon.length > 0 ? Spacing.XS : 0 })
          }
          .width('100%')
          .height(34)
          .padding({ left: Spacing.MD, right: Spacing.MD })
          .backgroundColor(Color.Transparent)
          .borderRadius(Radius.SM)
          .onClick(() => { this.handleAction(action.id); })
        }, (action: ContextMenuAction, index: number) => action.id)
      }
      .width(168)
      .padding({ top: Spacing.XS, bottom: Spacing.XS })
      .backgroundColor(this.colors().surface2)
      .borderRadius(Radius.SM)
      .border({ width: 1, color: this.colors().border })
      .shadow({ radius: 12, color: 'rgba(0,0,0,0.28)', offsetX: 2, offsetY: 4 })
      .position({ x: this.x, y: this.y })
      .zIndex(400)
    }
    .width('100%')
    .height('100%')
    .zIndex(400)
    .position({ x: 0, y: 0 })
    }
  }
}
