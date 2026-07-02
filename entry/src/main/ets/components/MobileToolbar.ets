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
    { id: 'bold', icon: 'B', label: '\u52A0\u7C97' },
    { id: 'italic', icon: 'I', label: '\u659C\u4F53' },
    { id: 'heading', icon: 'H', label: '\u6807\u9898' },
    { id: 'strikethrough', icon: '~', label: '\u5220\u9664\u7EBF' },
    { id: 'link', icon: '[[]', label: '\u94FE\u63A5' },
    { id: 'image', icon: Icons.IMAGE, label: '\u56FE\u7247' },
    { id: 'attachment', icon: Icons.ATTACHMENT, label: '\u9644\u4EF6' },
    { id: 'list', icon: Icons.BULLET, label: '\u5217\u8868' },
    { id: 'checklist', icon: Icons.CHECK, label: '\u5F85\u529E' },
    { id: 'quote', icon: '\u201C', label: '\u5F15\u7528' },
    { id: 'code', icon: '<>', label: '\u4EE3\u7801' },
    { id: 'save', icon: Icons.SAVE, label: '\u4FDD\u5B58' },
    { id: 'find', icon: Icons.SEARCH, label: '\u67E5\u627E' }
  ];

  private colors(): LuniusColors {
    return getColors(this.themeMode);
  }

  private isSpecialIcon(icon: string): boolean {
    return icon.length > 1 && icon !== '<>' && icon !== '[[]';
  }

  build() {
    Scroll() {
      Row({ space: 2 }) {
        ForEach(this.actions, (action: ToolbarAction) => {
          Button({ type: ButtonType.Circle }) {
            if (this.isSpecialIcon(action.icon)) {
              Text(action.icon)
                .fontSize(16)
                .fontColor(this.colors().iconPrimary)
            } else {
              Text(action.icon)
                .fontSize(14)
                .fontWeight(action.id === 'bold' ? FontWeight.Bold
                  : action.id === 'italic' ? FontWeight.Regular : FontWeight.Medium)
                .fontStyle(action.id === 'italic' ? FontStyle.Italic : FontStyle.Normal)
                .fontColor(this.colors().iconPrimary)
            }
          }
          .width(36)
          .height(36)
          .backgroundColor(Color.Transparent)
          .borderRadius(Radius.SM)
          .onClick(() => {
            this.onAction(action.id);
          })
        }, (action: ToolbarAction) => action.id)
      }
      .padding({ left: Spacing.SM, right: Spacing.SM })
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
    .height(Spacing.MOBILE_TOOLBAR_HEIGHT)
    .backgroundColor(this.colors().mobileToolbarBg)
    .border({ width: { top: 1 }, color: this.colors().divider })
  }
}
