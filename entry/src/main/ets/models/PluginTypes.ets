// models/PluginTypes.ets
// 插件系统类型 — LuniusPlugin 基类 + PluginAPI + Capability

import { PluginManifest } from '../services/ApiTypes';

export enum Capability {
  FILE_READ = 'file:read',
  FILE_WRITE = 'file:write',
  SEARCH = 'search',
  COMMANDS = 'commands',
  UI_RIBBON = 'ui:ribbon',
  UI_SIDEBAR = 'ui:sidebar',
  UI_STATUS_BAR = 'ui:status_bar',
  NETWORK = 'network',
  TEMPLATE = 'template'
}

export interface RibbonButtonConfig {
  id: string;
  icon: string;
  tooltip: string;
  onClick: () => void;
}

export interface CommandConfig {
  id: string;
  name: string;
  callback: () => void;
}

export interface PluginVaultAPI {
  readNote: (noteId: string) => Promise<object>;
  getFileTree: () => Promise<object[]>;
  searchNotes: (query: string, options?: object) => Promise<object[]>;
}

export interface PluginCommandsAPI {
  register: (config: CommandConfig) => void;
  unregister: (id: string) => void;
}

export interface PluginUIAPI {
  addRibbonButton: (config: RibbonButtonConfig) => void;
  removeRibbonButton: (id: string) => void;
}

export interface PluginAPI {
  vault: PluginVaultAPI;
  commands: PluginCommandsAPI;
  ui: PluginUIAPI;
}

export abstract class LuniusPlugin {
  abstract manifest: PluginManifest;
  capabilities: Capability[] = [];
  protected api: PluginAPI | null = null;
  private _enabled: boolean = false;

  get isEnabled(): boolean { return this._enabled; }

  onLoad(api: PluginAPI): void {
    this.api = api;
  }

  onUnload(): void {
    this.api = null;
  }

  onEnable(): void {}
  onDisable(): void {}

  _internalEnable(api: PluginAPI): void {
    this._enabled = true;
    this.onLoad(api);
    this.onEnable();
  }

  _internalDisable(): void {
    this._enabled = false;
    this.onDisable();
    this.onUnload();
  }
}
