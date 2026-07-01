// components/commandpalette/CommandPalette.ets
// Obsidian-style command palette — Ctrl+P overlay with search and keyboard nav

import { LuniusColors, ThemeMode, getColors, Spacing, Radius } from '../../utils/Theme';
import { KeyCode } from '@kit.InputKit';

export interface CommandItem {
  id: string;
  name: string;
  icon: string;
  shortcut: string;
}

@Component
export struct CommandPalette {
  @StorageLink('themeMode') themeMode: ThemeMode = ThemeMode.DARK;
  @Prop isVisible: boolean = false;
  @State searchText: string = '';
  @State selectedIndex: number = 0;
  onClose: () => void = () => {};
  onCommand: (commandId: string) => void = () => {};

  private builtInCommands: CommandItem[] = [
    { id: 'new-note', name: 'New note', icon: '\uD83D\uDCDD', shortcut: 'Ctrl+N' },
    { id: 'open-quick-switcher', name: 'Quick switcher', icon: '\uD83D\uDD0D', shortcut: 'Ctrl+O' },
    { id: 'save', name: 'Save', icon: '\uD83D\uDCBE', shortcut: 'Ctrl+S' },
    { id: 'toggle-theme', name: 'Toggle theme', icon: '\uD83C\uDF13', shortcut: '' },
    { id: 'toggle-graph', name: 'Graph view', icon: '\uD83D\uDD78\uFE0F', shortcut: 'Ctrl+G' },
    { id: 'split-view', name: 'Split view', icon: '\u27F7', shortcut: 'Ctrl+\\' },
    { id: 'search', name: 'Search', icon: '\uD83D\uDD0E', shortcut: 'Ctrl+Shift+F' },
    { id: 'export-html', name: 'Export HTML', icon: '\uD83C\uDF10', shortcut: '' },
    { id: 'export-md', name: 'Export Markdown', icon: '\uD83D\uDCC4', shortcut: '' },
    { id: 'export-pdf', name: 'Export PDF', icon: '\uD83D\uDCDC', shortcut: '' },
    { id: 'settings', name: 'Settings', icon: '\u2699\uFE0F', shortcut: 'Ctrl+,' }
  ];

  private colors(): LuniusColors {
    return getColors(this.themeMode);
  }

  private getFilteredCommands(): CommandItem[] {
    const q: string = this.searchText.toLowerCase();
    if (q.length === 0) {
      return this.builtInCommands;
    }
    const result: CommandItem[] = [];
    const len: number = this.builtInCommands.length;
    for (let i = 0; i < len; i++) {
      const cmd: CommandItem = this.builtInCommands[i];
      const nameLower: string = cmd.name.toLowerCase();
      const idLower: string = cmd.id.toLowerCase();
      const shortcutLower: string = cmd.shortcut.toLowerCase();
      if (nameLower.indexOf(q) !== -1 ||
          idLower.indexOf(q) !== -1 ||
          shortcutLower.indexOf(q) !== -1) {
        result.push(cmd);
      }
    }
    return result;
  }

  private handleKeyEvent(event: KeyEvent): void {
    if (event.type !== KeyType.Down) {
      return;
    }
    const filtered: CommandItem[] = this.getFilteredCommands();
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
        const cmd: CommandItem = filtered[this.selectedIndex];
        this.onCommand(cmd.id);
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

  private selectCommand(cmd: CommandItem): void {
    this.onCommand(cmd.id);
    this.onClose();
  }

  private clearSearch(): void {
    this.searchText = '';
    this.selectedIndex = 0;
  }

  build() {
    if (this.isVisible) {
      Column() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.45)')
        .onClick(() => { this.onClose(); })

      Column() {
        Row() {
          Text('\u2318')
            .fontSize(14)
            .fontColor(this.colors().textMuted)
            .width(28)
            .textAlign(TextAlign.Center)

          TextInput({ placeholder: 'Type a command...', text: $$this.searchText })
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
          ForEach(this.getFilteredCommands(), (cmd: CommandItem, index: number) => {
            ListItem() {
              Row() {
                Text(cmd.icon)
                  .fontSize(14)
                  .width(32)
                  .textAlign(TextAlign.Center)
                  .fontColor(this.colors().textSecondary)

                Text(cmd.name)
                  .fontSize(13)
                  .fontColor(this.colors().textPrimary)
                  .fontWeight(index === this.selectedIndex ? FontWeight.Medium : FontWeight.Regular)
                  .layoutWeight(1)

                if (cmd.shortcut.length > 0) {
                  Text(cmd.shortcut)
                    .fontSize(10)
                    .fontColor(this.colors().textMuted)
                    .backgroundColor(this.colors().bgTertiary)
                    .padding({ left: Spacing.SM, right: Spacing.SM, top: 2, bottom: 2 })
                    .borderRadius(Radius.SM)
                }
              }
              .width('100%')
              .height(40)
              .padding({ left: Spacing.LG, right: Spacing.LG })
              .backgroundColor(index === this.selectedIndex ? this.colors().bgActive : Color.Transparent)
              .borderRadius(Radius.SM)
              .onClick(() => { this.selectCommand(cmd); })
            }
          }, (cmd: CommandItem, index: number) => cmd.id)
        }
        .width('100%')
        .constraintSize({ maxHeight: 360 })
        .backgroundColor(this.colors().bgPrimary)
        .scrollBar(BarState.Auto)
        .onKeyEvent((event: KeyEvent) => { this.handleKeyEvent(event); })

        Row() {
          Text('\u2191\u2193 Navigate')
            .fontSize(10)
            .fontColor(this.colors().textMuted)
          Text('\u23CE Select')
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
      .width('78%')
      .constraintSize({ maxWidth: 520 })
      .shadow({ radius: 24, color: 'rgba(0,0,0,0.4)', offsetX: 0, offsetY: 10 })
      .position({ x: '11%', y: '10%' })
    }
    .width('100%')
    .height('100%')
    .zIndex(200)
    }
  }
}
