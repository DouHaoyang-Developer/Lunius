// pages/SearchPage.ets
// 全局搜索页 — 搜索栏 + 选项 + 历史/结果列表
// 设计：统一搜索栏样式、标签式选项开关、卡片式结果项

import { LuniusColors, ThemeMode, getColors, Spacing, Radius, Icons } from '../utils/Theme';
import { fileService, SearchOptions } from '../services/IFileService';
import { FileNode, NodeType } from '../models/FileNode';

interface SearchResultItem {
  file: FileNode;
  snippet: string;
  score: number;
}

@Component
struct SearchContent {
  @Consume('searchNavStack') searchNavStack: NavPathStack;
  @StorageLink('themeMode') themeMode: ThemeMode = ThemeMode.DARK;
  @State query: string = '';
  @State results: SearchResultItem[] = [];
  @State searchHistory: string[] = ['ArkTS', 'HarmonyOS', '性能优化', '响应式设计'];
  @State caseSensitive: boolean = false;
  @State useRegex: boolean = false;
  @State hoverIndex: number = -1;

  private getColors(): LuniusColors {
    return getColors(this.themeMode);
  }

  private async doSearch(keyword: string): Promise<void> {
    if (!keyword.trim()) {
      this.results = [];
      return;
    }
    try {
      const opts: SearchOptions = {
        includeContent: true,
        caseSensitive: this.caseSensitive,
        regex: this.useRegex,
        scope: 'vault'
      };
      const searchResults = await fileService.searchNotes(keyword, opts);
      const fileTree = await fileService.getFileTree();
      const allFiles: FileNode[] = [];
      const collect = (nodes: FileNode[]): void => {
        for (let i = 0; i < nodes.length; i++) {
          const n = nodes[i];
          if (n.type === NodeType.FILE) {
            allFiles.push(n);
          }
          if (n.children) {
            collect(n.children);
          }
        }
      };
      if (fileTree.length > 0) {
        collect(fileTree);
      }

      const matchMap = new Map<string, SearchResultItem>();
      for (let i = 0; i < searchResults.length; i++) {
        const r = searchResults[i];
        const snippet = r.matches.length > 0 ? r.matches[0].text : '';
        const item: SearchResultItem = {
          file: { id: r.noteId, name: r.title, type: NodeType.FILE, path: r.path },
          snippet: snippet,
          score: r.score
        };
        matchMap.set(r.noteId, item);
      }

      const merged: SearchResultItem[] = [];
      for (let i = 0; i < allFiles.length; i++) {
        const f = allFiles[i];
        const found = matchMap.get(f.id);
        if (found) {
          merged.push(found);
        } else {
          let nameMatch = false;
          const targetName = this.caseSensitive ? f.name : f.name.toLowerCase();
          const targetKeyword = this.caseSensitive ? keyword : keyword.toLowerCase();
          if (targetName.indexOf(targetKeyword) >= 0) {
            nameMatch = true;
          }
          if (!nameMatch) {
            try {
              const meta = await fileService.getMetadata(f.id);
              const aliases: string[] = meta.aliases || [];
              for (let j = 0; j < aliases.length; j++) {
                const targetAlias = this.caseSensitive ? aliases[j] : aliases[j].toLowerCase();
                if (targetAlias.indexOf(targetKeyword) >= 0) {
                  nameMatch = true;
                  break;
                }
              }
            } catch (e) {
              // ignore
            }
          }
          if (nameMatch) {
            const item: SearchResultItem = {
              file: f,
              snippet: f.path,
              score: 50
            };
            merged.push(item);
          }
        }
      }
      merged.sort((a: SearchResultItem, b: SearchResultItem): number => b.score - a.score);
      this.results = merged;
    } catch (e) {
      console.error('Search error: ' + JSON.stringify(e));
    }
  }

  private addToHistory(keyword: string): void {
    const exists = this.searchHistory.findIndex((item: string): boolean => item === keyword);
    if (exists >= 0) {
      this.searchHistory.splice(exists, 1);
    }
    this.searchHistory.unshift(keyword);
    if (this.searchHistory.length > 10) {
      this.searchHistory = this.searchHistory.slice(0, 10);
    }
  }

  private onSearchSubmit(keyword: string): void {
    this.query = keyword;
    this.addToHistory(keyword);
    this.doSearch(keyword);
  }

  private onHistoryTap(item: string): void {
    this.onSearchSubmit(item);
  }

  @Builder
  SearchBar() {
    Row({ space: Spacing.SM }) {
      Text(Icons.SEARCH)
        .fontSize(14)
        .fontColor(this.getColors().textTertiary)

      TextInput({ placeholder: '\u641C\u7D22\u7B14\u8BB0\u540D\u79F0\u3001\u522B\u540D\u3001\u5185\u5BB9...', text: $$this.query })
        .placeholderColor(this.getColors().textTertiary)
        .fontColor(this.getColors().textPrimary)
        .fontSize(14)
        .height(40)
        .backgroundColor(Color.Transparent)
        .layoutWeight(1)
        .onChange((value: string) => {
          this.query = value;
          this.doSearch(value);
        })
        .onSubmit((_enterKey: EnterKeyType) => {
          this.addToHistory(this.query);
        })

      if (this.query.length > 0) {
        Column() {
          Text(Icons.CLOSE)
            .fontSize(12)
            .fontColor(this.getColors().textTertiary)
        }
        .width(24)
        .height(24)
        .justifyContent(FlexAlign.Center)
        .borderRadius(Radius.FULL)
        .onClick(() => {
          this.query = '';
          this.results = [];
        })
      }
    }
    .width('100%')
    .height(44)
    .padding({ left: Spacing.MD, right: Spacing.SM })
    .backgroundColor(this.getColors().surface2)
    .borderRadius(Radius.MD)
  }

  @Builder
  OptionToggle(label: string, active: boolean, onToggle: () => void) {
    Row({ space: 4 }) {
      Text(label)
        .fontSize(12)
        .fontColor(active ? this.getColors().accent : this.getColors().textTertiary)
        .fontWeight(active ? FontWeight.Medium : FontWeight.Regular)
    }
    .height(28)
    .padding({ left: Spacing.SM, right: Spacing.MD })
    .backgroundColor(active ? this.getColors().accentSubtle : this.getColors().surface2)
    .borderRadius(Radius.FULL)
    .onClick(() => onToggle())
  }

  @Builder
  SearchOptions() {
    Row({ space: Spacing.SM }) {
      this.OptionToggle('Aa', this.caseSensitive, () => {
        this.caseSensitive = !this.caseSensitive;
        if (this.query.length > 0) this.doSearch(this.query);
      })
      this.OptionToggle('.*', this.useRegex, () => {
        this.useRegex = !this.useRegex;
        if (this.query.length > 0) this.doSearch(this.query);
      })
    }
    .width('100%')
  }

  @Builder
  HistorySection() {
    Scroll() {
      Column({ space: Spacing.MD }) {
        if (this.searchHistory.length > 0) {
          Text('\u6700\u8FD1\u641C\u7D22')
            .fontSize(11)
            .fontColor(this.getColors().textTertiary)
            .fontWeight(FontWeight.Medium)
            .width('100%')
            .padding({ left: Spacing.LG, top: Spacing.XL, bottom: Spacing.SM })

          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
            ForEach(this.searchHistory, (item: string, _idx: number) => {
              Text(item)
                .fontSize(13)
                .fontColor(this.getColors().textSecondary)
                .backgroundColor(this.getColors().surface2)
                .padding({ left: Spacing.MD, right: Spacing.MD, top: 6, bottom: 6 })
                .borderRadius(Radius.FULL)
                .margin(4)
                .onClick(() => this.onHistoryTap(item))
            }, (item: string, _idx: number): string => item)
          }
          .width('100%')
          .padding({ left: Spacing.MD, right: Spacing.MD })
        }

        Text('\u641C\u7D22\u63D0\u793A')
          .fontSize(11)
          .fontColor(this.getColors().textTertiary)
          .fontWeight(FontWeight.Medium)
          .width('100%')
          .padding({ left: Spacing.LG, top: Spacing.XL, bottom: Spacing.XS })

        Text('\u2022 \u8F93\u5165\u5173\u952E\u8BCD\u641C\u7D22\u7B14\u8BB0\u540D\u79F0\u3001\u522B\u540D\u6216\u5185\u5BB9')
          .fontSize(12)
          .fontColor(this.getColors().textTertiary)
          .width('100%')
          .padding({ left: Spacing.LG, right: Spacing.LG })
        Text('\u2022 \u5F00\u542F\u6B63\u5219\u8868\u8FBE\u5F0F\u8FDB\u884C\u9AD8\u7EA7\u5339\u914D')
          .fontSize(12)
          .fontColor(this.getColors().textTertiary)
          .width('100%')
          .padding({ left: Spacing.LG, right: Spacing.LG })
        Text('\u2022 \u533A\u5206\u5927\u5C0F\u5199\u7CBE\u786E\u5B9A\u4F4D')
          .fontSize(12)
          .fontColor(this.getColors().textTertiary)
          .width('100%')
          .padding({ left: Spacing.LG, right: Spacing.LG })
      }
      .width('100%')
    }
    .width('100%')
    .layoutWeight(1)
    .scrollBar(BarState.Off)
  }

  @Builder
  ResultItem(item: SearchResultItem, index: number) {
    Column({ space: 4 }) {
      Row({ space: Spacing.SM }) {
        Text(item.file.name)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.getColors().textPrimary)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        if (item.file.wordCount) {
          Text(String(item.file.wordCount) + ' \u5B57')
            .fontSize(11)
            .fontColor(this.getColors().textTertiary)
        }
      }
      .width('100%')

      if (item.snippet.length > 0 && item.snippet !== item.file.path) {
        Text(item.snippet)
          .fontSize(12)
          .fontColor(this.getColors().textSecondary)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }

      if (item.file.tags && item.file.tags.length > 0) {
        Row({ space: 4 }) {
          ForEach(item.file.tags, (tag: string) => {
            Text('#' + tag)
              .fontSize(10)
              .fontColor(this.getColors().accent)
              .backgroundColor(this.getColors().accentSubtle)
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .borderRadius(Radius.FULL)
          }, (tag: string): string => tag)
        }
        .width('100%')
        .margin({ top: 2 })
      }
    }
    .width('100%')
    .padding({ left: Spacing.LG, right: Spacing.LG, top: Spacing.MD, bottom: Spacing.MD })
    .backgroundColor(index === this.hoverIndex ? this.getColors().surfaceHover : this.getColors().surface0)
    .border({ width: { bottom: 1 }, color: this.getColors().border })
    .onClick(() => {
      this.searchNavStack.pushPathByName('searchDetail',
        new Object({ fileId: item.file.id, fileName: item.file.name }));
    })
  }

  @Builder
  EmptyResults() {
    Column({ space: Spacing.SM }) {
      Text(Icons.SEARCH)
        .fontSize(32)
        .fontColor(this.getColors().textTertiary)
        .margin({ top: 48 })
      Text('\u672A\u627E\u5230\u5339\u914D\u7ED3\u679C')
        .fontSize(14)
        .fontColor(this.getColors().textSecondary)
      Text('\u8BF7\u5C1D\u8BD5\u5176\u4ED6\u5173\u952E\u8BCD\u6216\u9009\u9879')
        .fontSize(12)
        .fontColor(this.getColors().textTertiary)
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Start)
  }

  build() {
    Column() {
      // 搜索栏
      Row() {
        this.SearchBar()
      }
      .width('100%')
      .padding({ left: Spacing.MD, right: Spacing.MD, top: Spacing.SM, bottom: Spacing.SM })
      .backgroundColor(this.getColors().surface1)

      // 选项
      Row() {
        this.SearchOptions()
      }
      .width('100%')
      .padding({ left: Spacing.MD, right: Spacing.MD, bottom: Spacing.SM })
      .backgroundColor(this.getColors().surface1)
      .border({ width: { bottom: 1 }, color: this.getColors().border })

      // 内容区
      if (this.query.length === 0) {
        this.HistorySection()
      } else {
        if (this.results.length === 0) {
          this.EmptyResults()
        } else {
          List({ space: 0 }) {
            ForEach(this.results, (item: SearchResultItem, index: number) => {
              ListItem() {
                this.ResultItem(item, index)
              }
            }, (item: SearchResultItem): string => item.file.id)
          }
          .width('100%')
          .layoutWeight(1)
          .scrollBar(BarState.Auto)
          .padding({ top: Spacing.XS })
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.getColors().surface0)
  }
}

@Component
struct SearchDetailPage {
  @Consume('searchNavStack') searchNavStack: NavPathStack;
  @StorageLink('themeMode') themeMode: ThemeMode = ThemeMode.DARK;
  @State fileId: string = '';
  @State fileName: string = '';

  aboutToAppear(): void {
    const params: Object = this.searchNavStack.getParamByName('searchDetail') as Object;
    if (params) {
      const obj = params as Record<string, Object>;
      const id = obj['fileId'];
      const name = obj['fileName'];
      if (id) {
        this.fileId = id as string;
      }
      if (name) {
        this.fileName = name as string;
      }
    }
  }

  private getColors(): LuniusColors {
    return getColors(this.themeMode);
  }

  build() {
    Column() {
      Row() {
        Column() {
          Text(Icons.BACK)
            .fontSize(18)
            .fontColor(this.getColors().textPrimary)
        }
        .width(36)
        .height(36)
        .justifyContent(FlexAlign.Center)
        .borderRadius(Radius.SM)
        .onClick(() => {
          this.searchNavStack.pop();
        })

        Text(this.fileName.length > 0 ? this.fileName : '\u641C\u7D22\u7ED3\u679C\u8BE6\u60C5')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.getColors().textPrimary)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Row().width(36)
      }
      .width('100%')
      .height(52)
      .padding({ left: Spacing.SM, right: Spacing.SM })
      .backgroundColor(this.getColors().surface1)
      .border({ width: { bottom: 1 }, color: this.getColors().border })

      Column({ space: Spacing.MD }) {
        Text('\u6587\u4EF6 ID: ' + this.fileId)
          .fontSize(13)
          .fontColor(this.getColors().textSecondary)
          .width('100%')
          .padding({ left: Spacing.XL, right: Spacing.XL, top: Spacing.XL })

        Text('\u6B64\u5904\u53EF\u6E32\u67D3\u8BE5\u6587\u4EF6\u7684 Markdown \u9884\u89C8\u6216\u9AD8\u4EAE\u5339\u914D\u6587\u672C')
          .fontSize(12)
          .fontColor(this.getColors().textTertiary)
          .width('100%')
          .padding({ left: Spacing.XL, right: Spacing.XL })
      }
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.getColors().surface0)
  }
}

@Entry
@Component
struct SearchPage {
  @Provide('searchNavStack') searchNavStack: NavPathStack = new NavPathStack();

  @Builder
  searchPageMap(name: string) {
    if (name === 'searchDetail') {
      SearchDetailPage()
    }
  }

  build() {
    Navigation(this.searchNavStack) {
      SearchContent()
    }
    .hideTitleBar(true)
    .navDestination(this.searchPageMap)
    .mode(NavigationMode.Stack)
    .width('100%')
    .height('100%')
  }
}
