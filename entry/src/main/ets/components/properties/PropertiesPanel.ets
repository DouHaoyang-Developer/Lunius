// components/properties/PropertiesPanel.ets
// Obsidian Frontmatter YAML 属性编辑面板

import { ObsidianColors, ThemeMode, getColors } from '../../utils/Theme';
import { NoteMetadata } from '../../services/ApiTypes';

type PropertyType = 'text' | 'number' | 'checkbox' | 'tags' | 'date' | 'list';

export interface PropertyItem {
  key: string;
  value: string | number | boolean | string[];
  type: PropertyType;
}

@Component
export struct PropertiesPanel {
  @StorageLink('themeMode') themeMode: ThemeMode = ThemeMode.DARK;
  @Prop metadata: NoteMetadata | null = null;
  @State isExpanded: boolean = true;
  @State editingKey: string = '';
  @State editingValue: string = '';
  onUpdate?: (key: string, value: string | number | boolean | string[]) => void;
  onAddProperty?: (key: string, value: string | number | boolean | string[]) => void;

  private get colors(): ObsidianColors {
    return getColors(this.themeMode);
  }

  private get properties(): PropertyItem[] {
    if (!this.metadata?.frontmatter) return [];
    const result: PropertyItem[] = [];
    this.metadata.frontmatter.forEach((value: string | number | boolean | string[], key: string) => {
      let propType: PropertyType = 'text';
      if (typeof value === 'number') propType = 'number';
      else if (typeof value === 'boolean') propType = 'checkbox';
      else if (Array.isArray(value)) propType = 'tags';
      const pi: PropertyItem = { key: key, value: value, type: propType };
      result.push(pi);
    });
    return result;
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Row({ space: 6 }) {
          Text('📋')
            .fontSize(14)
          Text('属性')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.colors.textSecondary)
        }
        .layoutWeight(1)

        Text(this.isExpanded ? '▼' : '▶')
          .fontSize(10)
          .fontColor(this.colors.textMuted)
          .onClick(() => {
            this.isExpanded = !this.isExpanded;
          })

        Button({ type: ButtonType.Circle }) {
          Text('+')
            .fontSize(16)
            .fontColor(this.colors.accent)
        }
        .width(24)
        .height(24)
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          this.editingKey = 'new-property';
          this.editingValue = '';
        })
      }
      .width('100%')
      .height(36)
      .padding({ left: 12, right: 12 })
      .backgroundColor(this.colors.sidebarBg)

      if (this.isExpanded) {
        // 基础元信息（只读）
        Column({ space: 0 }) {
          this.ReadOnlyRow('创建时间', this.formatDate(this.metadata?.createdAt));
          this.ReadOnlyRow('修改时间', this.formatDate(this.metadata?.updatedAt));
          this.ReadOnlyRow('路径', this.metadata?.path ?? '-');
          this.ReadOnlyRow('字数', `${this.metadata?.wordCount ?? 0}`);
          this.ReadOnlyRow('别名', (this.metadata?.aliases || []).join(', ') || '-');
        }
        .width('100%')
        .padding({ top: 4, bottom: 4 })
        .border({ width: { bottom: 1 }, color: this.colors.divider })

        // 可编辑 Frontmatter
        List({ space: 0 }) {
          ForEach(this.properties, (prop: PropertyItem, index: number) => {
            ListItem() {
              this.PropertyRow(prop)
            }
          }, (prop: PropertyItem) => prop.key)
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)

        // 新增属性输入
        if (this.editingKey) {
          Row({ space: 8 }) {
            TextInput({ placeholder: '属性名', text: $$this.editingKey })
              .fontSize(12)
              .fontColor(this.colors.textPrimary)
              .width(80)
              .height(28)
              .backgroundColor(this.colors.bgTertiary)
              .borderRadius(4)

            TextInput({ placeholder: '值', text: $$this.editingValue })
              .fontSize(12)
              .fontColor(this.colors.textPrimary)
              .layoutWeight(1)
              .height(28)
              .backgroundColor(this.colors.bgTertiary)
              .borderRadius(4)

            Button({ type: ButtonType.Circle }) {
              Text('✓')
                .fontSize(12)
                .fontColor(this.colors.accent)
            }
            .width(24)
            .height(24)
            .backgroundColor(Color.Transparent)
            .onClick(() => {
              this.onAddProperty?.(this.editingKey, this.editingValue);
              this.editingKey = '';
              this.editingValue = '';
            })
          }
          .width('100%')
          .height(40)
          .padding({ left: 12, right: 12, top: 4, bottom: 4 })
        }
      }
    }
    .width('100%')
    .backgroundColor(this.colors.sidebarBg)
    .borderRadius(4)
  }

  @Builder
  ReadOnlyRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(11)
        .fontColor(this.colors.textMuted)
        .width(60)
      Text(value)
        .fontSize(11)
        .fontColor(this.colors.textSecondary)
        .layoutWeight(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .maxLines(1)
    }
    .width('100%')
    .height(28)
    .padding({ left: 12, right: 12 })
  }

  @Builder
  PropertyRow(prop: PropertyItem) {
    Row({ space: 8 }) {
      Text(prop.key)
        .fontSize(12)
        .fontColor(this.colors.textMuted)
        .width(70)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .maxLines(1)

      if (prop.type === 'checkbox') {
        Toggle({ type: ToggleType.Checkbox, isOn: prop.value as boolean })
          .selectedColor(this.colors.accent)
          .width(20)
          .height(20)
          .onChange((isOn: boolean) => {
            this.onUpdate?.(prop.key, isOn);
          })
      } else if (prop.type === 'tags' && Array.isArray(prop.value)) {
        Row({ space: 4 }) {
          ForEach(prop.value as string[], (tag: string, idx: number) => {
            Text(tag)
              .fontSize(10)
              .fontColor(this.colors.tagText)
              .backgroundColor(this.colors.tagBg)
              .padding({ left: 4, right: 4, top: 1, bottom: 1 })
              .borderRadius(8)
          }, (tag: string) => tag)
        }
        .layoutWeight(1)
      } else {
        Text(`${prop.value}`)
          .fontSize(12)
          .fontColor(this.colors.textPrimary)
          .layoutWeight(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .maxLines(1)
      }
    }
    .width('100%')
    .height(32)
    .padding({ left: 12, right: 12 })
    .backgroundColor(Color.Transparent)
    .onClick(() => {
      // 点击编辑（简化版）
    })
  }

  private formatDate(timestamp: number | undefined): string {
    if (!timestamp) return '-';
    const date = new Date(timestamp);
    return `${date.getFullYear()}-${String(date.getMonth()+1).padStart(2,'0')}-${String(date.getDate()).padStart(2,'0')}`;
  }
}
