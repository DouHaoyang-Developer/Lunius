// services/PluginManager.ets
// 插件管理器 — 注册/启用/禁用/恢复 + PluginStore 持久化

import { LuniusPlugin, PluginAPI } from '../models/PluginTypes';
import { fileIo as fs } from '@kit.CoreFileKit';

const PLUGIN_STATE_FILE = 'plugin_state.json';

interface PluginState {
  id: string;
  enabled: boolean;
}

class PluginStore {
  private basePath: string = '';
  private states: Map<string, PluginState> = new Map();

  setBasePath(path: string): void {
    this.basePath = path;
  }

  loadAll(): Map<string, PluginState> {
    if (!this.basePath) return this.states;
    try {
      const fp = `${this.basePath}/${PLUGIN_STATE_FILE}`;
      if (fs.accessSync(fp)) {
        const raw = fs.readTextSync(fp);
        const arr: PluginState[] = JSON.parse(raw);
        for (const s of arr) {
          this.states.set(s.id, s);
        }
      }
    } catch (e) {
      console.error('PluginStore load failed: ' + JSON.stringify(e));
    }
    return this.states;
  }

  private async persist(): Promise<void> {
    if (!this.basePath) return;
    try {
      const arr: PluginState[] = [];
      this.states.forEach((s: PluginState) => arr.push(s));
      const fp = `${this.basePath}/${PLUGIN_STATE_FILE}`;
      const file = await fs.open(fp,
        fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
      await fs.write(file.fd, JSON.stringify(arr));
      await fs.close(file);
    } catch (e) {
      console.error('PluginStore persist failed: ' + JSON.stringify(e));
    }
  }

  async save(id: string, enabled: boolean): Promise<void> {
    this.states.set(id, { id: id, enabled: enabled });
    await this.persist();
  }

  isEnabled(id: string): boolean {
    const state = this.states.get(id);
    return state ? state.enabled : false;
  }
}

export class PluginManager {
  private plugins: Map<string, LuniusPlugin> = new Map();
  private api: PluginAPI | null = null;
  private store: PluginStore = new PluginStore();
  private static instance: PluginManager;

  static getInstance(): PluginManager {
    if (!PluginManager.instance) {
      PluginManager.instance = new PluginManager();
    }
    return PluginManager.instance;
  }

  setBasePath(path: string): void {
    this.store.setBasePath(path);
  }

  setAPI(api: PluginAPI): void {
    this.api = api;
  }

  register(plugin: LuniusPlugin): void {
    this.plugins.set(plugin.manifest.id, plugin);
  }

  getPlugin(id: string): LuniusPlugin | undefined {
    return this.plugins.get(id);
  }

  getAllPlugins(): LuniusPlugin[] {
    const result: LuniusPlugin[] = [];
    this.plugins.forEach((p: LuniusPlugin) => result.push(p));
    return result;
  }

  async enable(id: string): Promise<void> {
    const plugin = this.plugins.get(id);
    if (!plugin || plugin.isEnabled) return;
    if (!this.api) {
      console.error('PluginManager: API not set. Call setAPI() before enabling plugins.');
      return;
    }
    plugin._internalEnable(this.api);
    await this.store.save(id, true);
  }

  async disable(id: string): Promise<void> {
    const plugin = this.plugins.get(id);
    if (!plugin || !plugin.isEnabled) return;
    plugin._internalDisable();
    await this.store.save(id, false);
  }

  async toggle(id: string): Promise<void> {
    const plugin = this.plugins.get(id);
    if (!plugin) return;
    if (plugin.isEnabled) {
      await this.disable(id);
    } else {
      await this.enable(id);
    }
  }

  async restore(): Promise<void> {
    this.store.loadAll();
    const allStates: Map<string, PluginState> = this.store.loadAll();
    allStates.forEach((state: PluginState, pluginId: string) => {
      if (state.enabled) {
        this.enable(pluginId).catch((e: Error) => {
          console.error('PluginManager: failed to restore plugin ' + pluginId + ': ' + e.message);
        });
      }
    });
  }

  getEnabledPlugins(): LuniusPlugin[] {
    const result: LuniusPlugin[] = [];
    this.plugins.forEach((p: LuniusPlugin) => {
      if (p.isEnabled) result.push(p);
    });
    return result;
  }
}

export const pluginManager: PluginManager = PluginManager.getInstance();
