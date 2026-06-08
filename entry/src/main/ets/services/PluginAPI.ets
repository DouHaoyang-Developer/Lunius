// services/PluginAPI.ets
// PluginAPI 实现 — 向插件暴露的受限服务代理

import { PluginAPI, RibbonButtonConfig, CommandConfig } from '../models/PluginTypes';
import { fileService } from './IFileService';
import { CommandPaletteManager } from './CommandPaletteManager';

// 命令面板管理器（单例，供插件注册命令）
export class CommandPaletteManager {
  private commands: Map<string, CommandConfig> = new Map();
  private static instance: CommandPaletteManager;

  static getInstance(): CommandPaletteManager {
    if (!CommandPaletteManager.instance) {
      CommandPaletteManager.instance = new CommandPaletteManager();
    }
    return CommandPaletteManager.instance;
  }

  register(config: CommandConfig): void {
    this.commands.set(config.id, config);
  }

  unregister(id: string): void {
    this.commands.delete(id);
  }

  getByName(name: string): CommandConfig | undefined {
    let result: CommandConfig | undefined;
    this.commands.forEach((cmd: CommandConfig) => {
      if (cmd.name === name) result = cmd;
    });
    return result;
  }

  getAll(): CommandConfig[] {
    const result: CommandConfig[] = [];
    this.commands.forEach((cmd: CommandConfig) => result.push(cmd));
    return result;
  }
}

// Ribbon 按钮注册表
export class RibbonRegistry {
  private buttons: Map<string, RibbonButtonConfig> = new Map();
  private static instance: RibbonRegistry;

  static getInstance(): RibbonRegistry {
    if (!RibbonRegistry.instance) {
      RibbonRegistry.instance = new RibbonRegistry();
    }
    return RibbonRegistry.instance;
  }

  add(config: RibbonButtonConfig): void {
    this.buttons.set(config.id, config);
  }

  remove(id: string): void {
    this.buttons.delete(id);
  }

  getAll(): RibbonButtonConfig[] {
    const result: RibbonButtonConfig[] = [];
    this.buttons.forEach((b: RibbonButtonConfig) => result.push(b));
    return result;
  }
}

export function createPluginAPI(): PluginAPI {
  const cmdMgr = CommandPaletteManager.getInstance();
  const ribbonReg = RibbonRegistry.getInstance();

  return {
    vault: {
      readNote: async (noteId: string) => {
        return await fileService.readNote(noteId);
      },
      getFileTree: async () => {
        return await fileService.getFileTree();
      },
      searchNotes: async (query: string, options?: object) => {
        return await fileService.searchNotes(query, options);
      }
    },
    commands: {
      register: (config: CommandConfig) => {
        cmdMgr.register(config);
      },
      unregister: (id: string) => {
        cmdMgr.unregister(id);
      }
    },
    ui: {
      addRibbonButton: (config: RibbonButtonConfig) => {
        ribbonReg.add(config);
      },
      removeRibbonButton: (id: string) => {
        ribbonReg.remove(id);
      }
    }
  };
}
