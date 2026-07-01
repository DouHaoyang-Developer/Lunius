// components/FindReplaceBar.ets
// 编辑器查找与替换栏

import { LuniusColors, ThemeMode, getColors } from '../utils/Theme';

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

  build() {
    Row({ space: 0 }) {
      Column() {
        // 搜索行
        Row({ space: 8 }) {
          // 搜索输入
          Row({ space: 4 }) {
            Text('🔍')
              .fontSize(13)
              .fontColor(this.colors().textMuted)
            TextInput({ placeholder: '查找...', text: $$this.query })
              .placeholderColor(this.colors().textMuted)
              .fontColor(this.colors().textPrimary)
              .fontSize(13)
              .height(32)
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
          .height(32)
          .backgroundColor(this.colors().bgTertiary)
          .borderRadius(4)
          .padding({ left: 8, right: 8 })

          // 匹配计数
          if (this.query && this.matchCount > 0) {
            Text(`${this.currentIndex + 1}/${this.matchCount}`)
              .fontSize(12)
              .fontColor(this.colors().textMuted)
              .width(50)
              .textAlign(TextAlign.Center)
          } else if (this.query) {
            Text('无匹配')
              .fontSize(12)
              .fontColor(this.colors().textMuted)
              .width(50)
              .textAlign(TextAlign.Center)
          }

          // 导航按钮
          Button({ type: ButtonType.Circle }) {
            Text('▲')
              .fontSize(10)
              .fontColor(this.colors().iconSecondary)
          }
          .width(26)
          .height(26)
          .backgroundColor(this.colors().bgHover)
          .onClick(() => {
            if (this.onNavigate) this.onNavigate('prev');
          })

          Button({ type: ButtonType.Circle }) {
            Text('▼')
              .fontSize(10)
              .fontColor(this.colors().iconSecondary)
          }
          .width(26)
          .height(26)
          .backgroundColor(this.colors().bgHover)
          .onClick(() => {
            if (this.onNavigate) this.onNavigate('next');
          })

          // 区分大小写
          Button({ type: ButtonType.Circle }) {
            Text('Aa')
              .fontSize(11)
              .fontColor(this.caseSensitive ? this.colors().accent : this.colors().iconSecondary)
          }
          .width(26)
          .height(26)
          .backgroundColor(this.caseSensitive ? this.colors().bgActive : this.colors().bgHover)
          .onClick(() => {
            this.caseSensitive = !this.caseSensitive;
            if (this.onSearch) {
              this.onSearch(this.query, this.caseSensitive);
            }
          })

          // 展开替换
          Button({ type: ButtonType.Circle }) {
            Text(this.showReplace ? '▲' : '▼')
              .fontSize(9)
              .fontColor(this.colors().iconSecondary)
          }
          .width(26)
          .height(26)
          .backgroundColor(this.colors().bgHover)
          .onClick(() => {
            this.showReplace = !this.showReplace;
          })

          // 关闭
          Button({ type: ButtonType.Circle }) {
            Text('✕')
              .fontSize(11)
              .fontColor(this.colors().iconSecondary)
          }
          .width(26)
          .height(26)
          .backgroundColor(this.colors().bgHover)
          .onClick(() => {
            if (this.onClose) this.onClose();
          })
        }
        .width('100%')
        .height(40)
        .padding({ left: 12, right: 12 })

        // 替换行（可展开）
        if (this.showReplace) {
          Row({ space: 8 }) {
            TextInput({ placeholder: '替换为...', text: $$this.replaceText })
              .placeholderColor(this.colors().textMuted)
              .fontColor(this.colors().textPrimary)
              .fontSize(13)
              .height(32)
              .backgroundColor(this.colors().bgTertiary)
              .borderRadius(4)
              .layoutWeight(1)
              .padding({ left: 8, right: 8 })

            Button('替换')
              .fontSize(12)
              .fontColor(this.colors().textPrimary)
              .backgroundColor(this.colors().bgHover)
              .height(30)
              .borderRadius(4)
              .padding({ left: 12, right: 12 })
              .onClick(() => {
                if (this.onReplace) {
                  this.onReplace(this.replaceText);
                }
              })

            Button('全部替换')
              .fontSize(12)
              .fontColor(Color.White)
              .backgroundColor(this.colors().accent)
              .height(30)
              .borderRadius(4)
              .padding({ left: 12, right: 12 })
              .onClick(() => {
                if (this.onReplaceAll) {
                  this.onReplaceAll(this.replaceText);
                }
              })
          }
          .width('100%')
          .height(40)
          .padding({ left: 12, right: 12 })
        }
      }
      .width('100%')
    }
    .width('100%')
    .backgroundColor(this.colors().bgSecondary)
    .border({ width: { bottom: 1 }, color: this.colors().divider })
    .padding({ top: 4 })
  }
}
