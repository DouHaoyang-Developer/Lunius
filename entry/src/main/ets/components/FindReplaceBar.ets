// components/FindReplaceBar.ets
// 编辑器查找与替换栏
// 设计：紧凑输入框、几何图标、分组按钮

import { LuniusColors, ThemeMode, getColors, Spacing, Radius, Icons } from '../utils/Theme';

export interface FindMatch {
  start: number;
  end: number;
  line: number;
}

@Component
export struct FindReplaceBar {
  @StorageLink('themeMode') themeMode: ThemeMode = ThemeMode.DARK;
  @State query: string = '';
  @State replaceText: string = '';
  @State showReplace: boolean = false;
  @State caseSensitive: boolean = false;
  @Prop matchCount: number = 0;
  @Prop currentIndex: number = 0;
  onSearch?: (query: string, caseSensitive: boolean) => void;
  onNavigate?: (direction: 'next' | 'prev') => void;
  onReplace?: (replacement: string) => void;
  onReplaceAll?: (replacement: string) => void;
  onClose?: () => void;

  private colors(): LuniusColors {
    return getColors(this.themeMode);
  }

  @Builder
  IconButton(icon: string, active: boolean, action?: () => void) {
    Column() {
      Text(icon)
        .fontSize(11)
        .fontColor(active ? this.colors().accent : this.colors().textSecondary)
    }
    .width(26)
    .height(26)
    .justifyContent(FlexAlign.Center)
    .borderRadius(Radius.SM)
    .backgroundColor(active ? this.colors().accentSubtle : Color.Transparent)
    .onClick(() => {
      if (action) action();
    })
  }

  build() {
    Column() {
      // 搜索行
      Row({ space: Spacing.SM }) {
        // 搜索输入
        Row({ space: 6 }) {
          Text(Icons.SEARCH)
            .fontSize(11)
            .fontColor(this.colors().textTertiary)
          TextInput({ placeholder: '\u67E5\u627E...', text: $$this.query })
            .placeholderColor(this.colors().textTertiary)
            .fontColor(this.colors().textPrimary)
            .fontSize(12)
            .height(28)
            .backgroundColor(Color.Transparent)
            .layoutWeight(1)
            .onChange((value: string) => {
              this.query = value;
              if (this.onSearch) {
                this.onSearch(value, this.caseSensitive);
              }
            })
        }
        .width(200)
        .height(28)
        .backgroundColor(this.colors().surface2)
        .borderRadius(Radius.SM)
        .padding({ left: Spacing.SM, right: Spacing.SM })

        // 匹配计数
        if (this.query && this.matchCount > 0) {
          Text((this.currentIndex + 1) + '/' + this.matchCount)
            .fontSize(11)
            .fontColor(this.colors().textTertiary)
            .width(50)
            .textAlign(TextAlign.Center)
        } else if (this.query) {
          Text('\u65E0\u5339\u914D')
            .fontSize(11)
            .fontColor(this.colors().textTertiary)
            .width(50)
            .textAlign(TextAlign.Center)
        }

        // 导航按钮
        this.IconButton(Icons.CHEVRON_UP, false, () => {
          if (this.onNavigate) this.onNavigate('prev');
        })
        this.IconButton(Icons.CHEVRON_DOWN, false, () => {
          if (this.onNavigate) this.onNavigate('next');
        })

        // 分隔线
        Divider().vertical(true).height(16).color(this.colors().border)

        // 区分大小写
        this.IconButton('Aa', this.caseSensitive, () => {
          this.caseSensitive = !this.caseSensitive;
          if (this.onSearch) {
            this.onSearch(this.query, this.caseSensitive);
          }
        })

        // 展开替换
        this.IconButton(this.showReplace ? Icons.CHEVRON_UP : Icons.CHEVRON_DOWN,
          this.showReplace, () => {
            this.showReplace = !this.showReplace;
          })

        // 关闭
        this.IconButton(Icons.CLOSE_TAB, false, () => {
          if (this.onClose) this.onClose();
        })
      }
      .width('100%')
      .height(40)
      .padding({ left: Spacing.MD, right: Spacing.MD })

      // 替换行（可展开）
      if (this.showReplace) {
        Row({ space: Spacing.SM }) {
          TextInput({ placeholder: '\u66FF\u6362\u4E3A...', text: $$this.replaceText })
            .placeholderColor(this.colors().textTertiary)
            .fontColor(this.colors().textPrimary)
            .fontSize(12)
            .height(28)
            .backgroundColor(this.colors().surface2)
            .borderRadius(Radius.SM)
            .layoutWeight(1)
            .padding({ left: Spacing.SM, right: Spacing.SM })

          Text('\u66FF\u6362')
            .fontSize(12)
            .fontColor(this.colors().textPrimary)
            .height(28)
            .padding({ left: Spacing.SM, right: Spacing.SM })
            .backgroundColor(this.colors().surface2)
            .borderRadius(Radius.SM)
            .onClick(() => {
              if (this.onReplace) {
                this.onReplace(this.replaceText);
              }
            })

          Text('\u5168\u90E8\u66FF\u6362')
            .fontSize(12)
            .fontColor(this.colors().onAccent)
            .height(28)
            .padding({ left: Spacing.SM, right: Spacing.SM })
            .backgroundColor(this.colors().accent)
            .borderRadius(Radius.SM)
            .onClick(() => {
              if (this.onReplaceAll) {
                this.onReplaceAll(this.replaceText);
              }
            })
        }
        .width('100%')
        .height(40)
        .padding({ left: Spacing.MD, right: Spacing.MD })
      }
    }
    .width('100%')
    .backgroundColor(this.colors().surface1)
    .border({ width: { bottom: 1 }, color: this.colors().border })
  }
}
