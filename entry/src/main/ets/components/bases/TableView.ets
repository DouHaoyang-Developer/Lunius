// components/bases/TableView.ets
// 数据库表格视图 — 列头 + 数据行 + 排序交互

import { ObsidianColors, ThemeMode, getColors } from '../../utils/Theme';
import { TableRowData, ColumnDef, SortRule } from '../../models/BasesTypes';
import { BasesViewModel } from '../../viewmodels/BasesViewModel';

@Component
export struct TableView {
  @StorageLink('themeMode') themeMode: ThemeMode = ThemeMode.DARK;
  @ObjectLink vm: BasesViewModel;
  onRowClick?: (noteId: string) => void;

  private get colors(): ObsidianColors {
    return getColors(this.themeMode);
  }

  private get visibleColumns(): ColumnDef[] {
    return this.vm.config.columns.filter((c: ColumnDef) => c.visible);
  }

  private sortIcon(property: string): string {
    const rule = this.vm.config.sort.find((s: SortRule) => s.property === property);
    if (!rule) return '⇅';
    return rule.direction === 'asc' ? '↑' : '↓';
  }

  build() {
    Column() {
      if (this.vm.isLoading) {
        Row() {
          LoadingProgress().width(24).height(24).color(this.colors.accent)
          Text('加载中...').fontSize(14).fontColor(this.colors.textMuted).margin({ left: 8 })
        }
        .width('100%').height(60).justifyContent(FlexAlign.Center)
      } else {
        // 表头
        Row() {
          ForEach(this.visibleColumns, (col: ColumnDef) => {
            Row({ space: 4 }) {
              Text(col.label)
                .fontSize(12).fontWeight(FontWeight.Medium)
                .fontColor(this.colors.textSecondary)
                .textOverflow({ overflow: TextOverflow.Ellipsis }).maxLines(1)
              if (col.sortable) {
                Text(this.sortIcon(col.key))
                  .fontSize(10).fontColor(this.colors.accent)
              }
            }
            .width(col.width).height(36).padding({ left: 8, right: 8 })
            .justifyContent(FlexAlign.Start)
            .onClick(() => { if (col.sortable) this.vm.addSortRule(col.key); })
          }, (col: ColumnDef) => col.key)
        }
        .width('100%').height(36)
        .backgroundColor(this.colors.bgSecondary)
        .border({ width: { bottom: 1 }, color: this.colors.divider })

        // 数据行
        if (this.vm.rows.length === 0) {
          Text('没有匹配的笔记')
            .fontSize(14).fontColor(this.colors.textMuted).margin(40)
        } else {
          List({ space: 0 }) {
            ForEach(this.vm.rows, (row: TableRowData, index: number) => {
              ListItem() {
                Row() {
                  ForEach(this.visibleColumns, (col: ColumnDef) => {
                    Text(row.cells.get(col.key) || '-')
                      .fontSize(12).fontColor(this.colors.textPrimary)
                      .width(col.width).padding({ left: 8, right: 8 })
                      .textOverflow({ overflow: TextOverflow.Ellipsis }).maxLines(1)
                  }, (col: ColumnDef) => col.key)
                }
                .width('100%').height(36)
                .backgroundColor(index % 2 === 0 ? this.colors.bgPrimary : this.colors.bgSecondary)
                .border({ width: { bottom: 0.5 }, color: this.colors.divider })
                .onClick(() => { if (this.onRowClick) this.onRowClick(row.noteId); })
              }
            }, (row: TableRowData) => row.noteId)
          }
          .width('100%').layoutWeight(1).scrollBar(BarState.Auto)
        }

        // 底部状态栏
        Row() {
          Text(`${this.vm.filteredCount} / ${this.vm.totalCount} 条`)
            .fontSize(11).fontColor(this.colors.textMuted).layoutWeight(1)
          Text(`${this.vm.config.columns.filter((c: ColumnDef) => c.visible).length} 列`)
            .fontSize(11).fontColor(this.colors.textMuted)
        }
        .width('100%').height(28).padding({ left: 12, right: 12 })
        .backgroundColor(this.colors.bgSecondary)
        .border({ width: { top: 1 }, color: this.colors.divider })
      }
    }
    .width('100%').height('100%')
    .backgroundColor(this.colors.bgPrimary)
  }
}
