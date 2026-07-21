// components/breadcrumb/Breadcrumb.ets
// 面包屑导航 — Vault 图标 + 路径层级
// 设计：紧凑、带分隔符、修改标记

import { LuniusColors, ThemeMode, getColors, Spacing, Radius, Icons } from '../../utils/Theme';

export interface BreadcrumbItem {
  name: string;
  path: string;
  isFile: boolean;
}

@Component
export struct Breadcrumb {
  @StorageLink('themeMode') themeMode: ThemeMode = ThemeMode.DARK;
  @Prop items: BreadcrumbItem[] = [];
  @Prop hasModified: boolean = false;

  private colors(): LuniusColors {
    return getColors(this.themeMode);
  }

  build() {
    Row({ space: 2 }) {
      // Vault 图标
      Text(Icons.VAULT)
        .fontSize(13)
        .fontColor(this.colors().accent)

      ForEach(this.items, (item: BreadcrumbItem, index: number) => {
        Row({ space: 2 }) {
          Text('\u203A')
            .fontSize(11)
            .fontColor(this.colors().textTertiary)
            .margin({ left: 2, right: 2 })

          Text(item.name)
            .fontSize(12)
            .fontColor(index === this.items.length - 1
              ? this.colors().textPrimary
              : this.colors().textSecondary)
            .fontWeight(index === this.items.length - 1
              ? FontWeight.Medium
              : FontWeight.Regular)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }, (item: BreadcrumbItem) => item.path)

      if (this.hasModified) {
        Row()
          .width(5)
          .height(5)
          .backgroundColor(this.colors().accent)
          .borderRadius(Radius.FULL)
          .margin({ left: Spacing.XS })
      }
    }
    .width('100%')
    .height(32)
    .padding({ left: Spacing.LG, right: Spacing.LG })
    .backgroundColor(this.colors().surface1)
    .border({ width: { bottom: 1 }, color: this.colors().border })
  }
}
