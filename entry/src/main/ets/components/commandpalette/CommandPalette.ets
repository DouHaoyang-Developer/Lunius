// components/commandpalette/CommandPalette.ets
// 命令面板 — Ctrl+P 快速命令
// 设计：居中浮层、搜索框、键盘导航、快捷键提示

import { LuniusColors, ThemeMode, getColors, Spacing, Radius, Icons, Motion } from '../../utils/Theme';
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
    { id: 'new-note', name: '\u65B0\u5EFA\u7B14\u8BB0', icon: Icons.NEW_NOTE, shortcut: 'Ctrl+N' },
    { id: 'open-quick-switcher', name: '\u6253\u5F00\u6587\u4EF6', icon: Icons.SEARCH, shortcut: 'Ctrl+O' },
    { id: 'toggle-source', name: '\u5207\u6362\u6E90\u7801\u6A21\u5F0F', icon: Icons.VIEW_SOURCE, shortcut: 'Ctrl+E' },
    { id: 'toggle-preview', name: '\u5207\u6362\u9605\u8BFB\u6A21\u5F0F', icon: Icons.VIEW_PREVIEW, shortcut: 'Ctrl+Shift+E' },
    { id: 'insert-link', name: '\u63D2\u5165 Wiki \u94FE\u63A5', icon: Icons.LINK, shortcut: 'Ctrl+K' },
    { id: 'insert-image', name: '\u63D2\u5165\u56FE\u7247', icon: Icons.IMAGE, shortcut: '' },
    { id: 'format-bold', name: '\u52A0\u7C97', icon: Icons.BOLD, shortcut: 'Ctrl+B' },
    { id: 'format-italic', name: '\u659C\u4F53', icon: Icons.ITALIC, shortcut: 'Ctrl+I' },
    { id: 'open-daily-note', name: '\u6253\u5F00/\u521B\u5EFA\u4ECA\u65E5\u7B14\u8BB0', icon: Icons.DAILY_NOTE, shortcut: '' },
    { id: 'toggle-bookmark', name: '\u6DFB\u52A0/\u79FB\u9664\u4E66\u7B7E', icon: Icons.BOOKMARK, shortcut: 'Ctrl+M' },
    { id: 'open-graph', name: '\u6253\u5F00\u77E5\u8BC6\u56FE\u8C31', icon: Icons.GRAPH, shortcut: 'Ctrl+G' },
    { id: 'open-settings', name: '\u6253\u5F00\u8BBE\u7F6E', icon: Icons.SETTINGS, shortcut: 'Ctrl+,' }
  ];

  private colors(): LuniusColors {
    return getColors(this.themeMode);
  }

  private filteredCommands(): CommandItem[] {
    if (this.searchText.trim() === '') {
      return this.builtInCommands;
    }
    const q = this.searchText.toLowerCase();
    return this.builtInCommands.filter((cmd: CommandItem) =>
      cmd.name.toLowerCase().includes(q) || cmd.id.includes(q)
    );
  }

  private handleKeyEvent(event: KeyEvent): boolean {
    if (!this.isVisible) return false;

    const KEY_UP = 2024;
    const KEY_DOWN = 2025;
    const KEY_ENTER = 2054;
    const KEY_ESC = 2070;

    if (event.type === KeyType.Down) {
      if (event.keyCode === KEY_ESC) {
        this.onClose();
        return true;
      }
      if (event.keyCode === KEY_UP) {
        if (this.selectedIndex > 0) {
          this.selectedIndex--;
        }
        return true;
      }
      if (event.keyCode === KEY_DOWN) {
        const cmds = this.filteredCommands();
        if (this.selectedIndex < cmds.length - 1) {
          this.selectedIndex++;
        }
        return true;
      }
      if (event.keyCode === KEY_ENTER) {
        const cmds = this.filteredCommands();
        if (this.selectedIndex < cmds.length) {
          const cmd = cmds[this.selectedIndex];
          this.onCommand(cmd.id);
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
  CommandRow(cmd: CommandItem, index: number) {
    Row({ space: Spacing.SM }) {
      // 图标
      Column() {
        Text(cmd.icon)
          .fontSize(14)
          .fontColor(this.colors().textSecondary)
      }
      .width(28).height(28)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(this.colors().surface2)
      .borderRadius(Radius.SM)

      // 名称
      Text(cmd.name)
        .fontSize(13)
        .fontColor(index === this.selectedIndex
          ? this.colors().textPrimary : this.colors().textSecondary)
        .layoutWeight(1)

      // 快捷键
      if (cmd.shortcut) {
        Text(cmd.shortcut)
          .fontSize(10)
          .fontColor(this.colors().textTertiary)
          .backgroundColor(this.colors().surface2)
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .borderRadius(Radius.XS)
      }

      // 选中指示
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
      this.onCommand(cmd.id);
      this.onClose();
    })
  }

  @Builder
  Footer() {
    Row({ space: Spacing.LG }) {
      Row({ space: 4 }) {
        Text('\u2191\u2193')
          .fontSize(10)
          .fontColor(this.colors().textTertiary)
        Text('\u5BFC\u822A')
          .fontSize(10)
          .fontColor(this.colors().textTertiary)
      }
      Row({ space: 4 }) {
        Text('\u23CE')
          .fontSize(10)
          .fontColor(this.colors().textTertiary)
        Text('\u9009\u62E9')
          .fontSize(10)
          .fontColor(this.colors().textTertiary)
      }
      Row({ space: 4 }) {
        Text('Esc')
          .fontSize(10)
          .fontColor(this.colors().textTertiary)
        Text('\u5173\u95ED')
          .fontSize(10)
          .fontColor(this.colors().textTertiary)
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
    if (this.isVisible) {
      Stack() {
        // 背景遮罩
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('rgba(0,0,0,0.3)')
          .onClick(() => this.onClose())

        // 面板
        Column() {
          // 搜索输入
          Row({ space: Spacing.SM }) {
            Text(Icons.SEARCH)
              .fontSize(14)
              .fontColor(this.colors().textTertiary)
            TextInput({ placeholder: '\u8F93\u5165\u547D\u4EE4...', text: $$this.searchText })
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

          // 命令列表
          List({ space: 0 }) {
            ForEach(this.filteredCommands(), (cmd: CommandItem, index: number) => {
              ListItem() {
                this.CommandRow(cmd, index)
              }
            }, (cmd: CommandItem) => cmd.id)
          }
          .width('100%')
          .layoutWeight(1)
          .constraintSize({ maxHeight: 320 })
          .scrollBar(BarState.Off)
          .onKeyEvent((event: KeyEvent) => this.handleKeyEvent(event))

          this.Footer()
        }
        .width('78%')
        .constraintSize({ maxWidth: 520 })
        .backgroundColor(this.colors().surface0)
        .borderRadius(Radius.MD)
        .border({ width: 1, color: this.colors().border })
        .shadow(ShadowStyle.OUTER_FLOATING_MD)
        .position({ x: '11%', y: '10%' })
      }
      .width('100%')
      .height('100%')
      .zIndex(200)
    }
  }
}
