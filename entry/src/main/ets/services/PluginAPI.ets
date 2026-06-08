// services/PluginAPI.ets
// PluginAPI 实现 — 向插件暴露的受限服务代理

import { PluginAPI, PluginVaultAPI, PluginCommandsAPI, PluginUIAPI, RibbonButtonConfig, CommandConfig } from '../models/PluginTypes';
import { fileService } from './IFileService';

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
  const cmdMgr: CommandPaletteManager = CommandPaletteManager.getInstance();
  const ribbonReg: RibbonRegistry = RibbonRegistry.getInstance();

  const vaultAPI: PluginVaultAPI = {
    readNote: async (noteId: string): Promise<object> => {
      const result = await fileService.readNote(noteId);
      return result as object;
    },
    getFileTree: async (): Promise<object[]> => {
      const result = await fileService.getFileTree();
      return result as object[];
    },
    searchNotes: async (query: string, options?: object): Promise<object[]> => {
      const result = await fileService.searchNotes(query, options);
      return result as object[];
    }
  };

  const commandsAPI: PluginCommandsAPI = {
    register: (config: CommandConfig): void => {
      cmdMgr.register(config);
    },
    unregister: (id: string): void => {
      cmdMgr.unregister(id);
    }
  };

  const uiAPI: PluginUIAPI = {
    addRibbonButton: (config: RibbonButtonConfig): void => {
      ribbonReg.add(config);
    },
    removeRibbonButton: (id: string): void => {
      ribbonReg.remove(id);
    }
  };

  const api: PluginAPI = {
    vault: vaultAPI,
    commands: commandsAPI,
    ui: uiAPI
  };
  return api;
}
