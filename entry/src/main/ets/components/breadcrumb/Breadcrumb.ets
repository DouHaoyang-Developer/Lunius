// components/breadcrumb/Breadcrumb.ets
// Obsidian 面包屑导航 - 显示当前文件路径与快速跳转

import { ObsidianColors, ThemeMode, getColors } from '../../utils/Theme';

export interface BreadcrumbItem {
  name: string;
  path: string;
  isFile: boolean;
}

@Component
export struct Breadcrumb {
  @StorageLink('themeMode') themeMode: ThemeMode = ThemeMode.DARK;
  @Prop items: BreadcrumbItem[] = [];
  @Prop currentFile: string = '';
  onNavigate?: (path: string) => void;

  private get colors(): ObsidianColors {
    return getColors(this.themeMode);
  }

  build() {
    Row({ space: 4 }) {
      // Vault 根图标
      Text('💎')
        .fontSize(14)
        .onClick(() => {
          this.onNavigate?.('/');
        })

      ForEach(this.items, (item: BreadcrumbItem, index: number) => {
        Row({ space: 4 }) {
          Text('›')
            .fontSize(12)
            .fontColor(this.colors.textMuted)
            .margin({ left: 2, right: 2 })

          Text(item.name)
            .fontSize(12)
            .fontColor(index === this.items.length - 1 ? this.colors.textPrimary : this.colors.textSecondary)
            .fontWeight(index === this.items.length - 1 ? FontWeight.Medium : FontWeight.Regular)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .onClick(() => {
              this.onNavigate?.(item.path);
            })
        }
      }, (item: BreadcrumbItem) => item.path)

      // 当前文件状态指示
      if (this.currentFile) {
        Text('●')
          .fontSize(8)
          .fontColor(this.colors.accent)
          .margin({ left: 4 })
      }
    }
    .width('100%')
    .height(32)
    .padding({ left: 16, right: 16 })
    .backgroundColor(this.colors.editorBg)
    .border({ width: { bottom: 1 }, color: this.colors.divider })
  }
}
