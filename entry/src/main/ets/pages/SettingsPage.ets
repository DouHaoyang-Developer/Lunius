// pages/SettingsPage.ets
// 设置页 — 分组卡片式设计
// 设计：圆角分组卡片、统一行高、清晰的视觉层次

import { LuniusColors, ThemeMode, getColors, Spacing, Radius, Icons } from '../utils/Theme';
import { vaultIndex } from '../services/VaultIndex';
import { pluginManager } from '../services/PluginManager';
import { LuniusPlugin } from '../models/PluginTypes';
import { VaultStats } from '../services/ApiTypes';

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
  SectionHeader(title: string) {
    Text(title)
      .fontSize(12)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.getColors().textTertiary)
      .width('100%')
      .padding({ left: Spacing.LG, right: Spacing.LG, top: Spacing.XL, bottom: Spacing.SM })
      .letterSpacing(0.5)
  }

  @Builder
  ToggleRow(label: string, isOn: boolean, onChange: (val: boolean) => void) {
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
    .padding({ left: Spacing.LG, right: Spacing.LG })
    .backgroundColor(this.getColors().surface2)
    .border({ width: { bottom: 1 }, color: this.getColors().border })
  }

  @Builder
  ReadOnlyRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontColor(this.getColors().textPrimary)
        .layoutWeight(1)

      Text(value)
        .fontSize(14)
        .fontColor(this.getColors().textTertiary)
        .margin({ right: 4 })
    }
    .width('100%')
    .height(44)
    .padding({ left: Spacing.LG, right: Spacing.LG })
    .backgroundColor(this.getColors().surface2)
    .border({ width: { bottom: 1 }, color: this.getColors().border })
  }

  @Builder
  ActionRow(label: string, value: string, onClick: () => void) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontColor(this.getColors().textPrimary)
        .layoutWeight(1)

      Row({ space: 4 }) {
        Text(value)
          .fontSize(13)
          .fontColor(this.getColors().textTertiary)
        Text('\u203A')
          .fontSize(14)
          .fontColor(this.getColors().textTertiary)
      }
    }
    .width('100%')
    .height(44)
    .padding({ left: Spacing.LG, right: Spacing.LG })
    .backgroundColor(this.getColors().surface2)
    .border({ width: { bottom: 1 }, color: this.getColors().border })
    .onClick(onClick)
  }

  @Builder
  StatCard(label: string, value: string) {
    Column({ space: 4 }) {
      Text(value)
        .fontSize(22)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.getColors().textPrimary)
      Text(label)
        .fontSize(11)
        .fontColor(this.getColors().textTertiary)
    }
    .width('100%')
    .padding({ top: Spacing.MD, bottom: Spacing.MD })
    .backgroundColor(this.getColors().surface2)
    .borderRadius(Radius.MD)
    .border({ width: 1, color: this.getColors().border })
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    Column() {
      // 顶部导航栏
      Row() {
        Column() {
          Text(Icons.BACK)
            .fontSize(16)
            .fontColor(this.getColors().textPrimary)
        }
        .width(36)
        .height(36)
        .justifyContent(FlexAlign.Center)
        .borderRadius(Radius.SM)
        .onClick(() => {
          try {
            this.getUIContext().getRouter().back();
          } catch (e) {
            console.error('back error: ' + JSON.stringify(e));
          }
        })

        Text('\u8BBE\u7F6E')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.getColors().textPrimary)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        Row().width(36)
      }
      .width('100%')
      .height(52)
      .padding({ left: Spacing.SM, right: Spacing.SM })
      .backgroundColor(this.getColors().surface1)
      .border({ width: { bottom: 1 }, color: this.getColors().border })

      Scroll() {
        Column() {
          // 外观
          this.SectionHeader('\u5916\u89C2')
          Column() {
            this.ToggleRow('\u6DF1\u8272\u6A21\u5F0F',
              this.themeMode === ThemeMode.DARK,
              (isOn: boolean): void => {
                this.themeMode = isOn ? ThemeMode.DARK : ThemeMode.LIGHT;
              })
            this.ActionRow('\u5B57\u4F53\u5927\u5C0F',
              this.fontSizeLabel(),
              (): void => { this.cycleFontSize(); })
            this.ActionRow('\u4E3B\u9898\u8272', '\u7D2B\u7F57\u5170', (): void => {})
          }
          .width('100%')
          .margin({ left: Spacing.LG, right: Spacing.LG })
          .backgroundColor(this.getColors().surface2)
          .borderRadius(Radius.MD)
          .border({ width: 1, color: this.getColors().border })
          .clip(true)

          // 编辑器
          this.SectionHeader('\u7F16\u8F91\u5668')
          Column() {
            this.ToggleRow('\u81EA\u52A8\u4FDD\u5B58', this.autoSave,
              (val: boolean): void => { this.autoSave = val; })
            this.ToggleRow('\u81EA\u52A8\u6362\u884C', this.wordWrap,
              (val: boolean): void => { this.wordWrap = val; })
            this.ToggleRow('\u663E\u793A\u884C\u53F7', this.showLineNumbers,
              (val: boolean): void => { this.showLineNumbers = val; })
            this.ActionRow('\u7F29\u8FDB', '4 \u7A7A\u683C', (): void => {})
          }
          .width('100%')
          .margin({ left: Spacing.LG, right: Spacing.LG })
          .backgroundColor(this.getColors().surface2)
          .borderRadius(Radius.MD)
          .border({ width: 1, color: this.getColors().border })
          .clip(true)

          // 文件与链接
          this.SectionHeader('\u6587\u4EF6\u4E0E\u94FE\u63A5')
          Column() {
            this.ActionRow('\u9ED8\u8BA4\u65B0\u7B14\u8BB0\u4F4D\u7F6E', '/\u672A\u5206\u7C7B', (): void => {})
            this.ActionRow('\u9644\u4EF6\u6587\u4EF6\u5939', 'attachments/', (): void => {})
            this.ToggleRow('\u4F7F\u7528 Wiki \u94FE\u63A5', true, (_val: boolean): void => {})
          }
          .width('100%')
          .margin({ left: Spacing.LG, right: Spacing.LG })
          .backgroundColor(this.getColors().surface2)
          .borderRadius(Radius.MD)
          .border({ width: 1, color: this.getColors().border })
          .clip(true)

          // 同步与版本
          this.SectionHeader('\u540C\u6B65\u4E0E\u7248\u672C')
          Column() {
            this.ActionRow('\u7248\u672C\u5386\u53F2',
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
            this.ActionRow('\u4E91\u540C\u6B65', '\u534E\u4E3A\u4E91\u7A7A\u95F4',
              (): void => {
                try {
                  this.getUIContext().getRouter().pushUrl({
                    url: 'components/CloudSyncSettings'
                  });
                } catch (e) {
                  console.error('navigate error: ' + JSON.stringify(e));
                }
              })
          }
          .width('100%')
          .margin({ left: Spacing.LG, right: Spacing.LG })
          .backgroundColor(this.getColors().surface2)
          .borderRadius(Radius.MD)
          .border({ width: 1, color: this.getColors().border })
          .clip(true)

          // Vault 统计 — 卡片网格
          this.SectionHeader('Vault \u7EDF\u8BA1')
          Row({ space: Spacing.SM }) {
            Column() {
              this.StatCard('\u603B\u7B14\u8BB0',
                this.vaultStats ? String(this.vaultStats.totalNotes) : '...')
            }.layoutWeight(1)
            Column() {
              this.StatCard('\u603B\u8BCD\u6570',
                this.vaultStats ? String(this.vaultStats.totalWords) : '...')
            }.layoutWeight(1)
          }
          .width('100%')
          .padding({ left: Spacing.LG, right: Spacing.LG })

          Row({ space: Spacing.SM }) {
            Column() {
              this.StatCard('\u603B\u94FE\u63A5',
                this.vaultStats ? String(this.vaultStats.totalLinks) : '...')
            }.layoutWeight(1)
            Column() {
              this.StatCard('\u603B\u6807\u7B7E',
                this.vaultStats ? String(this.vaultStats.totalTags) : '...')
            }.layoutWeight(1)
          }
          .width('100%')
          .padding({ left: Spacing.LG, right: Spacing.LG })

          // 插件管理
          this.SectionHeader('\u63D2\u4EF6\u7BA1\u7406')
          if (this.plugins.length === 0) {
            Column({ space: Spacing.SM }) {
              Text(Icons.PLUGIN)
                .fontSize(28)
                .fontColor(this.getColors().textTertiary)
              Text('\u6682\u65E0\u63D2\u4EF6')
                .fontSize(13)
                .fontColor(this.getColors().textTertiary)
            }
            .width('100%')
            .padding({ top: Spacing.XL, bottom: Spacing.XL })
            .backgroundColor(this.getColors().surface2)
            .borderRadius(Radius.MD)
            .margin({ left: Spacing.LG, right: Spacing.LG })
            .border({ width: 1, color: this.getColors().border })
          } else {
            Column() {
              ForEach(this.plugins, (plugin: LuniusPlugin, _idx: number) => {
                Row() {
                  Column({ space: 2 }) {
                    Text(plugin.manifest.name)
                      .fontSize(14)
                      .fontColor(this.getColors().textPrimary)
                    Text(plugin.manifest.description)
                      .fontSize(11)
                      .fontColor(this.getColors().textTertiary)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    Text('v' + plugin.manifest.version + ' \u00B7 ' + plugin.manifest.author)
                      .fontSize(10)
                      .fontColor(this.getColors().textTertiary)
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
                      setTimeout((): void => { this.loadPlugins(); }, 300);
                    })
                }
                .width('100%')
                .height(64)
                .padding({ left: Spacing.LG, right: Spacing.LG })
                .border({ width: { bottom: 1 }, color: this.getColors().border })
              }, (plugin: LuniusPlugin): string => plugin.manifest.id)
            }
            .width('100%')
            .margin({ left: Spacing.LG, right: Spacing.LG })
            .backgroundColor(this.getColors().surface2)
            .borderRadius(Radius.MD)
            .border({ width: 1, color: this.getColors().border })
            .clip(true)
          }

          // 关于
          this.SectionHeader('\u5173\u4E8E')
          Column() {
            this.ReadOnlyRow('\u7248\u672C', 'v1.0.0 (HarmonyOS 5.0)')
            this.ReadOnlyRow('\u5F00\u6E90\u534F\u8BAE', 'MIT License')
            this.ActionRow('\u68C0\u67E5\u66F4\u65B0', '\u5DF2\u662F\u6700\u65B0', (): void => {})
          }
          .width('100%')
          .margin({ left: Spacing.LG, right: Spacing.LG })
          .backgroundColor(this.getColors().surface2)
          .borderRadius(Radius.MD)
          .border({ width: 1, color: this.getColors().border })
          .clip(true)

          Row().height(Spacing.XL)
        }
        .width('100%')
      }
      .width('100%')
      .layoutWeight(1)
      .backgroundColor(this.getColors().surface0)
      .scrollBar(BarState.Auto)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.getColors().surface0)
  }
}
