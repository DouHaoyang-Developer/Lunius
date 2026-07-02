// components/QuickSwitcher.ets
// Lunius-style quick switcher — Ctrl+O overlay with fuzzy file search and keyboard nav

import { LuniusColors, ThemeMode, getColors, Spacing, Radius } from '../utils/Theme';
import { KeyCode } from '@kit.InputKit';

interface SwitcherItem {
  id: string;
  name: string;
  score: number;
}

function fuzzyScore(query: string, target: string): number {
  const q: string = query.toLowerCase();
  const t: string = target.toLowerCase();
  if (t.indexOf(q) === 0) {
    return 100;
  }
  if (t.indexOf(q) !== -1) {
    return 50;
  }
  let qi: number = 0;
  const tl: number = t.length;
  const ql: number = q.length;
  for (let i = 0; i < tl && qi < ql; i++) {
    if (t.charAt(i) === q.charAt(qi)) {
      qi++;
    }
  }
  if (qi === ql) {
    return 30;
  }
  return 0;
}

@Component
export struct QuickSwitcher {
  @StorageLink('themeMode') themeMode: ThemeMode = ThemeMode.DARK;
  @Prop noteNames: string[] = [];
  @Prop visible: boolean = false;
  @State searchText: string = '';
  @State selectedIndex: number = 0;
  onSelect: (noteId: string) => void = () => {};
  onClose: () => void = () => {};

  private colors(): LuniusColors {
    return getColors(this.themeMode);
  }

  private getFilteredItems(): SwitcherItem[] {
    if (this.searchText.length === 0) {
      const result: SwitcherItem[] = [];
      const max: number = this.noteNames.length < 20 ? this.noteNames.length : 20;
      for (let i = 0; i < max; i++) {
        const name: string = this.noteNames[i];
        const item: SwitcherItem = { id: name, name: name, score: 100 };
        result.push(item);
      }
      return result;
    }
    const scored: SwitcherItem[] = [];
    const len: number = this.noteNames.length;
    for (let i = 0; i < len; i++) {
      const name: string = this.noteNames[i];
      const score: number = fuzzyScore(this.searchText, name);
      if (score > 0) {
        const item: SwitcherItem = { id: name, name: name, score: score };
        scored.push(item);
      }
    }
    scored.sort((a: SwitcherItem, b: SwitcherItem) => b.score - a.score);
    const limit: number = scored.length < 15 ? scored.length : 15;
    const result: SwitcherItem[] = [];
    for (let i = 0; i < limit; i++) {
      result.push(scored[i]);
    }
    return result;
  }

  private handleKeyEvent(event: KeyEvent): void {
    if (event.type !== KeyType.Down) {
      return;
    }
    const filtered: SwitcherItem[] = this.getFilteredItems();
    const count: number = filtered.length;
    if (count === 0) {
      return;
    }
    if (event.keyCode === KeyCode.KEYCODE_ESCAPE) {
      this.onClose();
      return;
    }
    if (event.keyCode === KeyCode.KEYCODE_ENTER) {
      if (this.selectedIndex >= 0 && this.selectedIndex < count) {
        const item: SwitcherItem = filtered[this.selectedIndex];
        this.onSelect(item.id);
        this.onClose();
      }
      return;
    }
    if (event.keyCode === KeyCode.KEYCODE_DPAD_DOWN) {
      if (this.selectedIndex < count - 1) {
        this.selectedIndex = this.selectedIndex + 1;
      } else {
        this.selectedIndex = 0;
      }
      return;
    }
    if (event.keyCode === KeyCode.KEYCODE_DPAD_UP) {
      if (this.selectedIndex <= 0) {
        this.selectedIndex = count - 1;
      } else {
        this.selectedIndex = this.selectedIndex - 1;
      }
      return;
    }
  }

  private selectItem(item: SwitcherItem): void {
    this.onSelect(item.id);
    this.onClose();
  }

  private clearSearch(): void {
    this.searchText = '';
    this.selectedIndex = 0;
  }

  build() {
    if (this.visible) {
      Column() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.45)')
        .onClick(() => { this.onClose(); })

      Column() {
        Row() {
          Text('\uD83D\uDD0D')
            .fontSize(13)
            .fontColor(this.colors().textMuted)
            .width(28)
            .textAlign(TextAlign.Center)

          TextInput({ placeholder: 'Search notes...', text: $$this.searchText })
            .placeholderColor(this.colors().textMuted)
            .fontColor(this.colors().textPrimary)
            .fontSize(13)
            .height(36)
            .backgroundColor(Color.Transparent)
            .borderRadius(0)
            .layoutWeight(1)
            .onChange(() => { this.selectedIndex = 0; })

          if (this.searchText.length > 0) {
            Button({ type: ButtonType.Circle }) {
              Text('\u2715')
                .fontSize(10)
                .fontColor(this.colors().textMuted)
            }
            .width(22)
            .height(22)
            .backgroundColor(Color.Transparent)
            .onClick(() => { this.clearSearch(); })
          }
        }
        .width('100%')
        .height(44)
        .padding({ left: Spacing.LG, right: Spacing.SM })
        .backgroundColor(this.colors().bgSecondary)
        .border({ width: { bottom: 1 }, color: this.colors().divider })
        .borderRadius({ topLeft: Radius.MD, topRight: Radius.MD })

        List() {
          ForEach(this.getFilteredItems(), (item: SwitcherItem, index: number) => {
            ListItem() {
              Row() {
                Text('\uD83D\uDCC4')
                  .fontSize(13)
                  .width(28)
                  .textAlign(TextAlign.Center)
                  .fontColor(this.colors().textMuted)

                Text(item.name)
                  .fontSize(13)
                  .fontColor(this.colors().textPrimary)
                  .fontWeight(index === this.selectedIndex ? FontWeight.Medium : FontWeight.Regular)
                  .layoutWeight(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .maxLines(1)
              }
              .width('100%')
              .height(40)
              .padding({ left: Spacing.LG, right: Spacing.LG })
              .backgroundColor(index === this.selectedIndex ? this.colors().bgActive : Color.Transparent)
              .borderRadius(Radius.SM)
              .onClick(() => { this.selectItem(item); })
            }
          }, (item: SwitcherItem, index: number) => item.id)
        }
        .width('100%')
        .constraintSize({ maxHeight: 300 })
        .backgroundColor(this.colors().bgPrimary)
        .scrollBar(BarState.Auto)
        .onKeyEvent((event: KeyEvent) => { this.handleKeyEvent(event); })

        Row() {
          Text('\u2191\u2193 Navigate')
            .fontSize(10)
            .fontColor(this.colors().textMuted)
          Text('\u23CE Open')
            .fontSize(10)
            .fontColor(this.colors().textMuted)
          Text('Esc Close')
            .fontSize(10)
            .fontColor(this.colors().textMuted)
        }
        .width('100%')
        .height(28)
        .justifyContent(FlexAlign.SpaceEvenly)
        .backgroundColor(this.colors().bgSecondary)
        .border({ width: { top: 1 }, color: this.colors().divider })
        .borderRadius({ bottomLeft: Radius.MD, bottomRight: Radius.MD })
      }
      .width('72%')
      .constraintSize({ maxWidth: 480 })
      .shadow({ radius: 24, color: 'rgba(0,0,0,0.4)', offsetX: 0, offsetY: 10 })
      .position({ x: '14%', y: '12%' })
    }
    .width('100%')
    .height('100%')
    .zIndex(300)
    }
  }
}
