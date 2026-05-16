import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { FileService } from '../utils/FileService';
import { TabManager } from '../utils/TabManager';
import { initAllServices } from '../services/Index';

const TAG = 'ObsidianEntryAbility';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(0x0000, TAG, '%{public}s', 'Ability onCreate');

    // 初始化文件服务上下文（必须在任何文件操作前调用）
    FileService.getInstance().setContext(this.context);

    // 异步初始化标签管理器（恢复上次会话的标签状态）
    TabManager.getInstance().init().then(() => {
      hilog.info(0x0000, TAG, 'TabManager initialized');
    });

    // 预热后端服务索引（图谱、标签、同步状态）
    initAllServices().then(() => {
      hilog.info(0x0000, TAG, 'Backend services warmed up');
    });

    // 初始化主题模式（默认 Dark）
    AppStorage.setOrCreate('themeMode', 'dark');
  }

  onDestroy(): void {
    hilog.info(0x0000, TAG, '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(0x0000, TAG, '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/MainEntry', (err) => {
      if (err.code) {
        hilog.error(0x0000, TAG, 'Failed to load the content. Cause: %{public}s', JSON.stringify(err) ?? '');
        return;
      }
      hilog.info(0x0000, TAG, 'Succeeded in loading the content.');
    });

    try {
      const windowInstance = windowStage.getMainWindowSync();
      windowInstance.setWindowBackgroundColor('#1E1E1E');
      windowInstance.setWindowLayoutFullScreen(true);
    } catch (e) {
      hilog.error(0x0000, TAG, 'Window setup error: %{public}s', JSON.stringify(e));
    }
  }

  onWindowStageDestroy(): void {
    hilog.info(0x0000, TAG, '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(0x0000, TAG, '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(0x0000, TAG, '%{public}s', 'Ability onBackground');
    // 进入后台时确保标签状态落盘
    TabManager.getInstance().flushState();
  }
}
