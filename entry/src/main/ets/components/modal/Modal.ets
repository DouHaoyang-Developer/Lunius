// components/modal/Modal.ets
// Generic Obsidian-style modal dialog — alert, confirm, and prompt types

import { LuniusColors, ThemeMode, getColors, Spacing, Radius } from '../../utils/Theme';

export interface ModalConfig {
  title: string;
  message: string;
  type: string;
}

@Component
export struct Modal {
  @StorageLink('themeMode') themeMode: ThemeMode = ThemeMode.DARK;
  @Prop config: ModalConfig = { title: '', message: '', type: 'alert' };
  @Prop isVisible: boolean = false;
  @State inputValue: string = '';
  onConfirm: (value?: string) => void = () => {};
  onCancel: () => void = () => {};

  private colors(): LuniusColors {
    return getColors(this.themeMode);
  }

  aboutToAppear(): void {
    this.inputValue = '';
  }

  private handleConfirm(): void {
    if (this.config.type === 'prompt') {
      this.onConfirm(this.inputValue);
    } else {
      this.onConfirm();
    }
  }

  private handleCancel(): void {
    this.onCancel();
  }

  build() {
    if (this.isVisible) {
      Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.55)')
        .onClick(() => { this.handleCancel(); })

      Column() {
        Column() {
          Text(this.config.title)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.colors().textPrimary)
            .width('100%')
            .textAlign(TextAlign.Start)
            .padding({ bottom: Spacing.SM })

          Text(this.config.message)
            .fontSize(13)
            .fontColor(this.colors().textSecondary)
            .width('100%')
            .textAlign(TextAlign.Start)
            .lineHeight(20)
            .padding({ bottom: Spacing.LG })

          if (this.config.type === 'prompt') {
            TextInput({ placeholder: 'Enter value...', text: $$this.inputValue })
              .fontSize(13)
              .fontColor(this.colors().textPrimary)
              .placeholderColor(this.colors().textMuted)
              .width('100%')
              .height(38)
              .backgroundColor(this.colors().bgTertiary)
              .borderRadius(Radius.SM)
              .padding({ left: Spacing.MD, right: Spacing.MD })
              .margin({ bottom: Spacing.LG })
          }

          Row() {
            if (this.config.type === 'prompt' || this.config.type === 'confirm') {
              Button('Cancel')
                .fontSize(13)
              .fontColor(this.colors().textSecondary)
              .backgroundColor(this.colors().bgHover)
              .borderRadius(Radius.SM)
              .layoutWeight(1)
              .height(36)
              .onClick(() => { this.handleCancel(); })

              Blank()
                .width(Spacing.MD)
            }

            Button(this.config.type === 'alert' ? 'OK' : 'Confirm')
              .fontSize(13)
            .fontColor('#FFFFFF')
            .backgroundColor(this.colors().accent)
            .borderRadius(Radius.SM)
            .layoutWeight(1)
            .height(36)
            .onClick(() => { this.handleConfirm(); })
          }
          .width('100%')
        }
        .width('100%')
        .padding(Spacing.XL)
        .backgroundColor(this.colors().bgPrimary)
        .borderRadius(Radius.LG)
        .border({ width: 1, color: this.colors().border })
        .shadow({ radius: 24, color: 'rgba(0,0,0,0.4)', offsetX: 0, offsetY: 8 })
      }
      .width('78%')
      .constraintSize({ maxWidth: 400 })
      .position({ x: '11%', y: '28%' })
    }
    .width('100%')
    .height('100%')
    .zIndex(300)
    }
  }
}
