// components/properties/GlobalPropertyPanel.ets
// 全局属性面板 — 列出 vault 中所有属性及使用频次

import { LuniusColors, ThemeMode, getColors } from '../../utils/Theme';
import { PropertyUsage, PropertyType, FrontmatterValue } from '../../services/ApiTypes';
import { vaultIndex } from '../../services/VaultIndex';

@Component
export struct GlobalPropertyPanel {
  @StorageLink('themeMode') themeMode: ThemeMode = ThemeMode.DARK;
  @State properties: PropertyUsage[] = [];
  @State isLoading: boolean = true;
  @State searchFilter: string = '';
  @State selectedProperty: PropertyUsage | null = null;

  private colors(): LuniusColors {
    return getColors(this.themeMode);
  }

  async aboutToAppear(): Promise<void> {
    await this.loadProperties();
  }

  async loadProperties(): Promise<void> {
    this.isLoading = true;
    try {
      await vaultIndex.ensureBuilt(true);
      this.properties = await vaultIndex.getAllProperties();
    } catch (e) {
      console.error('GlobalPropertyPanel load failed: ' + JSON.stringify(e));
    }
    this.isLoading = false;
  }

  private filteredProperties(): PropertyUsage[] {
    if (!this.searchFilter) return this.properties;
    const filter = this.searchFilter.toLowerCase();
    return this.properties.filter((p: PropertyUsage) => p.key.toLowerCase().includes(filter));
  }

  private typeIcon(t: PropertyType): string {
    switch (t) {
      case PropertyType.TEXT: return 'Aa';
      case PropertyType.NUMBER: return '#';
      case PropertyType.CHECKBOX: return '☑';
      case PropertyType.DATE: return '📅';
      case PropertyType.TAGS: return '#';
      case PropertyType.LIST: return '☰';
    }
  }

  private typeColor(t: PropertyType): string {
    switch (t) {
      case PropertyType.NUMBER: return '#52C41A';
      case PropertyType.CHECKBOX: return '#7B68EE';
      case PropertyType.DATE: return '#E67E22';
      case PropertyType.TAGS: return '#3498DB';
      default: return this.colors().textSecondary;
    }
  }

  private formatValue(v: FrontmatterValue): string {
    if (typeof v === 'boolean') return v ? 'true' : 'false';
    if (Array.isArray(v)) return v.join(', ');
    return String(v);
  }

  build() {
    Column() {
      // 标题
      Row() {
        Text('全局属性')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.colors().textSecondary)
          .layoutWeight(1)

        Button({ type: ButtonType.Circle }) {
          Text('↻').fontSize(14).fontColor(this.colors().accent)
        }
        .width(28).height(28).backgroundColor(Color.Transparent)
        .onClick(() => { this.loadProperties(); })
      }
      .width('100%').height(36).padding({ left: 12, right: 12 })
      .backgroundColor(this.colors().sidebarBg)

      if (this.isLoading) {
        Text('加载中...')
          .fontSize(12).fontColor(this.colors().textMuted).margin(20)
      } else {
        // 搜索过滤
        TextInput({ placeholder: '过滤属性名...', text: $$this.searchFilter })
          .fontSize(12).fontColor(this.colors().textPrimary)
          .height(32).backgroundColor(this.colors().bgTertiary).borderRadius(6)
          .width('100%').margin({ left: 8, right: 8, top: 4, bottom: 4 })

        // 属性列表
        List({ space: 0 }) {
          ForEach(this.filteredProperties(), (prop: PropertyUsage, index: number) => {
            ListItem() {
              Row({ space: 8 }) {
                Text(this.typeIcon(prop.type))
                  .fontSize(14).fontColor(this.typeColor(prop.type))
                  .width(24).textAlign(TextAlign.Center)

                Column({ space: 2 }) {
                  Text(prop.key)
                    .fontSize(13).fontColor(this.colors().textPrimary)
                    .textOverflow({ overflow: TextOverflow.Ellipsis }).maxLines(1)
                  Text(`${prop.count} 个笔记`)
                    .fontSize(11).fontColor(this.colors().textMuted)
                }
                .layoutWeight(1).alignItems(HorizontalAlign.Start)

                Row({ space: 2 }) {
                  ForEach(prop.values.slice(0, 3), (v: FrontmatterValue, vi: number) => {
                    Text(this.formatValue(v))
                      .fontSize(10).fontColor(this.colors().tagText)
                      .backgroundColor(this.colors().tagBg)
                      .padding({ left: 4, right: 4, top: 1, bottom: 1 })
                      .borderRadius(8).maxLines(1)
                  }, (_v: FrontmatterValue, vi: number) => `${vi}`)
                }
              }
              .width('100%').height(40).padding({ left: 12, right: 12 })
              .backgroundColor(index % 2 === 0 ? this.colors().bgPrimary : this.colors().bgSecondary)
            }
          }, (prop: PropertyUsage) => prop.key)
        }
        .width('100%').layoutWeight(1).scrollBar(BarState.Auto)
      }
    }
    .width('100%').height('100%')
    .backgroundColor(this.colors().sidebarBg)
  }
}
