// components/QuickSwitcher.ets
// 快速切换器 — Ctrl+O 打开，模糊搜索所有笔记文件名

import { ObsidianColors, ThemeMode, getColors } from '../utils/Theme';

interface SwitcherItem {
  id: string;
  name: string;
  score: number;
}

function fuzzyScore(query: string, target: string): number {
  const q = query.toLowerCase();
  const t = target.toLowerCase();
  if (t.startsWith(q)) return 100;
  if (t.includes(q)) return 50;
  let qi = 0;
  for (let i = 0; i < t.length && qi < q.length; i++) {
    if (t[i] === q[qi]) qi++;
  }
  return qi === q.length ? 30 : 0;
}

@Component
export struct QuickSwitcher {
  @StorageLink('themeMode') themeMode: ThemeMode = ThemeMode.DARK;
  @Prop noteNames: string[] = [];
  @Prop visible: boolean = false;
  @State query: string = '';
  @State selectedIndex: number = 0;
  onSelect?: (noteId: string) => void;
  onClose?: () => void;

  private get colors(): ObsidianColors {
    return getColors(this.themeMode);
  }

  private get filtered(): SwitcherItem[] {
    if (!this.query) {
      const result: SwitcherItem[] = [];
      const names = this.noteNames.slice(0, 20);
      for (const name of names) {
        const item: SwitcherItem = { id: name, name: name, score: 100 };
        result.push(item);
      }
      return result;
    }
    const result: SwitcherItem[] = [];
    for (const name of this.noteNames) {
      const score = fuzzyScore(this.query, name);
      if (score > 0) {
        const item: SwitcherItem = { id: name, name: name, score: score };
        result.push(item);
      }
    }
    result.sort((a: SwitcherItem, b: SwitcherItem) => b.score - a.score);
    return result.slice(0, 15);
  }

  build() {
    if (this.visible) {
      Stack() {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('rgba(0,0,0,0.4)')
          .onClick(() => {
            if (this.onClose) this.onClose();
          })

        Column({ space: 0 }) {
          // 搜索输入
          Row({ space: 8 }) {
            Text('🔍')
              .fontSize(14)
              .fontColor(this.colors.textMuted)
            TextInput({ placeholder: '搜索笔记...', text: $$this.query })
              .placeholderColor(this.colors.textMuted)
              .fontColor(this.colors.textPrimary)
              .fontSize(14)
              .height(40)
              .backgroundColor(Color.Transparent)
              .layoutWeight(1)
              .onChange(() => {
                this.selectedIndex = 0;
              })
          }
          .width('100%')
          .height(48)
          .padding({ left: 16, right: 16 })
          .backgroundColor(this.colors.bgSecondary)
          .border({ width: { bottom: 1 }, color: this.colors.divider })

          // 文件列表
          List({ space: 0 }) {
            ForEach(this.filtered, (item: SwitcherItem, index: number) => {
              ListItem() {
                Row({ space: 10 }) {
                  Text('📄')
                    .fontSize(14)
                  Text(item.name)
                    .fontSize(14)
                    .fontColor(this.colors.textPrimary)
                    .layoutWeight(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .maxLines(1)
                }
                .width('100%')
                .height(40)
                .padding({ left: 16, right: 16 })
                .backgroundColor(index === this.selectedIndex ? this.colors.bgActive : Color.Transparent)
                .onClick(() => {
                  if (this.onSelect) this.onSelect(item.id);
                })
              }
            }, (item: SwitcherItem) => item.id)
          }
          .width('100%')
          .constraintSize({ maxHeight: 320 })
          .scrollBar(BarState.Auto)

          // 底部提示
          Row() {
            Text('↑↓ 选择  Enter 打开  Esc 关闭')
              .fontSize(10)
              .fontColor(this.colors.textMuted)
          }
          .width('100%')
          .height(28)
          .padding({ left: 16, right: 16 })
          .backgroundColor(this.colors.bgSecondary)
          .border({ width: { top: 1 }, color: this.colors.divider })
        }
        .width('70%')
        .backgroundColor(this.colors.bgPrimary)
        .borderRadius(8)
        .shadow({ radius: 16, color: 'rgba(0,0,0,0.3)', offsetX: 0, offsetY: 8 })
        .position({ x: '15%', y: '20%' })
      }
      .width('100%')
      .height('100%')
      .zIndex(300)
    }
  }
}
