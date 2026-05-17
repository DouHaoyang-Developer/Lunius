// components/commandpalette/CommandPalette.ets
// Obsidian 命令面板 - Ctrl+P 唤起，支持命令搜索与快捷操作

import { ObsidianColors, ThemeMode, getColors } from '../../utils/Theme';

export interface CommandItem {
  id: string;
  name: string;
  icon: string;
  shortcut?: string;
  category: string;
  action: () => void;
}

@Component
export struct CommandPalette {
  @StorageLink('themeMode') themeMode: ThemeMode = ThemeMode.DARK;
  @State query: string = '';
  @State selectedIndex: number = 0;
  @Prop isVisible: boolean = false;
  onClose?: () => void;
  onCommand?: (commandId: string) => void;

  private get colors(): ObsidianColors {
    return getColors(this.themeMode);
  }

  private get commands(): CommandItem[] {
    const all: CommandItem[] = [
      { id: 'new', name: '新建笔记', icon: '📝', shortcut: 'Ctrl+N', category: '文件', action: () => {} },
      { id: 'open', name: '快速打开', icon: '📂', shortcut: 'Ctrl+O', category: '文件', action: () => {} },
      { id: 'save', name: '保存当前笔记', icon: '💾', shortcut: 'Ctrl+S', category: '文件', action: () => {} },
      { id: 'search', name: '全局搜索', icon: '🔍', shortcut: 'Ctrl+Shift+F', category: '搜索', action: () => {} },
      { id: 'graph', name: '打开关系图谱', icon: '📊', shortcut: 'Ctrl+G', category: '视图', action: () => {} },
      { id: 'split', name: '左右分屏', icon: '⇄', shortcut: 'Ctrl+\\', category: '视图', action: () => {} },
      { id: 'preview', name: '切换预览模式', icon: '👁', shortcut: 'Ctrl+E', category: '视图', action: () => {} },
      { id: 'settings', name: '打开设置', icon: '⚙️', shortcut: 'Ctrl+,', category: '系统', action: () => {} },
      { id: 'theme', name: '切换主题', icon: '🌓', shortcut: '', category: '系统', action: () => {} },
      { id: 'sync', name: '立即同步', icon: '⟳', shortcut: '', category: '系统', action: () => {} },
      { id: 'exportPdf', name: '导出 PDF', icon: '🖨', shortcut: '', category: '导出', action: () => { if (this.onCommand) this.onCommand('exportPdf'); } },
      { id: 'exportHtml', name: '导出 HTML', icon: '📄', shortcut: '', category: '导出', action: () => { if (this.onCommand) this.onCommand('exportHtml'); } },
      { id: 'exportMd', name: '导出 Markdown', icon: '📝', shortcut: '', category: '导出', action: () => { if (this.onCommand) this.onCommand('exportMd'); } }
    ];

    if (!this.query) return all;
    const q = this.query.toLowerCase();
    return all.filter(cmd =>
      cmd.name.toLowerCase().includes(q) ||
      cmd.category.toLowerCase().includes(q) ||
      (cmd.shortcut?.toLowerCase().includes(q) ?? false)
    );
  }

  build() {
    Column() {
      // 遮罩背景
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.5)')
        .onClick(() => {
          if (this.onClose) { this.onClose(); }
        })

      // 命令面板浮层
      Column() {
        // 搜索输入
        Row({ space: 8 }) {
          Text('⌘')
            .fontSize(16)
            .fontColor(this.colors.textMuted)

          TextInput({ placeholder: '输入命令或搜索...', text: $$this.query })
            .placeholderColor(this.colors.textMuted)
            .fontColor(this.colors.textPrimary)
            .fontSize(14)
            .height(40)
            .backgroundColor(Color.Transparent)
            .layoutWeight(1)

          if (this.query.length > 0) {
            Button({ type: ButtonType.Circle }) {
              Text('✕')
                .fontSize(12)
                .fontColor(this.colors.textMuted)
            }
            .width(24)
            .height(24)
            .backgroundColor(Color.Transparent)
            .onClick(() => {
              this.query = '';
            })
          }
        }
        .width('100%')
        .height(48)
        .padding({ left: 16, right: 16 })
        .backgroundColor(this.colors.bgSecondary)
        .border({ width: { bottom: 1 }, color: this.colors.divider })

        // 命令列表
        List({ space: 0 }) {
          ForEach(this.commands, (cmd: CommandItem, index: number) => {
            ListItem() {
              Row({ space: 12 }) {
                Text(cmd.icon)
                  .fontSize(16)
                  .width(24)

                Column({ space: 2 }) {
                  Text(cmd.name)
                    .fontSize(14)
                    .fontColor(this.colors.textPrimary)
                    .fontWeight(index === this.selectedIndex ? FontWeight.Medium : FontWeight.Regular)

                  Text(cmd.category)
                    .fontSize(10)
                    .fontColor(this.colors.textMuted)
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                if (cmd.shortcut) {
                  Text(cmd.shortcut)
                    .fontSize(11)
                    .fontColor(this.colors.textMuted)
                    .backgroundColor(this.colors.bgTertiary)
                    .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                    .borderRadius(4)
                }
              }
              .width('100%')
              .height(44)
              .padding({ left: 16, right: 16 })
              .backgroundColor(index === this.selectedIndex ? this.colors.bgActive : Color.Transparent)
              .onClick(() => {
                cmd.action();
                if (this.onClose) { this.onClose(); }
              })
            }
          }, (cmd: CommandItem) => cmd.id)
        }
        .width('100%')
        .constraintSize({ maxHeight: 400 })
        .scrollBar(BarState.Auto)

        // 底部提示
        Row({ space: 16 }) {
          Text('↑↓ 选择')
            .fontSize(10)
            .fontColor(this.colors.textMuted)
          Text('Enter 执行')
            .fontSize(10)
            .fontColor(this.colors.textMuted)
          Text('Esc 关闭')
            .fontSize(10)
            .fontColor(this.colors.textMuted)
        }
        .width('100%')
        .height(32)
        .padding({ left: 16, right: 16 })
        .backgroundColor(this.colors.bgSecondary)
        .border({ width: { top: 1 }, color: this.colors.divider })
      }
      .width('80%')
      .constraintSize({ maxHeight: 480 })
      .backgroundColor(this.colors.bgPrimary)
      .borderRadius(8)
      .shadow({ radius: 16, color: 'rgba(0,0,0,0.3)', offsetX: 0, offsetY: 8 })
      .position({ x: '10%', y: '15%' })
    }
    .width('100%')
    .height('100%')
    .zIndex(200)
  }
}
