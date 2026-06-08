// components/bases/ColumnConfigBar.ets
// 列配置栏 — 勾选显隐 + 列宽调整

import { ObsidianColors, ThemeMode, getColors } from '../../utils/Theme';
import { ColumnDef } from '../../models/BasesTypes';
import { BasesViewModel } from '../../viewmodels/BasesViewModel';

@Component
export struct ColumnConfigBar {
  @StorageLink('themeMode') themeMode: ThemeMode = ThemeMode.DARK;
  @ObjectLink vm: BasesViewModel;
  @State isExpanded: boolean = false;

  private get colors(): ObsidianColors {
    return getColors(this.themeMode);
  }

  private get columns(): ColumnDef[] {
    return this.vm.config.columns;
  }

  build() {
    Column() {
      Row() {
        Row({ space: 4 }) {
          Text('▦').fontSize(12)
          Text('列配置')
            .fontSize(13).fontWeight(FontWeight.Medium).fontColor(this.colors.textSecondary)
        }
        .layoutWeight(1)

        Text(this.isExpanded ? '收起' : '展开')
          .fontSize(11).fontColor(this.colors.accent)
          .onClick(() => { this.isExpanded = !this.isExpanded; })
      }
      .width('100%').height(32).padding({ left: 12, right: 12 })

      if (this.isExpanded) {
        List({ space: 0 }) {
          ForEach(this.columns, (col: ColumnDef) => {
            ListItem() {
              Row({ space: 8 }) {
                Toggle({ type: ToggleType.Checkbox, isOn: col.visible })
                  .selectedColor(this.colors.accent)
                  .width(20).height(20)
                  .onChange((isOn: boolean) => {
                    this.vm.updateColumn({
                      key: col.key, label: col.label, type: col.type,
                      width: col.width, visible: isOn,
                      sortable: col.sortable, filterable: col.filterable
                    } as ColumnDef);
                  })

                Text(col.label)
                  .fontSize(12).fontColor(this.colors.textPrimary)
                  .layoutWeight(1).textOverflow({ overflow: TextOverflow.Ellipsis }).maxLines(1)

                Text(`${col.width}px`)
                  .fontSize(10).fontColor(this.colors.textMuted)
              }
              .width('100%').height(32).padding({ left: 12, right: 12 })
            }
          }, (col: ColumnDef) => col.key)
        }
        .width('100%').maxHeight(200).scrollBar(BarState.Auto)
      }
    }
    .width('100%')
    .backgroundColor(this.colors.bgSecondary)
  }
}
