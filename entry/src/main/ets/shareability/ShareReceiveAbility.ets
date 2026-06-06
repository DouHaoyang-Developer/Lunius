// shareability/ShareReceiveAbility.ets
// 接收来自碰一碰/华为分享/系统分享面板的笔记文件
// SDK 6.1.1(24): ShareExtensionAbility.onCreate 参数为 AbilityConstant.LaunchParam

import { ShareExtensionAbility, AbilityConstant } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'ShareReceiveAbility';

export default class ShareReceiveAbility extends ShareExtensionAbility {
  onCreate(launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(0x0000, TAG, 'ShareReceiveAbility onCreate, launchReason: %{public}d',
      launchParam.launchReason);

    // 分享数据由主 Ability（EntryAbility）通过 onNewWant / onCreate 的 Want 处理。
    // ShareReceiveAbility 的存在仅需让系统知道本应用支持接收分享内容，
    // 实际的笔记创建和跳转逻辑由 EntryAbility.handleDeepLink() 统一处理。
  }
}
