// components/bases/FilterEditor.ets
// 筛选条件编辑器 — 属��选择 + 运算符 + 值输入 + AND/OR 切换

import { LuniusColors, ThemeMode, getColors } from '../../utils/Theme';
import { FilterGroup, FilterCondition, ColumnDef } from '../../models/BasesTypes';
import { BasesViewModel } from '../../viewmodels/BasesViewModel';

@Component
struct FilterConditionRow {
  @StorageLink('themeMode') themeMode: ThemeMode = ThemeMode.DARK;
  @Link condition: FilterCondition;
  @Prop columns: ColumnDef[];
  onRemove?: () => void;

  private colors(): LuniusColors {
    return getColors(this.themeMode);
  }

  private operators(): { label: string, value: string }[] {
    return [
      { label: '等于', value: 'equals' },
      { label: '不等于', value: 'not_equals' },
      { label: '包含', value: 'contains' },
      { label: '不包含', value: 'not_contains' },
      { label: '大于', value: 'greater_than' },
      { label: '小于', value: 'less_than' },
      { label: '存在', value: 'exists' },
      { label: '不存在', value: 'not_exists' }
    ];
  }

  build() {
    Row({ space: 6 }) {
      // 属性选择
      TextInput({ text: $$this.condition.property, placeholder: '属性' })
        .fontSize(12).fontColor(this.colors().textPrimary)
        .width(80).height(30).backgroundColor(this.colors().surface1).borderRadius(4)

      // 运算符选择
      TextInput({ text: '=', placeholder: '=' })
        .fontSize(12).fontColor(this.colors().accent).width(30).height(30)
        .backgroundColor(this.colors().surface1).borderRadius(4)

      // 值输入（exists/not_exists 不需要）
      if (this.condition.operator !== 'exists' && this.condition.operator !== 'not_exists') {
        TextInput({ text: $$this.condition.value, placeholder: '值' })
          .fontSize(12).fontColor(this.colors().textPrimary)
          .layoutWeight(1).height(30)
          .backgroundColor(this.colors().surface1).borderRadius(4)
      }

      Button({ type: ButtonType.Circle }) {
        Text('✕').fontSize(10).fontColor(this.colors().textTertiary)
      }
      .width(20).height(20).backgroundColor(Color.Transparent)
      .onClick(() => { if (this.onRemove) this.onRemove(); })
    }
    .width('100%').height(36).padding({ left: 4, right: 4 })
  }
}

@Component
export struct FilterEditor {
  @StorageLink('themeMode') themeMode: ThemeMode = ThemeMode.DARK;
  @ObjectLink vm: BasesViewModel;
  @State isExpanded: boolean = false;

  private colors(): LuniusColors {
    return getColors(this.themeMode);
  }

  private filter(): FilterGroup {
    return this.vm.config.filter;
  }

  build() {
    Column() {
      Row() {
        Row({ space: 4 }) {
          Text('🔍').fontSize(12)
          Text('筛选')
            .fontSize(13).fontWeight(FontWeight.Medium).fontColor(this.colors().textSecondary)
        }
        .layoutWeight(1)

        Text(this.isExpanded ? '收起' : '展开')
          .fontSize(11).fontColor(this.colors().accent)
          .onClick(() => { this.isExpanded = !this.isExpanded; })
      }
      .width('100%').height(32).padding({ left: 12, right: 12 })

      if (this.isExpanded) {
        // 已有条件列表
        ForEach(this.filter().conditions as (FilterCondition | FilterGroup)[],
          (cond: FilterCondition | FilterGroup, index: number) => {
            if ('property' in cond) {
              FilterConditionRow({
                condition: cond as FilterCondition,
                columns: this.vm.config.columns
              })
            }
          }, (_cond: FilterCondition | FilterGroup, index: number) => `${index}`)

        // 添加条件按钮
        Row({ space: 8 }) {
          Button('+ 条件')
            .fontSize(12).fontColor(this.colors().accent)
            .height(28).padding({ left: 8, right: 8 })
            .backgroundColor(this.colors().surface1).borderRadius(4)
            .onClick(() => {
              const newCond: FilterCondition = {
                property: '', operator: 'contains', value: ''
              };
              (this.filter().conditions as FilterCondition[]).push(newCond);
            })

          Button('清除')
            .fontSize(12).fontColor(this.colors().textTertiary)
            .height(28).padding({ left: 8, right: 8 })
            .backgroundColor(this.colors().surface1).borderRadius(4)
            .onClick(() => {
              this.filter().conditions = [];
            })
        }
        .width('100%').padding({ left: 12, right: 12 })
      }
    }
    .width('100%')
    .backgroundColor(this.colors().surface2)
    .border({ width: { bottom: 1 }, color: this.colors().border })
  }
}
