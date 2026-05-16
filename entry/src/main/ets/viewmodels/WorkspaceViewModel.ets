import { NoteViewModel } from './NoteViewModel';
import { NoteMetadata } from '../services/ApiTypes';
import { TabManager } from '../utils/TabManager';
import { FileService } from '../utils/FileService';

export interface HistoryEntry {
  noteId: string;
  paneId: string;
}

export interface TabState {
  id: string;
  noteId: string;
  title: string;
  viewModel: NoteViewModel;
  isModified: boolean;
  isActive: boolean;
  viewMode: 'editor' | 'preview' | 'split';
}

export interface SplitPane {
  id: string;
  tabs: TabState[];
  activeTabId: string;
  width: number;
}

@Observed
export class WorkspaceViewModel {
  panes: SplitPane[] = [];
  activePaneId: string = '';
  isSplitView: boolean = false;

  history: HistoryEntry[] = [];
  historyIndex: number = -1;

  leftSidebarVisible: boolean = true;
  rightSidebarVisible: boolean = true;
  leftSidebarWidth: number = 280;
  rightSidebarWidth: number = 260;
  ribbonCollapsed: boolean = false;

  isSearchOpen: boolean = false;
  searchQuery: string = '';

  private tabManager: TabManager = TabManager.getInstance();

  constructor() {
    this.initDefaultPane();
  }

  private initDefaultPane(): void {
    const defaultPane: SplitPane = {
      id: 'pane-0',
      tabs: [],
      activeTabId: '',
      width: 100
    };
    this.panes = [defaultPane];
    this.activePaneId = defaultPane.id;
  }

  async restoreSession(): Promise<void> {
    await this.tabManager.init();
    const savedTabs = this.tabManager.getTabs();

    const fileTabs = savedTabs.filter(t => !t.isEmpty);
    if (fileTabs.length === 0) return;

    const pane = this.panes[0];
    for (const tabItem of fileTabs) {
      const noteId = tabItem.fileName.replace('.md', '');
      const vm = new NoteViewModel();
      try {
        await vm.loadNote(noteId);
      } catch (e) {
        console.error('Failed to restore tab: ' + tabItem.fileName);
        continue;
      }

      const tab: TabState = {
        id: tabItem.id,
        noteId,
        title: tabItem.fileName,
        viewModel: vm,
        isModified: false,
        isActive: tabItem.isActive,
        viewMode: 'split'
      };
      pane.tabs.push(tab);
      if (tabItem.isActive) {
        pane.activeTabId = tab.id;
      }
    }

    if (!pane.activeTabId && pane.tabs.length > 0) {
      pane.activeTabId = pane.tabs[0].id;
      pane.tabs[0].isActive = true;
    }
  }

  openNote(noteId: string, title: string, paneId?: string): TabState {
    const targetPaneId = paneId ?? this.activePaneId;
    const pane = this.panes.find(p => p.id === targetPaneId);
    if (!pane) {
      const empty: TabState = { id: '', noteId: '', title: '', viewModel: new NoteViewModel(), isModified: false, isActive: false, viewMode: 'editor' };
      return empty;
    }

    const existingTab = pane.tabs.find(t => t.noteId === noteId);
    if (existingTab) {
      this.activateTab(existingTab.id, targetPaneId);
      return existingTab;
    }

    const tabId = `tab-${Date.now()}`;
    const vm = new NoteViewModel();
    vm.loadNote(noteId);

    const newTab: TabState = {
      id: tabId,
      noteId,
      title,
      viewModel: vm,
      isModified: false,
      isActive: true,
      viewMode: 'split'
    };

    pane.tabs.push(newTab);
    pane.activeTabId = tabId;
    this.deactivateOtherTabs(pane, tabId);
    this.addToHistory(noteId, targetPaneId);

    // 同步到持久化层
    const fileName = `${noteId}.md`;
    const filePath = `${FileService.getInstance().getBaseDirectory()}/${fileName}`;
    this.tabManager.addTab(fileName, filePath);

    return newTab;
  }

  closeTab(tabId: string, paneId?: string): void {
    const targetPaneId = paneId ?? this.activePaneId;
    const pane = this.panes.find(p => p.id === targetPaneId);
    if (!pane) return;

    const idx = pane.tabs.findIndex(t => t.id === tabId);
    if (idx === -1) return;

    pane.tabs.splice(idx, 1);
    if (pane.activeTabId === tabId && pane.tabs.length > 0) {
      pane.activeTabId = pane.tabs[Math.max(0, idx - 1)].id;
    }

    this.tabManager.removeTab(tabId);
  }

  activateTab(tabId: string, paneId?: string): void {
    const targetPaneId = paneId ?? this.activePaneId;
    const pane = this.panes.find(p => p.id === targetPaneId);
    if (!pane) return;

    pane.activeTabId = tabId;
    this.deactivateOtherTabs(pane, tabId);

    const tab = pane.tabs.find(t => t.id === tabId);
    if (tab) {
      this.addToHistory(tab.noteId, targetPaneId);
      this.tabManager.setActiveTabById(tabId);
    }
  }

  splitView(orientation: 'horizontal' | 'vertical'): void {
    if (this.panes.length >= 2) return;

    const currentPane = this.panes.find(p => p.id === this.activePaneId);
    if (!currentPane) return;

    const newPane: SplitPane = {
      id: `pane-${Date.now()}`,
      tabs: [],
      activeTabId: '',
      width: 50
    };

    currentPane.width = 50;
    this.panes.push(newPane);
    this.activePaneId = newPane.id;
    this.isSplitView = true;
  }

  closeSplitPane(paneId: string): void {
    if (this.panes.length <= 1) return;
    const idx = this.panes.findIndex(p => p.id === paneId);
    if (idx === -1) return;

    const pane = this.panes[idx];
    const targetPane = this.panes[0];
    pane.tabs.forEach(tab => {
      tab.isActive = false;
      targetPane.tabs.push(tab);
    });

    this.panes.splice(idx, 1);
    targetPane.width = 100;
    this.activePaneId = targetPane.id;
    this.isSplitView = false;
  }

  navigateBack(): void {
    if (this.historyIndex > 0) {
      this.historyIndex--;
      const entry = this.history[this.historyIndex];
      this.openNote(entry.noteId, '', entry.paneId);
    }
  }

  navigateForward(): void {
    if (this.historyIndex < this.history.length - 1) {
      this.historyIndex++;
      const entry = this.history[this.historyIndex];
      this.openNote(entry.noteId, '', entry.paneId);
    }
  }

  private deactivateOtherTabs(pane: SplitPane, activeTabId: string): void {
    pane.tabs.forEach(t => {
      t.isActive = t.id === activeTabId;
    });
  }

  private addToHistory(noteId: string, paneId: string): void {
    this.history = this.history.slice(0, this.historyIndex + 1);
    const entry: HistoryEntry = { noteId: noteId, paneId: paneId };
    this.history.push(entry);
    this.historyIndex++;

    if (this.history.length > 50) {
      this.history.shift();
      this.historyIndex--;
    }
  }
}
