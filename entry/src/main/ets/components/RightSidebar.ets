// components/RightSidebar.ets
// 右侧边栏容器（大纲 + 反向链接）

import { ObsidianColors, ThemeMode, getColors, SidebarWidth, DeviceType } from '../utils/Theme';
import { ResponsiveState } from '../utils/ResponsiveLayout';
import { OutlineView } from './OutlineView';
import { BacklinksView } from './BacklinksView';
import { OutlineNode, Backlink, MockTags } from '../models/FileNode';
import { NoteViewModel } from '../viewmodels/NoteViewModel';

@Component
export struct RightSidebar {
  @StorageLink('themeMode') themeMode: ThemeMode = ThemeMode.DARK;
  @ObjectLink responsive: ResponsiveState;
  @ObjectLink vm: NoteViewModel;
  @Prop isVisible: boolean = true;
  @Prop panelWidth: number = SidebarWidth.PC_RIGHT;
  onClose?: () => void;

  private get colors(): ObsidianColors {
    return getColors(this.themeMode);
  }

  private getOutline(): OutlineNode[] {
    if (!this.vm.content) return [];
    const lines = this.vm.content.split('\n');
    const outline: OutlineNode[] = [];
    for (let i = 0; i < lines.length; i++) {
      const match = lines[i].match(/^(#{1,6})\s+(.*)/);
      if (match) {
        outline.push({ level: match[1].length, title: match[2], line: i });
      }
    }
    return outline;
  }

  private getBacklinks(): Backlink[] {
    if (!this.vm.metadata) return [];
    const result: Backlink[] = [];
    const bl = this.vm.metadata.backlinks;
    for (let i = 0; i < bl.length; i++) {
      const item: Backlink = { source: bl[i], context: '', line: 0 };
      result.push(item);
    }
    return result;
  }

  private getTags(): string[] {
    return this.vm.metadata?.tags ?? [];
  }

  build() {
    Column() {
      Row()
        .width(4).height('100%')
        .backgroundColor(this.colors.divider)
        .position({ x: 0 })

      Column() {
        Row() {
          Text('面板')
            .fontSize(14).fontWeight(FontWeight.Medium)
            .fontColor(this.colors.textSecondary)

          if (!this.responsive.isPC) {
            Button({ type: ButtonType.Circle }) {
              Text('✕').fontSize(12).fontColor(this.colors.textMuted)
            }
            .width(24).height(24).backgroundColor(Color.Transparent)
            .onClick(() => {
              if (this.onClose) this.onClose();
            })
          }
        }
        .width('100%').height(40)
        .padding({ left: 16, right: 12 })
        .justifyContent(FlexAlign.SpaceBetween)
        .backgroundColor(this.colors.sidebarBg)
        .border({ width: { bottom: 1 }, color: this.colors.divider })

        OutlineView({ data: this.getOutline() })
          .height('50%')

        Divider().color(this.colors.divider).strokeWidth(1)

        BacklinksView({
          backlinks: this.getBacklinks(),
          tags: this.getTags()
        })
        .height('50%')
      }
      .width('100%').height('100%')
      .padding({ left: 4 })
    }
    .width(this.isVisible ? this.panelWidth : 0)
    .height('100%')
    .backgroundColor(this.colors.sidebarBg)
    .border({ width: { left: 1 }, color: this.colors.divider })
    .animation({ duration: 300, curve: Curve.EaseInOut })
  }
}
