// pages/SettingsPage.ets
// Obsidian 设置页 - 通过 router.pushUrl 进入的独立页面

import { ObsidianColors, ThemeMode, getColors } from '../utils/Theme';
import { vaultIndex } from '../services/VaultIndex';
import { VaultStats } from '../services/ApiTypes';
import { pluginManager } from '../services/PluginManager';
import { LuniusPlugin } from '../models/PluginTypes';

@Entry
@Component
struct SettingsPage {
  @StorageLink('themeMode') themeMode: ThemeMode = ThemeMode.DARK;
  @State fontSize: number = 14;
  @State lineHeight: number = 1.6;
  @State wordWrap: boolean = true;
  @State autoSave: boolean = true;
  @State showLineNumber: boolean = false;
  @State vaultStats: VaultStats | null = null;
  @State plugins: LuniusPlugin[] = [];

  aboutToAppear(): void {
    this.loadStats();
    this.loadPlugins();
  }

  async loadStats(): Promise<void> {
    try {
      this.vaultStats = await vaultIndex.getVaultStats();
    } catch (e) {
      console.error('Failed to load vault stats: ' + JSON.stringify(e));
    }
  }

  async loadPlugins(): Promise<void> {
    this.plugins = pluginManager.getAllPlugins();
  }

  private get colors(): ObsidianColors {
    return getColors(this.themeMode);
  }

  @Builder
  SectionTitle(title: string) {
    Text(title)
      .fontSize(12)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.colors.textMuted)
      .margin({ top: 24, bottom: 8, left: 16, right: 16 })
      .letterSpacing(1)
  }

  @Builder
  SettingItem(label: string, value: string, onClick?: () => void) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontColor(this.colors.textPrimary)
        .layoutWeight(1)

      Row({ space: 4 }) {
        Text(value)
          .fontSize(14)
          .fontColor(this.colors.textMuted)
        Text('›')
          .fontSize(14)
          .fontColor(this.colors.textMuted)
      }
    }
    .width('100%')
    .height(48)
    .padding({ left: 16, right: 16 })
    .backgroundColor(this.colors.bgPrimary)
    .border({ width: { bottom: 1 }, color: this.colors.divider })
    .onClick(() => {
      if (onClick) onClick();
    })
  }

  @Builder
  ToggleItem(label: string, isOn: boolean, onChange: (val: boolean) => void) {
    Row() {
      Column({ space: 2 }) {
        Text(label)
          .fontSize(14)
          .fontColor(this.colors.textPrimary)
        Text('重启后生效')
          .fontSize(11)
          .fontColor(this.colors.textMuted)
          .visibility(Visibility.None) // 预留提示位
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Toggle({ type: ToggleType.Switch, isOn: isOn })
        .selectedColor(this.colors.accent)
        .onChange(onChange)
    }
    .width('100%')
    .height(48)
    .padding({ left: 16, right: 16 })
    .backgroundColor(this.colors.bgPrimary)
    .border({ width: { bottom: 1 }, color: this.colors.divider })
  }

  build() {
    Column() {
      // 顶部导航栏
      Row() {
        Button({ type: ButtonType.Circle }) {
          Text('←')
            .fontSize(18)
            .fontColor(this.colors.textPrimary)
        }
        .width(36)
        .height(36)
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          try {
            this.getUIContext().getRouter().back();
          } catch (e) {
            console.error('back error:', JSON.stringify(e));
          }
        })

        Text('设置')
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.colors.textPrimary)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        Row().width(36) // 占位保持标题居中
      }
      .width('100%')
      .height(52)
      .padding({ left: 12, right: 12 })
      .backgroundColor(this.colors.bgSecondary)
      .border({ width: { bottom: 1 }, color: this.colors.divider })

      Scroll() {
        Column() {
          // 外观
          this.SectionTitle('外观');
          this.ToggleItem('深色模式', this.themeMode === ThemeMode.DARK, (isOn: boolean) => {
            this.themeMode = isOn ? ThemeMode.DARK : ThemeMode.LIGHT;
          });
          this.SettingItem('主题色', '紫罗兰', () => {});
          this.SettingItem('字体', '系统默认', () => {});
          this.SettingItem('字体大小', `${this.fontSize}px`, () => {
            this.fontSize = this.fontSize >= 20 ? 12 : this.fontSize + 2;
          });

          // 编辑器
          this.SectionTitle('编辑器');
          this.ToggleItem('自动保存', this.autoSave, (v) => this.autoSave = v);
          this.ToggleItem('自动换行', this.wordWrap, (v) => this.wordWrap = v);
          this.ToggleItem('显示行号', this.showLineNumber, (v) => this.showLineNumber = v);
          this.SettingItem('行高', `${this.lineHeight}`, () => {
            this.lineHeight = this.lineHeight >= 2.0 ? 1.2 : this.lineHeight + 0.2;
          });
          this.SettingItem('缩进', '4 空格', () => {});

          // 文件与链接
          this.SectionTitle('文件与链接');
          this.SettingItem('默认新笔记位置', '/未分类', () => {});
          this.SettingItem('附件文件夹', 'attachments/', () => {});
          this.ToggleItem('使用 Wiki 链接', true, () => {});
          this.ToggleItem('自动格式化', false, () => {});

          // Vault 统计
          this.SectionTitle('Vault 统计');
          this.SettingItem('总笔记数', `${this.vaultStats?.totalNotes ?? '...'}`, () => {});
          this.SettingItem('总词数', `${this.vaultStats?.totalWords ?? '...'}`, () => {});
          this.SettingItem('总链接数', `${this.vaultStats?.totalLinks ?? '...'}`, () => {});
          this.SettingItem('总标签数', `${this.vaultStats?.totalTags ?? '...'}`, () => {});

          // 插件管理
          this.SectionTitle('插件管理');

          if (this.plugins.length === 0) {
            Text('暂无插件')
              .fontSize(13).fontColor(this.colors.textMuted)
              .width('100%').padding({ left: 16, right: 16, top: 8, bottom: 8 })
          } else {
            ForEach(this.plugins, (plugin: LuniusPlugin) => {
              Column() {
                Row() {
                  Column({ space: 2 }) {
                    Text(plugin.manifest.name)
                      .fontSize(14).fontColor(this.colors.textPrimary)
                    Text(plugin.manifest.description)
                      .fontSize(11).fontColor(this.colors.textMuted)
                      .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                    Text(`v${plugin.manifest.version} · ${plugin.manifest.author}`)
                      .fontSize(10).fontColor(this.colors.textMuted)
                  }
                  .alignItems(HorizontalAlign.Start).layoutWeight(1)

                  Toggle({ type: ToggleType.Switch, isOn: plugin.isEnabled })
                    .selectedColor(this.colors.accent)
                    .onChange(async (isOn: boolean) => {
                      if (isOn) {
                        await pluginManager.enable(plugin.manifest.id);
                      } else {
                        await pluginManager.disable(plugin.manifest.id);
                      }
                      this.loadPlugins();
                    })
                }
                .width('100%').padding({ left: 16, right: 16, top: 10, bottom: 10 })
              }
              .width('100%').backgroundColor(this.colors.bgPrimary)
              .border({ width: { bottom: 1 }, color: this.colors.divider })
            }, (plugin: LuniusPlugin) => plugin.manifest.id)
          }

          // 关于
          this.SectionTitle('关于');
          this.SettingItem('版本', 'v1.0.0 (HarmonyOS 5.0)', () => {});
          this.SettingItem('开源协议', 'MIT License', () => {});
          this.SettingItem('检查更新', '已是最新', () => {});

          Row().height(40) // 底部留白
        }
        .width('100%')
      }
      .width('100%')
      .layoutWeight(1)
      .backgroundColor(this.colors.bgPrimary)
      .scrollBar(BarState.Auto)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.colors.bgPrimary)
  }
}
