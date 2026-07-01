import { LuniusColors, ThemeMode, getColors, Spacing } from '../../utils/Theme';

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
      Text('\uD83D\uDC8E')
        .fontSize(14)

      ForEach(this.items, (item: BreadcrumbItem, index: number) => {
        Row({ space: 4 }) {
          Text('\u203A')
            .fontSize(13)
            .fontColor(this.colors().textMuted)
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
        Text('\u25CF')
          .fontSize(8)
          .fontColor(this.colors().accent)
          .margin({ left: Spacing.XS })
      }
    }
    .width('100%')
    .height(32)
    .padding({ left: Spacing.LG, right: Spacing.LG })
    .backgroundColor(this.colors().editorBg)
    .border({ width: { bottom: 1 }, color: this.colors().divider })
  }
}
