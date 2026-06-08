// components/CollaborationPanel.ets
// 超级终端协同面板 — 设备列表、会话管理、邀请协同

import { ObsidianColors, ThemeMode, getColors } from '../utils/Theme';
import {
  CollaborationSession,
  CollaborationSessionState,
  CollaboratorDevice,
  RemoteCursorState,
  DEVICE_CURSOR_COLORS
} from '../models/CollaborationTypes';

@Component
export struct CollaborationPanel {
  @StorageLink('themeMode') themeMode: ThemeMode = ThemeMode.DARK;
  @Prop session: CollaborationSession | null = null;
  @Prop remoteCursors: RemoteCursorState[] = [];
  @Prop isVisible: boolean = true;
  onStartSession: () => void = () => {};
  onJoinSession: (sessionId: string) => void = () => {};
  onLeaveSession: () => void = () => {};
  onInviteDevice: (deviceId: string) => void = () => {};
  onClose: () => void = () => {};

  @State joinSessionId: string = '';

  private colors(): ObsidianColors {
    return getColors(this.themeMode);
  }

  build() {
    Column() {
      if (this.isVisible) {
        Column({ space: 0 }) {
          // 标题栏
          Row() {
            Text('超级终端协同')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.colors().textPrimary)
              .layoutWeight(1)

            Button({ type: ButtonType.Circle }) {
              Text('✕').fontSize(12).fontColor(this.colors().iconSecondary)
            }
            .width(24)
            .height(24)
            .backgroundColor(Color.Transparent)
            .onClick(() => this.onClose())
          }
          .width('100%')
          .height(44)
          .padding({ left: 14, right: 8 })
          .backgroundColor(this.colors().sidebarBg)
          .border({ width: { bottom: 1 }, color: this.colors().divider })

          // 会话状态
          if (this.session && this.session.state !== CollaborationSessionState.IDLE) {
            this.SessionStatusView()
          }

          // 在线设备列表
          if (this.session && this.session.participants.length > 0) {
            this.DeviceListView()
          } else if (!this.session || this.session.state === CollaborationSessionState.IDLE) {
            this.IdleStateView()
          }

          // 底部操作按钮
          Row({ space: 8 }) {
            if (!this.session || this.session.state === CollaborationSessionState.IDLE) {
              Button('创建协同会话')
                .fontSize(13)
                .backgroundColor(this.colors().accent)
                .borderRadius(6)
                .layoutWeight(1)
                .onClick(() => this.onStartSession())
            } else {
              Button('退出协同', { type: ButtonType.Normal })
                .fontSize(13)
                .fontColor('#FFFFFF')
                .backgroundColor('#E74C3C')
                .borderRadius(6)
                .layoutWeight(1)
                .onClick(() => this.onLeaveSession())
            }
          }
          .width('100%')
          .padding({ left: 14, right: 14, top: 10, bottom: 14 })
          .backgroundColor(this.colors().sidebarBg)
        }
        .width(280)
        .backgroundColor(this.colors().sidebarBg)
        .borderRadius(10)
        .border({ width: 1, color: this.colors().divider })
        .shadow({ radius: 16, color: 'rgba(0,0,0,0.25)', offsetX: 0, offsetY: 4 })
      }
    }
  }

  @Builder
  SessionStatusView() {
    Column({ space: 4 }) {
      Row({ space: 6 }) {
        Circle({ width: 6, height: 6 })
          .fill(this.session!.state === CollaborationSessionState.CONNECTED ? '#2ECC71' : '#F39C12')

        Text(this.getStateLabel(this.session!.state))
          .fontSize(12)
          .fontColor(this.colors().textSecondary)
      }
      .width('100%')
      .padding({ left: 14, top: 10 })

      Text(`笔记: ${this.session!.noteTitle}`)
        .fontSize(12)
        .fontColor(this.colors().textMuted)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .padding({ left: 14, right: 14 })

      Text(`${this.session!.participants.length} 台设备在线`)
        .fontSize(11)
        .fontColor(this.colors().textMuted)
        .width('100%')
        .padding({ left: 14, bottom: 6 })
    }
    .width('100%')
    .backgroundColor(this.colors().bgTertiary)
    .border({ width: { bottom: 1 }, color: this.colors().divider })
  }

  @Builder
  DeviceListView() {
    Column({ space: 2 }) {
      Text('在线设备')
        .fontSize(11)
        .fontColor(this.colors().textMuted)
        .fontWeight(FontWeight.Medium)
        .width('100%')
        .padding({ left: 14, top: 10, bottom: 6 })

      ForEach(this.session!.participants, (device: CollaboratorDevice, index: number) => {
        Row({ space: 10 }) {
          // 颜色指示器
          Circle({ width: 8, height: 8 })
            .fill(DEVICE_CURSOR_COLORS[index % DEVICE_CURSOR_COLORS.length])

          Column({ space: 2 }) {
            Text(device.deviceName)
              .fontSize(13)
              .fontColor(this.colors().textPrimary)

            Text(this.getDeviceTypeLabel(device.deviceType))
              .fontSize(10)
              .fontColor(this.colors().textMuted)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          if (device.isHost) {
            Text('主持人')
              .fontSize(10)
              .fontColor(this.colors().accent)
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .backgroundColor(this.colors().bgActive)
              .borderRadius(4)
          }

          if (device.isOnline) {
            Circle({ width: 5, height: 5 }).fill('#2ECC71')
          }
        }
        .width('100%')
        .height(42)
        .padding({ left: 14, right: 14 })
        .backgroundColor(this.colors().bgPrimary)
      }, (device: CollaboratorDevice) => device.deviceId)
    }
    .width('100%')
    .border({ width: { bottom: 1 }, color: this.colors().divider })
  }

  @Builder
  IdleStateView() {
    Column({ space: 12 }) {
      Column({ space: 8 }) {
        Text('📡')
          .fontSize(36)

        Text('未连接到协同会话')
          .fontSize(14)
          .fontColor(this.colors().textPrimary)

        Text('创建一个协同会话后，其他设备可以加入并实时编辑同一份笔记')
          .fontSize(12)
          .fontColor(this.colors().textMuted)
          .textAlign(TextAlign.Center)
          .width('85%')
      }
      .width('100%')
      .padding({ top: 30, bottom: 20 })
      .justifyContent(FlexAlign.Center)

      // 加入已有会话输入
      Row({ space: 8 }) {
        TextInput({ placeholder: '输入会话 ID...' })
          .fontSize(12)
          .height(36)
          .layoutWeight(1)
          .backgroundColor(this.colors().bgPrimary)
          .borderRadius(6)
          .border({ width: 1, color: this.colors().divider })
          .onChange((value: string) => {
            this.joinSessionId = value;
          })

        Button('加入')
          .fontSize(12)
          .height(36)
          .backgroundColor(this.colors().accent)
          .borderRadius(6)
          .padding({ left: 12, right: 12 })
          .onClick(() => {
            if (this.joinSessionId.trim().length > 0) {
              this.onJoinSession(this.joinSessionId.trim());
            }
          })
      }
      .width('100%')
      .padding({ left: 14, right: 14, bottom: 16 })
    }
    .width('100%')
  }

  private getStateLabel(state: CollaborationSessionState): string {
    switch (state) {
      case CollaborationSessionState.HOSTING: return '等待连接...';
      case CollaborationSessionState.CONNECTED: return '协同中';
      case CollaborationSessionState.DISCONNECTED: return '已断开';
      default: return '就绪';
    }
  }

  private getDeviceTypeLabel(deviceType: string): string {
    switch (deviceType) {
      case 'phone': return '手机';
      case 'tablet': return '平板';
      case '2in1': return 'PC';
      default: return deviceType;
    }
  }
}
