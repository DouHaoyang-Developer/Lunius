// components/MobileToolbar.ets
// 移动端编辑工具栏 — 分组式格式化工具
// 设计：水平滚动、分隔线分组、图标统一风格

import { LuniusColors, ThemeMode, getColors, Spacing, Radius, Icons } from '../utils/Theme';

interface ToolbarAction {
  id: string;
  icon: string;
  label: string;
}

@Component
export struct MobileToolbar {
  @StorageLink('themeMode') themeMode: ThemeMode = ThemeMode.DARK;
  onAction: (actionId: string) => void = () => {};

  private actions: ToolbarAction[] = [
    { id: 'heading', icon: 'H', label: '\u6807\u9898' },
    { id: 'bold', icon: 'B', label: '\u52A0\u7C97' },
    { id: 'italic', icon: 'I', label: '\u659C\u4F53' },
    { id: 'strikethrough', icon: '~', label: '\u5220\u9664\u7EBF' },
    { id: 'link', icon: '[[]', label: '\u94FE\u63A5' },
    { id: 'image', icon: Icons.IMAGE, label: '\u56FE\u7247' },
    { id: 'attachment', icon: Icons.ATTACHMENT, label: '\u9644\u4EF6' },
    { id: 'list', icon: Icons.BULLET, label: '\u5217\u8868' },
    { id: 'ordered-list', icon: Icons.NUMBER, label: '\u7F16\u53F7' },
    { id: 'checkbox', icon: Icons.CHECKBOX, label: '\u5F85\u529E' },
    { id: 'code', icon: Icons.CODE, label: '\u4EE3\u7801' },
    { id: 'quote', icon: Icons.QUOTE, label: '\u5F15\u7528' }
  ];

  private colors(): LuniusColors {
    return getColors(this.themeMode);
  }

  @Builder
  ToolButton(action: ToolbarAction) {
    Column() {
      Text(action.icon)
        .fontSize(14)
        .fontColor(this.colors().textPrimary)
        .fontWeight(action.id === 'bold' ? FontWeight.Bold : FontWeight.Medium)
        .fontStyle(action.id === 'italic' ? FontStyle.Italic : FontStyle.Normal)
    }
    .width(36)
    .height(36)
    .justifyContent(FlexAlign.Center)
    .borderRadius(Radius.SM)
    .onClick(() => {
      this.onAction(action.id);
    })
  }

  build() {
    Scroll() {
      Row({ space: Spacing.XS }) {
        // 格式化组
        this.ToolButton(this.actions[0])
        this.ToolButton(this.actions[1])
        this.ToolButton(this.actions[2])
        this.ToolButton(this.actions[3])

        Divider().vertical(true).height(20).color(this.colors().border)

        // 插入组
        this.ToolButton(this.actions[4])
        this.ToolButton(this.actions[5])
        this.ToolButton(this.actions[6])

        Divider().vertical(true).height(20).color(this.colors().border)

        // 块级组
        this.ToolButton(this.actions[7])
        this.ToolButton(this.actions[8])
        this.ToolButton(this.actions[9])
        this.ToolButton(this.actions[10])
        this.ToolButton(this.actions[11])
      }
      .padding({ left: Spacing.SM, right: Spacing.SM })
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
    .height(Spacing.MOBILE_TOOLBAR_HEIGHT)
    .backgroundColor(this.colors().surface1)
    .border({ width: { top: 1 }, color: this.colors().border })
  }
}
