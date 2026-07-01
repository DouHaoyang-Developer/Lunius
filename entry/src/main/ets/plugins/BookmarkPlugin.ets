// plugins/BookmarkPlugin.ets
// 书签插件 — 将 BookmarkManager 封装为 LuniusPlugin

import { LuniusPlugin, PluginAPI, Capability, RibbonButtonConfig } from '../models/PluginTypes';
import { PluginManifest } from '../services/ApiTypes';
import { BookmarkManager } from '../utils/BookmarkManager';

export class BookmarkPlugin extends LuniusPlugin {
  manifest: PluginManifest = {
    id: 'lunius-bookmark',
    name: '书签',
    version: '1.0.0',
    description: '收藏笔记、标题、段落',
    author: 'Lunius Team',
    isEnabled: false
  };

  capabilities: Capability[] = [
    Capability.FILE_READ,
    Capability.UI_RIBBON,
    Capability.UI_SIDEBAR
  ];

  private bookmarkManager: BookmarkManager = BookmarkManager.getInstance();

  onLoad(api: PluginAPI): void {
    super.onLoad(api);

    // 注册 Ribbon 按钮
    const ribbonConfig: RibbonButtonConfig = {
      id: 'bookmark-toggle',
      icon: '⭐',
      tooltip: '打开书签面板',
      onClick: () => {
        // 书签面板由 MainEntry 根据 API 注册动态渲染
      }
    };
    api.ui.addRibbonButton(ribbonConfig);
  }

  onEnable(): void {
    // 插件启用时的额外逻辑
  }

  onDisable(): void {
    if (this.api) {
      this.api.ui.removeRibbonButton('bookmark-toggle');
    }
  }
}

export const bookmarkPlugin: BookmarkPlugin = new BookmarkPlugin();
