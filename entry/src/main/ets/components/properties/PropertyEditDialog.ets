// components/properties/PropertyEditDialog.ets
// 属性编辑弹出框 — 类型选择器 + 值编辑器 + 校验

import { FrontmatterValue, PropertyType } from '../../services/ApiTypes';
import { ObsidianColors, getColors, ThemeMode } from '../../utils/Theme';

@Component
export struct PropertyEditDialog {
  @StorageLink('themeMode') themeMode: ThemeMode = ThemeMode.DARK;
  @Prop propertyKey: string;
  @Prop propertyValue: FrontmatterValue;
  @Prop propertyType: PropertyType;
  @State editKey: string = '';
  @State editValue: string = '';
  @State editType: PropertyType = PropertyType.TEXT;
  @State editChecked: boolean = false;
  @State editDate: string = '';
  @State showTypePicker: boolean = false;
  onConfirm?: (key: string, value: FrontmatterValue, type: PropertyType) => void;
  onDelete?: (key: string) => void;
  onCancel?: () => void;

  aboutToAppear(): void {
    this.editKey = this.propertyKey;
    this.editType = this.propertyType;
    this.setEditValue(this.propertyValue);
  }

  private setEditValue(val: FrontmatterValue): void {
    if (typeof val === 'boolean') {
      this.editChecked = val;
    } else if (Array.isArray(val)) {
      this.editValue = val.join(', ');
    } else if (typeof val === 'number') {
      this.editValue = String(val);
    } else {
      this.editValue = String(val);
    }
  }

  private buildResult(): FrontmatterValue {
    if (this.editType === PropertyType.CHECKBOX) return this.editChecked;
    if (this.editType === PropertyType.NUMBER) {
      const n = Number(this.editValue);
      return isNaN(n) ? 0 : n;
    }
    if (this.editType === PropertyType.TAGS) {
      return this.editValue.split(',').filter((s: string) => s.trim().length > 0).map((s: string) => s.trim());
    }
    return this.editValue;
  }

  private colors(): ObsidianColors {
    return getColors(this.themeMode);
  }

  private typeLabel(t: PropertyType): string {
    switch (t) {
      case PropertyType.TEXT: return '文本';
      case PropertyType.NUMBER: return '数字';
      case PropertyType.CHECKBOX: return '勾选';
      case PropertyType.DATE: return '日期';
      case PropertyType.TAGS: return '标签';
      case PropertyType.LIST: return '列表';
    }
  }

  build() {
    Stack() {
      Column({ space: 16 }) {
        // 标题行
        Row({ space: 8 }) {
          Text('编辑属性')
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.colors().textPrimary)
            .layoutWeight(1)

          Button({ type: ButtonType.Circle }) {
            Text('✕').fontSize(14).fontColor(this.colors().textMuted)
          }
          .width(28).height(28).backgroundColor(Color.Transparent)
          .onClick(() => { if (this.onCancel) this.onCancel(); })
        }
        .width('100%')

        Divider().color(this.colors().divider)

        // 属性键名
        Column({ space: 6 }) {
          Text('属性名')
            .fontSize(12).fontColor(this.colors().textMuted)
          TextInput({ text: $$this.editKey, placeholder: 'property_name' })
            .fontSize(14).fontColor(this.colors().textPrimary)
            .height(40).borderRadius(6)
            .backgroundColor(this.colors().bgTertiary)
            .width('100%')
        }.width('100%').alignItems(HorizontalAlign.Start)

        // 属性类型
        Column({ space: 6 }) {
          Text('类型')
            .fontSize(12).fontColor(this.colors().textMuted)
          Row() {
            Text(this.typeLabel(this.editType))
              .fontSize(14).fontColor(this.colors().accent)
              .layoutWeight(1)
            Image($r('sys.media.ohos_ic_public_arrow_down'))
              .width(16).height(16).fillColor(this.colors().textMuted)
          }
          .width('100%').height(40).padding({ left: 12, right: 12 })
          .backgroundColor(this.colors().bgTertiary).borderRadius(6)
          .onClick(() => { this.showTypePicker = !this.showTypePicker; })

          if (this.showTypePicker) {
            Column({ space: 0 }) {
              ForEach(
                [PropertyType.TEXT, PropertyType.NUMBER, PropertyType.CHECKBOX,
                 PropertyType.DATE, PropertyType.TAGS, PropertyType.LIST],
                (t: PropertyType) => {
                  Row() {
                    Text(this.typeLabel(t))
                      .fontSize(14).fontColor(t === this.editType ? this.colors().accent : this.colors().textPrimary)
                      .layoutWeight(1)
                    if (t === this.editType) {
                      Text('✓').fontSize(14).fontColor(this.colors().accent)
                    }
                  }
                  .width('100%').height(36).padding({ left: 12, right: 12 })
                  .backgroundColor(this.colors().bgSecondary)
                  .border({ width: { bottom: 0.5 }, color: this.colors().divider })
                  .onClick(() => {
                    this.editType = t;
                    this.showTypePicker = false;
                  })
                }, (t: PropertyType) => t
              )
            }
            .width('100%').borderRadius(6).clip(true)
          }
        }.width('100%').alignItems(HorizontalAlign.Start)

        // 值编辑器（按类型）
        Column({ space: 6 }) {
          Text('值')
            .fontSize(12).fontColor(this.colors().textMuted)

          if (this.editType === PropertyType.CHECKBOX) {
            Row({ space: 8 }) {
              Toggle({ type: ToggleType.Checkbox, isOn: $$this.editChecked })
                .selectedColor(this.colors().accent)
              Text(this.editChecked ? '是' : '否')
                .fontSize(14).fontColor(this.colors().textSecondary)
            }
          } else if (this.editType === PropertyType.TAGS) {
            TextInput({ text: $$this.editValue, placeholder: 'tag1, tag2, tag3' })
              .fontSize(14).fontColor(this.colors().textPrimary)
              .height(40).borderRadius(6)
              .backgroundColor(this.colors().bgTertiary).width('100%')
          } else if (this.editType === PropertyType.NUMBER) {
            TextInput({ text: $$this.editValue, placeholder: '0' })
              .type(InputType.Number)
              .fontSize(14).fontColor(this.colors().textPrimary)
              .height(40).borderRadius(6)
              .backgroundColor(this.colors().bgTertiary).width('100%')
          } else if (this.editType === PropertyType.DATE) {
            TextInput({ text: $$this.editValue, placeholder: 'YYYY-MM-DD' })
              .fontSize(14).fontColor(this.colors().textPrimary)
              .height(40).borderRadius(6)
              .backgroundColor(this.colors().bgTertiary).width('100%')
          } else {
            TextInput({ text: $$this.editValue, placeholder: 'value' })
              .fontSize(14).fontColor(this.colors().textPrimary)
              .height(40).borderRadius(6)
              .backgroundColor(this.colors().bgTertiary).width('100%')
          }
        }.width('100%').alignItems(HorizontalAlign.Start)

        Divider().color(this.colors().divider)

        // 底部按钮
        Row({ space: 12 }) {
          Button('删除')
            .fontSize(14).fontColor('#E74C3C')
            .height(36).layoutWeight(1)
            .backgroundColor(this.colors().bgTertiary).borderRadius(6)
            .onClick(() => { if (this.onDelete) this.onDelete(this.propertyKey); })

          Button('取消')
            .fontSize(14).fontColor(this.colors().textSecondary)
            .height(36).layoutWeight(1)
            .backgroundColor(this.colors().bgTertiary).borderRadius(6)
            .onClick(() => { if (this.onCancel) this.onCancel(); })

          Button('确认')
            .fontSize(14).fontColor(Color.White)
            .height(36).layoutWeight(1)
            .backgroundColor(this.colors().accent).borderRadius(6)
            .onClick(() => {
              if (this.onConfirm) {
                this.onConfirm(this.editKey, this.buildResult(), this.editType);
              }
            })
        }
        .width('100%')
      }
      .width('100%')
      .padding(20)
      .backgroundColor(this.colors().bgPrimary)
      .borderRadius(12)
    }
    .width('100%').height('100%')
    .backgroundColor('rgba(0,0,0,0.5)')
  }
}
