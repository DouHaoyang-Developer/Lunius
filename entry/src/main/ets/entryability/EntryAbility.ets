import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { FileService } from '../utils/FileService';
import { TabManager } from '../utils/TabManager';
import { initAllServices } from '../services/Index';
import { CollaborationService } from '../services/CollaborationService';
import { CloudSyncService } from '../services/CloudSyncService';

const TAG = 'ObsidianEntryAbility';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(0x0000, TAG, '%{public}s', 'Ability onCreate');

    // 初始化文件服务上下文（必须在任何文件操作前调用）
    FileService.getInstance().setContext(this.context);

    // 初始化协同服务上下文（供后续分布式协同使用）
    CollaborationService.setContext(this.context);

    // 异步初始化标签管理器（恢复上次会话的标签状态）
    TabManager.getInstance().init().then(() => {
      hilog.info(0x0000, TAG, 'TabManager initialized');
    });

    // 预热后端服务索引（图谱、标签、同步状态、版本控制、云同步）
    initAllServices().then(() => {
      hilog.info(0x0000, TAG, 'Backend services warmed up');
      // 启动周期云同步（每 5 分钟）
      this.startCloudSync();
    });

    // 初始化主题模式（默认 Dark）
    AppStorage.setOrCreate('themeMode', 'dark');

    // 处理冷启动时的深度链接/分享意图
    this.handleDeepLink(want);
  }

  // 热启动时处理深度链接
  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(0x0000, TAG, '%{public}s', 'onNewWant triggered');
    this.handleDeepLink(want);
  }

  // 跨端迁移：保存当前状态到另一设备
  onContinue(wantParam: Record<string, Object>): AbilityConstant.OnContinueResult {
    hilog.info(0x0000, TAG, '%{public}s', 'onContinue triggered');

    const currentNoteId = AppStorage.get<string>('currentNoteId');
    if (currentNoteId) {
      wantParam.noteId = currentNoteId;
    }
    const currentContent = AppStorage.get<string>('currentNoteContent');
    if (currentContent) {
      wantParam.noteContent = currentContent;
    }

    return AbilityConstant.OnContinueResult.AGREE;
  }

  // 解析深度链接、系统分享和跨端迁移意图
  private handleDeepLink(want: Want): void {
    try {
      // 路径 A: 系统分享面板传来的文件 URI
      const shareDataUri = want.parameters?.shareData as string;
      if (shareDataUri) {
        AppStorage.setOrCreate('pendingShareAction', 'openSharedFile');
        AppStorage.setOrCreate('pendingShareFileUri', shareDataUri);
        hilog.info(0x0000, TAG, 'Share data received: %{public}s', shareDataUri);
        return;
      }

      const uri = want.uri;
      if (uri) {
        // 路径 B: App Linking 深度链接 — https://lunius.drcn.agconnect.link/edit?noteId=xxx
        const noteId = this.extractQueryParam(uri, 'noteId');
        if (noteId) {
          AppStorage.setOrCreate('pendingShareAction', 'openSharedNote');
          AppStorage.setOrCreate('pendingShareNoteId', noteId);
          hilog.info(0x0000, TAG, 'Deep link: open note %{public}s', noteId);
          return;
        }

        // 路径 C: 协同会话深度链接 — ?sessionId=xxx
        const sessionId = this.extractQueryParam(uri, 'sessionId');
        if (sessionId) {
          AppStorage.setOrCreate('pendingShareAction', 'joinCollaboration');
          AppStorage.setOrCreate('pendingCollaborationSessionId', sessionId);
          hilog.info(0x0000, TAG, 'Deep link: join collaboration %{public}s', sessionId);
          return;
        }
      }

      // 路径 D: 跨端迁移传入的笔记参数
      const noteId = want.parameters?.noteId as string;
      if (noteId) {
        AppStorage.setOrCreate('pendingShareAction', 'openSharedNote');
        AppStorage.setOrCreate('pendingShareNoteId', noteId);
        if (want.parameters?.noteContent) {
          AppStorage.setOrCreate('pendingShareNoteContent', want.parameters.noteContent as string);
        }
      }
    } catch (err) {
      hilog.error(0x0000, TAG, 'handleDeepLink error: %{public}s', JSON.stringify(err));
    }
  }

  // 从 URI 中提取查询参数
  private extractQueryParam(uri: string, paramName: string): string | null {
    const pattern = `[?&]${paramName}=([^&]*)`;
    const match = uri.match(pattern);
    return match ? decodeURIComponent(match[1]) : null;
  }

  onDestroy(): void {
    hilog.info(0x0000, TAG, '%{public}s', 'Ability onDestroy');
  }

  // 启动周期云同步
  private startCloudSync(): void {
    const cloudSync = CloudSyncService.getInstance();
    if (cloudSync.isAuthorized()) {
      setInterval(() => {
        cloudSync.syncAll().then((result) => {
          hilog.info(0x0000, TAG, 'CloudSync: uploaded=%{public}d, downloaded=%{public}d, conflicts=%{public}d',
            result.uploaded, result.downloaded, result.conflicts);
        });
      }, 5 * 60 * 1000); // 每 5 分钟
      // 首次立即同步
      cloudSync.syncAll().then((result) => {
        hilog.info(0x0000, TAG, 'CloudSync initial: uploaded=%{public}d, downloaded=%{public}d, conflicts=%{public}d',
          result.uploaded, result.downloaded, result.conflicts);
      });
    }
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
    TabManager.getInstance().flushState();
  }
}
