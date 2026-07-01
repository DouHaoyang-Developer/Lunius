import { LuniusColors, ThemeMode, getColors, Spacing } from '../utils/Theme';
import { vaultIndex } from '../services/VaultIndex';
import { pluginManager } from '../services/PluginManager';
import { LuniusPlugin } from '../models/PluginTypes';
import { VaultStats } from '../services/ApiTypes';

interface StatRow {
  label: string;
  value: string;
}

@Entry
@Component
struct SettingsPage {
  @StorageLink('themeMode') themeMode: ThemeMode = ThemeMode.DARK;
  @StorageLink('editorFontSize') editorFontSize: number = 14;
  @State autoSave: boolean = true;
  @State wordWrap: boolean = true;
  @State showLineNumbers: boolean = false;
  @State vaultStats: VaultStats | null = null;
  @State plugins: LuniusPlugin[] = [];

  aboutToAppear(): void {
    this.loadVaultStats();
    this.loadPlugins();
  }

  private async loadVaultStats(): Promise<void> {
    try {
      this.vaultStats = await vaultIndex.getVaultStats();
    } catch (e) {
      console.error('loadVaultStats error: ' + JSON.stringify(e));
    }
  }

  private loadPlugins(): void {
    this.plugins = pluginManager.getAllPlugins();
  }

  private getColors(): LuniusColors {
    return getColors(this.themeMode);
  }

  private cycleFontSize(): void {
    if (this.editorFontSize >= 18) {
      this.editorFontSize = 12;
    } else if (this.editorFontSize >= 16) {
      this.editorFontSize = 18;
    } else if (this.editorFontSize >= 14) {
      this.editorFontSize = 16;
    } else {
      this.editorFontSize = 14;
    }
  }

  private fontSizeLabel(): string {
    return String(this.editorFontSize) + ' px';
  }

  @Builder
  sectionHeader(title: string) {
    Text(title)
      .fontSize(11)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.getColors().textMuted)
      .width('100%')
      .padding({ left: 16, right: 16, top: 28, bottom: 6 })
      .letterSpacing(1)
  }

  @Builder
  toggleRow(label: string, isOn: boolean, onChange: (val: boolean) => void) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontColor(this.getColors().textPrimary)
        .layoutWeight(1)

      Toggle({ type: ToggleType.Switch, isOn: isOn })
        .selectedColor(this.getColors().accent)
        .onChange(onChange)
    }
    .width('100%')
    .height(48)
    .padding({ left: 16, right: 16 })
    .backgroundColor(this.getColors().bgPrimary)
    .border({ width: { bottom: 1 }, color: this.getColors().divider })
  }

  @Builder
  readOnlyRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontColor(this.getColors().textPrimary)
        .layoutWeight(1)

      Text(value)
        .fontSize(14)
        .fontColor(this.getColors().textMuted)
        .margin({ right: 4 })
    }
    .width('100%')
    .height(44)
    .padding({ left: 16, right: 16 })
    .backgroundColor(this.getColors().bgPrimary)
    .border({ width: { bottom: 1 }, color: this.getColors().divider })
  }

  @Builder
  actionRow(label: string, value: string, onClick: () => void) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontColor(this.getColors().textPrimary)
        .layoutWeight(1)

      Row({ space: 4 }) {
        Text(value)
          .fontSize(14)
          .fontColor(this.getColors().textMuted)
        Text('\u203A')
          .fontSize(16)
          .fontColor(this.getColors().textMuted)
      }
    }
    .width('100%')
    .height(44)
    .padding({ left: 16, right: 16 })
    .backgroundColor(this.getColors().bgPrimary)
    .border({ width: { bottom: 1 }, color: this.getColors().divider })
    .onClick(onClick)
  }

  build() {
    Column() {
      Row() {
        Button({ type: ButtonType.Circle }) {
          Text('\u2190')
            .fontSize(18)
            .fontColor(this.getColors().textPrimary)
        }
        .width(36)
        .height(36)
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          try {
            this.getUIContext().getRouter().back();
          } catch (e) {
            console.error('back error: ' + JSON.stringify(e));
          }
        })

        Text('\u8BBE\u7F6E')
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.getColors().textPrimary)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        Row().width(36)
      }
      .width('100%')
      .height(52)
      .padding({ left: 12, right: 12 })
      .backgroundColor(this.getColors().bgSecondary)
      .border({ width: { bottom: 1 }, color: this.getColors().divider })

      Scroll() {
        Column() {
          this.sectionHeader('\u5916\u89C2')

          this.toggleRow('\u6DF1\u8272\u6A21\u5F0F',
            this.themeMode === ThemeMode.DARK,
            (isOn: boolean): void => {
              this.themeMode = isOn ? ThemeMode.DARK : ThemeMode.LIGHT;
            })

          this.actionRow('\u5B57\u4F53\u5927\u5C0F',
            this.fontSizeLabel(),
            (): void => {
              this.cycleFontSize();
            })

          this.actionRow('\u4E3B\u9898\u8272', '\u7D2B\u7F57\u5170', (): void => {})

          this.sectionHeader('\u7F16\u8F91\u5668')

          this.toggleRow('\u81EA\u52A8\u4FDD\u5B58',
            this.autoSave,
            (val: boolean): void => {
              this.autoSave = val;
            })

          this.toggleRow('\u81EA\u52A8\u6362\u884C',
            this.wordWrap,
            (val: boolean): void => {
              this.wordWrap = val;
            })

          this.toggleRow('\u663E\u793A\u884C\u53F7',
            this.showLineNumbers,
            (val: boolean): void => {
              this.showLineNumbers = val;
            })

          this.actionRow('\u7F29\u8FDB', '4 \u7A7A\u683C', (): void => {})

          this.sectionHeader('\u6587\u4EF6\u4E0E\u94FE\u63A5')

          this.actionRow('\u9ED8\u8BA4\u65B0\u7B14\u8BB0\u4F4D\u7F6E', '/\u672A\u5206\u7C7B', (): void => {})
          this.actionRow('\u9644\u4EF6\u6587\u4EF6\u5939', 'attachments/', (): void => {})
          this.toggleRow('\u4F7F\u7528 Wiki \u94FE\u63A5', true, (_val: boolean): void => {})

          this.sectionHeader('\u540C\u6B65\u4E0E\u7248\u672C')

          this.actionRow('\u7248\u672C\u5386\u53F2',
            '\u67E5\u770B\u7B14\u8BB0\u7248\u672C\u5FEB\u7167',
            (): void => {
              try {
                this.getUIContext().getRouter().pushUrl({
                  url: 'components/VersionHistoryPanel'
                });
              } catch (e) {
                console.error('navigate error: ' + JSON.stringify(e));
              }
            })

          this.actionRow('\u4E91\u540C\u6B65',
            '\u534E\u4E3A\u4E91\u7A7A\u95F4',
            (): void => {
              try {
                this.getUIContext().getRouter().pushUrl({
                  url: 'components/CloudSyncSettings'
                });
              } catch (e) {
                console.error('navigate error: ' + JSON.stringify(e));
              }
            })

          this.sectionHeader('Vault \u7EDF\u8BA1')

          this.readOnlyRow('\u603B\u7B14\u8BB0\u6570',
            this.vaultStats ? String(this.vaultStats.totalNotes) : '...')
          this.readOnlyRow('\u603B\u8BCD\u6570',
            this.vaultStats ? String(this.vaultStats.totalWords) : '...')
          this.readOnlyRow('\u603B\u94FE\u63A5\u6570',
            this.vaultStats ? String(this.vaultStats.totalLinks) : '...')
          this.readOnlyRow('\u603B\u6807\u7B7E\u6570',
            this.vaultStats ? String(this.vaultStats.totalTags) : '...')

          this.sectionHeader('\u63D2\u4EF6\u7BA1\u7406')

          if (this.plugins.length === 0) {
            Text('\u6682\u65E0\u63D2\u4EF6')
              .fontSize(13)
              .fontColor(this.getColors().textMuted)
              .width('100%')
              .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          } else {
            ForEach(this.plugins, (plugin: LuniusPlugin, idx: number) => {
              Column() {
                Row() {
                  Column({ space: 2 }) {
                    Text(plugin.manifest.name)
                      .fontSize(14)
                      .fontColor(this.getColors().textPrimary)
                    Text(plugin.manifest.description)
                      .fontSize(11)
                      .fontColor(this.getColors().textMuted)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    Text('v' + plugin.manifest.version + ' \u00B7 ' + plugin.manifest.author)
                      .fontSize(10)
                      .fontColor(this.getColors().textMuted)
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)

                  Toggle({ type: ToggleType.Switch, isOn: plugin.isEnabled })
                    .selectedColor(this.getColors().accent)
                    .onChange((isOn: boolean): void => {
                      if (isOn) {
                        pluginManager.enable(plugin.manifest.id);
                      } else {
                        pluginManager.disable(plugin.manifest.id);
                      }
                      setTimeout((): void => {
                        this.loadPlugins();
                      }, 300);
                    })
                }
                .width('100%')
                .padding({ left: 16, right: 16, top: 10, bottom: 10 })
              }
              .width('100%')
              .backgroundColor(this.getColors().bgPrimary)
              .border({ width: { bottom: 1 }, color: this.getColors().divider })
            }, (plugin: LuniusPlugin): string => plugin.manifest.id)
          }

          this.sectionHeader('\u5173\u4E8E')

          this.readOnlyRow('\u7248\u672C', 'v1.0.0 (HarmonyOS 5.0)')
          this.readOnlyRow('\u5F00\u6E90\u534F\u8BAE', 'MIT License')
          this.actionRow('\u68C0\u67E5\u66F4\u65B0', '\u5DF2\u662F\u6700\u65B0', (): void => {})

          Row().height(40)
        }
        .width('100%')
      }
      .width('100%')
      .layoutWeight(1)
      .backgroundColor(this.getColors().bgPrimary)
      .scrollBar(BarState.Auto)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.getColors().bgPrimary)
  }
}
