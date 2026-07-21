// components/QuickSwitcher.ets
// 快速切换器 — Ctrl+O 模糊文件搜索
// 设计：与命令面板一致的浮层风格

import { LuniusColors, ThemeMode, getColors, Spacing, Radius, Icons } from '../utils/Theme';
import { KeyCode } from '@kit.InputKit';

interface SwitcherItem {
  id: string;
  name: string;
  score: number;
}

function fuzzyScore(query: string, target: string): number {
  const q: string = query.toLowerCase();
  const t: string = target.toLowerCase();
  if (t.indexOf(q) === 0) return 100;
  if (t.indexOf(q) !== -1) return 50;
  let qi: number = 0;
  const tl: number = t.length;
  const ql: number = q.length;
  for (let i = 0; i < tl && qi < ql; i++) {
    if (t.charAt(i) === q.charAt(qi)) qi++;
  }
  if (qi === ql) return 25;
  return 0;
}

@Component
export struct QuickSwitcher {
  @StorageLink('themeMode') themeMode: ThemeMode = ThemeMode.DARK;
  @Prop visible: boolean = false;
  @Prop noteNames: string[] = [];
  @State searchText: string = '';
  @State selectedIndex: number = 0;
  onClose: () => void = () => {};
  onSelect: (noteId: string) => void = () => {};

  private colors(): LuniusColors {
    return getColors(this.themeMode);
  }

  private filteredFiles(): SwitcherItem[] {
    if (this.searchText.trim() === '') {
      return this.noteNames.slice(0, 20).map((name: string) => {
        return { id: name, name: name, score: 0 } as SwitcherItem;
      });
    }
    const results: SwitcherItem[] = [];
    for (const file of this.noteNames) {
      const score = fuzzyScore(this.searchText, file);
      if (score > 0) {
        results.push({ id: file, name: file, score: score });
      }
    }
    results.sort((a: SwitcherItem, b: SwitcherItem) => b.score - a.score);
    return results.slice(0, 20);
  }

  private handleKeyEvent(event: KeyEvent): boolean {
    if (!this.visible) return false;
    const KEY_UP = 2024;
    const KEY_DOWN = 2025;
    const KEY_ENTER = 2054;
    const KEY_ESC = 2070;

    if (event.type === KeyType.Down) {
      if (event.keyCode === KEY_ESC) { this.onClose(); return true; }
      if (event.keyCode === KEY_UP) {
        if (this.selectedIndex > 0) this.selectedIndex--;
        return true;
      }
      if (event.keyCode === KEY_DOWN) {
        const files = this.filteredFiles();
        if (this.selectedIndex < files.length - 1) this.selectedIndex++;
        return true;
      }
      if (event.keyCode === KEY_ENTER) {
        const files = this.filteredFiles();
        if (this.selectedIndex < files.length) {
          this.onSelect(files[this.selectedIndex].name);
          this.onClose();
        }
        return true;
      }
    }
    return false;
  }

  aboutToAppear(): void {
    this.selectedIndex = 0;
  }

  @Builder
  FileRow(item: SwitcherItem, index: number) {
    Row({ space: Spacing.SM }) {
      Text(Icons.FILE)
        .fontSize(12)
        .fontColor(this.colors().fileIcon)

      Text(item.name)
        .fontSize(13)
        .fontColor(index === this.selectedIndex
          ? this.colors().textPrimary : this.colors().textSecondary)
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      if (index === this.selectedIndex) {
        Row()
          .width(3)
          .height(16)
          .backgroundColor(this.colors().accent)
          .borderRadius(Radius.FULL)
      }
    }
    .width('100%')
    .height(36)
    .padding({ left: Spacing.MD, right: Spacing.MD })
    .backgroundColor(index === this.selectedIndex
      ? this.colors().surfaceHover : Color.Transparent)
    .onClick(() => {
      this.onSelect(item.name);
      this.onClose();
    })
  }

  @Builder
  Footer() {
    Row({ space: Spacing.LG }) {
      Row({ space: 4 }) {
        Text('\u2191\u2193').fontSize(10).fontColor(this.colors().textTertiary)
        Text('\u5BFC\u822A').fontSize(10).fontColor(this.colors().textTertiary)
      }
      Row({ space: 4 }) {
        Text('\u23CE').fontSize(10).fontColor(this.colors().textTertiary)
        Text('\u6253\u5F00').fontSize(10).fontColor(this.colors().textTertiary)
      }
      Row({ space: 4 }) {
        Text('Esc').fontSize(10).fontColor(this.colors().textTertiary)
        Text('\u5173\u95ED').fontSize(10).fontColor(this.colors().textTertiary)
      }
    }
    .width('100%')
    .height(32)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.colors().surface1)
    .border({ width: { top: 1 }, color: this.colors().border })
    .borderRadius({ bottomLeft: Radius.MD, bottomRight: Radius.MD })
  }

  build() {
    if (this.visible) {
      Stack() {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('rgba(0,0,0,0.3)')
          .onClick(() => this.onClose())

        Column() {
          Row({ space: Spacing.SM }) {
            Text(Icons.SEARCH)
              .fontSize(14)
              .fontColor(this.colors().textTertiary)
            TextInput({ placeholder: '\u8F93\u5165\u6587\u4EF6\u540D...', text: $$this.searchText })
              .placeholderColor(this.colors().textTertiary)
              .fontColor(this.colors().textPrimary)
              .fontSize(14)
              .backgroundColor(Color.Transparent)
              .layoutWeight(1)
              .onChange((value: string) => {
                this.searchText = value;
                this.selectedIndex = 0;
              })
          }
          .width('100%')
          .height(48)
          .padding({ left: Spacing.LG, right: Spacing.LG })
          .backgroundColor(this.colors().surface0)
          .borderRadius({ topLeft: Radius.MD, topRight: Radius.MD })
          .border({ width: { bottom: 1 }, color: this.colors().border })

          List({ space: 0 }) {
            ForEach(this.filteredFiles(), (item: SwitcherItem, index: number) => {
              ListItem() {
                this.FileRow(item, index)
              }
            }, (item: SwitcherItem) => item.id)
          }
          .width('100%')
          .layoutWeight(1)
          .constraintSize({ maxHeight: 320 })
          .scrollBar(BarState.Off)
          .onKeyEvent((event: KeyEvent) => this.handleKeyEvent(event))

          this.Footer()
        }
        .width('72%')
        .constraintSize({ maxWidth: 480 })
        .backgroundColor(this.colors().surface0)
        .borderRadius(Radius.MD)
        .border({ width: 1, color: this.colors().border })
        .shadow(ShadowStyle.OUTER_FLOATING_MD)
        .position({ x: '14%', y: '12%' })
      }
      .width('100%')
      .height('100%')
      .zIndex(300)
    }
  }
}
