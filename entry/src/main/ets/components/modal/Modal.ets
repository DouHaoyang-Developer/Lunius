// components/modal/Modal.ets
// 通用模态框组件 - 确认对话框、输入框、提示

import { ObsidianColors, ThemeMode, getColors } from '../../utils/Theme';

export interface ModalConfig {
  title: string;
  message: string;
  type: 'confirm' | 'prompt' | 'alert';
  confirmText?: string;
  cancelText?: string;
  inputPlaceholder?: string;
  defaultValue?: string;
}

@Component
export struct Modal {
  @StorageLink('themeMode') themeMode: ThemeMode = ThemeMode.DARK;
  @Prop config: ModalConfig = { title: '', message: '', type: 'alert' };
  @Prop isVisible: boolean = false;
  @State inputValue: string = '';
  onConfirm?: (value?: string) => void;
  onCancel?: () => void;

  private colors(): ObsidianColors {
    return getColors(this.themeMode);
  }

  aboutToAppear(): void {
    this.inputValue = this.config.defaultValue ?? '';
  }

  build() {
    Stack() {
      if (this.isVisible) {
        Column() {
          // 遮罩
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor('rgba(0,0,0,0.6)')
            .onClick(() => {
              this.onCancel?.();
            })

          // 对话框
          Column({ space: 16 }) {
            Text(this.config.title)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.colors().textPrimary)
              .width('100%')
              .textAlign(TextAlign.Center)

            Text(this.config.message)
              .fontSize(14)
              .fontColor(this.colors().textSecondary)
              .width('100%')
              .textAlign(TextAlign.Center)
              .lineHeight(20)

            if (this.config.type === 'prompt') {
              TextInput({ placeholder: this.config.inputPlaceholder, text: $$this.inputValue })
                .fontSize(14)
                .fontColor(this.colors().textPrimary)
                .width('100%')
                .height(40)
                .backgroundColor(this.colors().bgTertiary)
                .borderRadius(6)
                .padding({ left: 12, right: 12 })
            }

            Row({ space: 12 }) {
              if (this.config.type !== 'alert') {
                Button(this.config.cancelText ?? '取消') {
                }
                .fontSize(14)
                .fontColor(this.colors().textSecondary)
                .backgroundColor(this.colors().bgHover)
                .borderRadius(6)
                .layoutWeight(1)
                .height(36)
                .onClick(() => {
                  this.onCancel?.();
                })
              }

              Button(this.config.confirmText ?? '确定') {
              }
              .fontSize(14)
              .fontColor('#FFFFFF')
              .backgroundColor(this.colors().accent)
              .borderRadius(6)
              .layoutWeight(1)
              .height(36)
              .onClick(() => {
                if (this.config.type === 'prompt') {
                  this.onConfirm?.(this.inputValue);
                } else {
                  this.onConfirm?.();
                }
              })
            }
            .width('100%')
          }
          .width('80%')
          .padding(24)
          .backgroundColor(this.colors().bgPrimary)
          .borderRadius(12)
          .shadow({ radius: 20, color: 'rgba(0,0,0,0.4)', offsetX: 0, offsetY: 8 })
          .position({ x: '10%', y: '30%' })
        }
        .width('100%')
        .height('100%')
        .zIndex(300)
      }
    }
    .width('100%')
    .height('100%')
  }
}
