import { FileService } from './FileService';

/**
 * 标签页数据项
 */
export class TabItem {
  id: string = '';
  fileName: string = '';
  filePath: string = '';
  isPinned: boolean = false;
  isActive: boolean = false;
  createdAt: number = 0;

  get isEmpty(): boolean {
    return this.filePath === '';
  }
}

/**
 * 标签页状态管理器（单例）
 * 管理已打开的标签列表，通过 JSON 文件持久化到应用私有存储
 */
export class TabManager {
  private static instance: TabManager;
  private tabs: TabItem[] = [];
  private fileService: FileService = FileService.getInstance();
  private initialized: boolean = false;
  private saveTimer: number = -1;
  private static readonly SAVE_DEBOUNCE_MS: number = 500;

  private static readonly STATE_FILE = 'tabs_state.json';

  private constructor() {}

  public static getInstance(): TabManager {
    if (!TabManager.instance) {
      TabManager.instance = new TabManager();
    }
    return TabManager.instance;
  }

  /**
   * 从持久化存储加载标签列表（首次使用时自动调用）
   */
  public async init(): Promise<void> {
    if (this.initialized) {
      return;
    }

    try {
      const statePath = this.getStatePath();
      const isExists = await this.fileService.fileExists(statePath);
      if (isExists) {
        const content = await this.fileService.readFile(statePath);
        if (content) {
          const parsed = JSON.parse(content) as Record<string, Object>;
          const rawTabs = parsed.tabs as Array<Record<string, Object>>;
          if (rawTabs && rawTabs.length > 0) {
            this.tabs = rawTabs.map((item) => this.deserializeTab(item));
          }
        }
      }
    } catch (err) {
      console.error('Failed to load tabs state: ' + JSON.stringify(err));
      this.tabs = [];
    }

    // 清理过期标签：检查文件是否仍然存在
    await this.pruneStaleTabs();

    this.initialized = true;
    console.info(`TabManager initialized with ${this.tabs.length} tabs`);
  }

  /**
   * 添加新标签（若文件路径已存在则仅切换活跃状态）
   * @param fileName 文件名
   * @param filePath 文件路径
   * @returns 标签 ID
   */
  public async addTab(fileName: string, filePath: string): Promise<string> {
    await this.ensureInitialized();

    const existing = this.tabs.find(tab => tab.filePath === filePath);
    if (existing) {
      await this.setActiveTab(filePath);
      return existing.id;
    }

    // 取消其他标签的活跃状态
    this.tabs.forEach(tab => tab.isActive = false);

    const id = this.generateId();
    const newTab = new TabItem();
    newTab.id = id;
    newTab.fileName = fileName;
    newTab.filePath = filePath;
    newTab.isPinned = false;
    newTab.isActive = true;
    newTab.createdAt = Date.now();

    this.tabs.push(newTab);
    this.debouncedSaveState();
    console.info(`Tab added: ${fileName}`);
    return id;
  }

  /**
   * 移除标签（不删除源文件，仅从标签列表中移除）
   * @param tabId 标签 ID
   */
  public async removeTab(tabId: string): Promise<void> {
    await this.ensureInitialized();

    // 不允许删除最后一个标签页，最少保留 1 个
    if (this.tabs.length <= 1) {
      return;
    }

    const index = this.tabs.findIndex(tab => tab.id === tabId);
    if (index === -1) {
      return;
    }

    const removedActive = this.tabs[index].isActive;
    this.tabs.splice(index, 1);

    // 若移除的是活跃标签，选第一个未置顶的作为新活跃
    if (removedActive && this.tabs.length > 0) {
      const nextActive = this.tabs.find(tab => !tab.isPinned) || this.tabs[0];
      nextActive.isActive = true;
    }

    this.debouncedSaveState();
    console.info(`Tab removed: ${tabId}`);
  }

  /**
   * 切换标签置顶状态
   * @param tabId 标签 ID
   */
  public async togglePin(tabId: string): Promise<void> {
    await this.ensureInitialized();

    const tab = this.tabs.find(t => t.id === tabId);
    if (!tab) {
      return;
    }

    tab.isPinned = !tab.isPinned;
    this.debouncedSaveState();
  }

  /**
   * 设置活跃标签
   * @param filePath 文件路径
   */
  public async setActiveTab(filePath: string): Promise<void> {
    await this.ensureInitialized();

    this.tabs.forEach(tab => tab.isActive = (tab.filePath === filePath));
    this.debouncedSaveState();
  }

  /**
   * 获取排序后的标签列表（置顶优先，同组按创建时间倒序）
   */
  public getTabs(): TabItem[] {
    return [...this.tabs].sort((a, b) => {
      if (a.isPinned !== b.isPinned) {
        return a.isPinned ? -1 : 1;
      }
      return b.createdAt - a.createdAt;
    });
  }

  /**
   * 获取标签总数
   */
  public getTabCount(): number {
    return this.tabs.length;
  }

  /**
   * 获取活跃标签
   */
  public getActiveTab(): TabItem | null {
    return this.tabs.find(tab => tab.isActive) || null;
  }

  /**
   * 更新标签的文件名和路径（重命名后调用）
   * @param oldFilePath 原文件路径
   * @param newFileName 新文件名
   * @param newFilePath 新文件路径
   */
  public async updateTabInfo(oldFilePath: string, newFileName: string, newFilePath: string): Promise<void> {
    await this.ensureInitialized();

    const tab = this.tabs.find(t => t.filePath === oldFilePath);
    if (!tab) {
      return;
    }

    tab.fileName = newFileName;
    tab.filePath = newFilePath;
    this.debouncedSaveState();
    console.info(`Tab updated: ${oldFilePath} -> ${newFilePath}`);
  }

  /**
   * 根据 ID 获取标签
   */
  public getTabById(tabId: string): TabItem | null {
    return this.tabs.find(tab => tab.id === tabId) || null;
  }

  /**
   * 创建一个空标签（无关联文件），返回标签 ID
   */
  public async addEmptyTab(): Promise<string> {
    await this.ensureInitialized();

    // 若已有空标签则直接激活，避免创建多个空标签
    const existingEmpty = this.tabs.find(t => t.filePath === '');
    if (existingEmpty) {
      this.tabs.forEach(tab => tab.isActive = (tab.id === existingEmpty.id));
      this.debouncedSaveState();
      return existingEmpty.id;
    }

    this.tabs.forEach(tab => tab.isActive = false);

    const id = this.generateId();
    const newTab = new TabItem();
    newTab.id = id;
    newTab.fileName = '';
    newTab.filePath = '';
    newTab.isPinned = false;
    newTab.isActive = true;
    newTab.createdAt = Date.now();

    this.tabs.push(newTab);
    this.debouncedSaveState();
    console.info(`Empty tab added: ${id}`);
    return id;
  }

  /**
   * 为已有标签设置文件关联（空标签 → 文件标签）
   */
  public async setTabFile(tabId: string, fileName: string, filePath: string): Promise<void> {
    await this.ensureInitialized();

    const tab = this.tabs.find(t => t.id === tabId);
    if (!tab) {
      console.error(`Tab not found: ${tabId}`);
      return;
    }

    // 防止多个标签关联同一文件：若已有其他标签持有此 filePath，则合并（删除当前标签）
    const conflictingTab = this.tabs.find(t => t.filePath === filePath && t.id !== tabId);
    if (conflictingTab) {
      conflictingTab.isActive = true;
      this.tabs.forEach(t => { t.isActive = (t.id === conflictingTab.id); });
      const idx = this.tabs.findIndex(t => t.id === tabId);
      if (idx !== -1) {
        this.tabs.splice(idx, 1);
      }
      this.debouncedSaveState();
      console.info(`Tab ${tabId} merged into ${conflictingTab.id} for file ${filePath}`);
      return;
    }

    tab.fileName = fileName;
    tab.filePath = filePath;
    tab.isActive = true;
    this.tabs.forEach(t => { if (t.id !== tabId) { t.isActive = false; } });
    this.debouncedSaveState();
    console.info(`Tab file set: ${tabId} -> ${fileName}`);
  }

  /**
   * 清除标签的文件关联（文件标签 → 空标签）
   */
  public async clearTabFile(tabId: string): Promise<void> {
    await this.ensureInitialized();

    const tab = this.tabs.find(t => t.id === tabId);
    if (!tab) {
      return;
    }

    tab.fileName = '';
    tab.filePath = '';
    this.debouncedSaveState();
    console.info(`Tab file cleared: ${tabId}`);
  }

  /**
   * 按标签 ID 设置活跃标签
   */
  public async setActiveTabById(tabId: string): Promise<void> {
    await this.ensureInitialized();

    this.tabs.forEach(tab => tab.isActive = (tab.id === tabId));
    this.debouncedSaveState();
  }

  // ─── 持久化 Debounce ───────────────────────────

  /**
   * 延迟持久化（500ms 内的多次调用合并为一次写入）
   */
  private debouncedSaveState(): void {
    if (this.saveTimer !== -1) {
      clearTimeout(this.saveTimer);
    }
    this.saveTimer = setTimeout(() => {
      this.saveTimer = -1;
      this.saveState();
    }, TabManager.SAVE_DEBOUNCE_MS);
  }

  /**
   * 立即落盘（应用进入后台等关键时机调用）
   */
  public async flushState(): Promise<void> {
    if (this.saveTimer !== -1) {
      clearTimeout(this.saveTimer);
      this.saveTimer = -1;
      await this.saveState();
    }
  }

  // ─── 私有方法 ────────────────────────────────────

  /**
   * 生成唯一 ID
   */
  private generateId(): string {
    const timestamp = Date.now().toString(36);
    const random = Math.floor(Math.random() * 100000).toString(36);
    return `tab_${timestamp}${random}`;
  }

  /**
   * 获取状态文件完整路径
   */
  private getStatePath(): string {
    return `${this.fileService.getBaseDirectory()}/${TabManager.STATE_FILE}`;
  }

  /**
   * 保存状态到 JSON 文件
   */
  private async saveState(): Promise<void> {
    try {
      const json = JSON.stringify({ tabs: this.tabs });
      await this.fileService.writeFile(this.getStatePath(), json);
    } catch (err) {
      console.error('Failed to save tabs state: ' + JSON.stringify(err));
    }
  }

  /**
   * 清理已经被删除的标签条目
   */
  private async pruneStaleTabs(): Promise<void> {
    const validTabs: TabItem[] = [];
    for (const tab of this.tabs) {
      // 空标签（无文件关联）跳过文件存在性检查，直接保留
      if (tab.filePath === '' || await this.fileService.fileExists(tab.filePath)) {
        validTabs.push(tab);
      } else {
        console.info(`Pruned stale tab: ${tab.fileName}`);
      }
    }

    if (validTabs.length !== this.tabs.length) {
      this.tabs = validTabs;
      await this.saveState();
    }
  }

  /**
   * 从 JSON 对象反序列化为 TabItem
   */
  private deserializeTab(data: Record<string, Object>): TabItem {
    const tab = new TabItem();
    tab.id = (data.id as string) || '';
    tab.fileName = (data.fileName as string) || '';
    tab.filePath = (data.filePath as string) || '';
    tab.isPinned = (data.isPinned as boolean) || false;
    tab.isActive = (data.isActive as boolean) || false;
    tab.createdAt = (data.createdAt as number) || 0;
    return tab;
  }

  /**
   * 确保已完成初始化
   */
  private async ensureInitialized(): Promise<void> {
    if (!this.initialized) {
      await this.init();
    }
  }
}
