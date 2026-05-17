// pages/SearchPage.ets
// Obsidian 全局搜索页 - 使用 Navigation + NavPathStack 管理多层结果

import { ObsidianColors, ThemeMode, getColors } from '../utils/Theme';
import { FileNode, NodeType } from '../models/FileNode';
import { fileService } from '../services/IFileService';

interface SearchResult {
  file: FileNode;
  matches: string[];
  score: number;
}

@Component
struct SearchContent {
  @Consume('searchPathStack') searchPathStack: NavPathStack;
  @StorageLink('themeMode') themeMode: ThemeMode = ThemeMode.DARK;
  @State query: string = '';
  @State results: SearchResult[] = [];
  @State searchHistory: string[] = ['ArkTS', '响应式', '性能优化', 'HarmonyOS'];

  private get colors(): ObsidianColors {
    return getColors(this.themeMode);
  }

  private async performSearch(keyword: string): Promise<void> {
    if (!keyword.trim()) {
      this.results = [];
      return;
    }
    try {
      const searchResults = await fileService.searchNotes(keyword, { includeContent: true, scope: 'vault' });
      const fileTree = await fileService.getFileTree();
      const allFiles: FileNode[] = [];
      const collect = (nodes: FileNode[]) => {
        for (const n of nodes) {
          if (n.type === NodeType.FILE) allFiles.push(n);
          if (n.children) collect(n.children);
        }
      };
      if (fileTree.length > 0) collect(fileTree);

      const matchMap = new Map(searchResults.map(r => [r.noteId, r]));
      this.results = [];
      for (let i = 0; i < allFiles.length; i++) {
        const f = allFiles[i];
        const id = f.id;
        let isMatch = matchMap.has(id) || f.name.toLowerCase().includes(keyword.toLowerCase());
        // 别名匹配
        if (!isMatch) {
          try {
            const meta = await fileService.getMetadata(id);
            const aliases: string[] = meta.aliases || [];
            for (let j = 0; j < aliases.length; j++) {
              if (aliases[j].toLowerCase().includes(keyword.toLowerCase())) {
                isMatch = true;
                break;
              }
            }
          } catch (e) { /* skip */ }
        }
        if (isMatch) {
          const sr: SearchResult = {
            file: f,
            matches: [f.name],
            score: 50
          };
          this.results.push(sr);
        }
      }
      this.results.sort((a: SearchResult, b: SearchResult): number => b.score - a.score);
    } catch (e) {
      console.error('Search error: ' + JSON.stringify(e));
    }
  }

  build() {
    Column() {
      // 搜索栏
      Row({ space: 8 }) {
        TextInput({ placeholder: '搜索笔记、标签、内容...', text: $$this.query })
          .placeholderColor(this.colors.textMuted)
          .fontColor(this.colors.textPrimary)
          .fontSize(14)
          .height(40)
          .backgroundColor(this.colors.bgTertiary)
          .borderRadius(8)
          .layoutWeight(1)
          .padding({ left: 12, right: 12 })
          .onChange((value: string) => {
            this.query = value;
            this.performSearch(value);
          })

        Button({ type: ButtonType.Circle }) {
          Text('✕')
            .fontSize(14)
            .fontColor(this.colors.textMuted)
        }
        .width(32)
        .height(32)
        .backgroundColor(Color.Transparent)
        .visibility(this.query.length > 0 ? Visibility.Visible : Visibility.Hidden)
        .onClick(() => {
          this.query = '';
          this.results = [];
        })
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .backgroundColor(this.colors.bgSecondary)
      .border({ width: { bottom: 1 }, color: this.colors.divider })

      if (this.query.length === 0) {
        // 历史记录与建议
        Column({ space: 16 }) {
          Text('最近搜索')
            .fontSize(12)
            .fontColor(this.colors.textMuted)
            .width('100%')
            .padding({ left: 16, right: 16, top: 16 })

          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
            ForEach(this.searchHistory, (item: string, index: number) => {
              Text(item)
                .fontSize(13)
                .fontColor(this.colors.textSecondary)
                .backgroundColor(this.colors.bgTertiary)
                .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                .borderRadius(16)
                .margin(4)
                .onClick(() => {
                  this.query = item;
                  this.performSearch(item);
                })
            }, (item: string) => item)
          }
          .width('100%')
          .padding({ left: 12, right: 12 })

          Text('搜索选项')
            .fontSize(12)
            .fontColor(this.colors.textMuted)
            .width('100%')
            .padding({ left: 16, right: 16, top: 24 })

          Column({ space: 0 }) {
            ForEach(['仅搜索标题', '包含内容', '区分大小写', '正则表达式'], (opt: string, idx: number) => {
              Row() {
                Text(opt)
                  .fontSize(14)
                  .fontColor(this.colors.textPrimary)
                  .layoutWeight(1)
                Toggle({ type: ToggleType.Checkbox, isOn: idx === 0 })
                  .selectedColor(this.colors.accent)
              }
              .width('100%')
              .height(44)
              .padding({ left: 16, right: 16 })
              .backgroundColor(this.colors.bgPrimary)
              .border({ width: { bottom: 1 }, color: this.colors.divider })
            }, (opt: string) => opt)
          }
          .width('100%')
        }
        .width('100%')
        .layoutWeight(1)
      } else {
        // 搜索结果列表
        List({ space: 0 }) {
          ForEach(this.results, (res: SearchResult, index: number) => {
            ListItem() {
              Column({ space: 4 }) {
                Row({ space: 8 }) {
                  Text('📄')
                    .fontSize(14)
                  Text(res.file.name)
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.colors.textPrimary)
                    .layoutWeight(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .maxLines(1)
                  Text(`${res.file.wordCount} 字`)
                    .fontSize(11)
                    .fontColor(this.colors.textMuted)
                }
                .width('100%')

                Text(res.matches[0])
                  .fontSize(12)
                  .fontColor(this.colors.textSecondary)
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .margin({ left: 22 })

                // 标签
                if (res.file.tags && res.file.tags.length > 0) {
                  Row({ space: 4 }) {
                    ForEach(res.file.tags, (tag: string) => {
                      Text(`#${tag}`)
                        .fontSize(11)
                        .fontColor(this.colors.tagText)
                        .backgroundColor(this.colors.tagBg)
                        .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                        .borderRadius(10)
                    }, (tag: string) => tag)
                  }
                  .width('100%')
                  .margin({ left: 22, top: 4 })
                }
              }
              .width('100%')
              .padding(12)
              .backgroundColor(this.colors.bgPrimary)
              .border({ width: { bottom: 1 }, color: this.colors.divider })
              .onClick(() => {
                // 进入搜索结果详情页（Navigation 栈推进）
                this.searchPathStack.pushPathByName('searchDetail', new Object());
              })
            }
          }, (res: SearchResult, index: number) => res.file.id)
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
        .padding({ top: 8 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.colors.bgPrimary)
  }
}

@Component
struct SearchDetailPage {
  @Consume('searchPathStack') searchPathStack: NavPathStack;
  @StorageLink('themeMode') themeMode: ThemeMode = ThemeMode.DARK;
  @State fileId: string = '';

  aboutToAppear(): void {
    const params: Object = this.searchPathStack.getParamByName('searchDetail');
    if (params) {
      this.fileId = '';
    }
  }

  build() {
    Column() {
      Row() {
        Button({ type: ButtonType.Circle }) {
          Text('←')
            .fontSize(18)
            .fontColor(getColors(this.themeMode).textPrimary)
        }
        .width(36)
        .height(36)
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          this.searchPathStack.pop();
        })

        Text('搜索结果详情')
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(getColors(this.themeMode).textPrimary)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        Row().width(36)
      }
      .width('100%')
      .height(52)
      .padding({ left: 12, right: 12 })
      .backgroundColor(getColors(this.themeMode).bgSecondary)
      .border({ width: { bottom: 1 }, color: getColors(this.themeMode).divider })

      Text(`文件 ID: ${this.fileId}`)
        .fontSize(14)
        .fontColor(getColors(this.themeMode).textSecondary)
        .margin(24)

      Text('此处可渲染该文件的 Markdown 预览或高亮匹配文本')
        .fontSize(13)
        .fontColor(getColors(this.themeMode).textMuted)
        .margin({ left: 24, right: 24 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(getColors(this.themeMode).bgPrimary)
  }
}

@Entry
@Component
struct SearchPage {
  @Provide('searchPathStack') searchPathStack: NavPathStack = new NavPathStack();

  @Builder
  SearchPageMap(name: string) {
    if (name === 'searchDetail') {
      SearchDetailPage()
    }
  }

  build() {
    Navigation(this.searchPathStack) {
      SearchContent()
    }
    .hideTitleBar(true)
    .navDestination(this.SearchPageMap)
    .mode(NavigationMode.Stack)
    .width('100%')
    .height('100%')
  }
}
