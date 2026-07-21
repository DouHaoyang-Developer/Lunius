// components/CollaborationPanel.ets
// Lunius-style distributed collaboration panel — session management and participant list

import { LuniusColors, ThemeMode, getColors, Spacing, Radius } from '../utils/Theme';
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
  @Prop isVisible: boolean = false;
  @State joinSessionId: string = '';
  onStartSession: () => void = () => {};
  onJoinSession: (sessionId: string) => void = () => {};
  onLeaveSession: () => void = () => {};
  onInviteDevice: (deviceId: string) => void = () => {};
  onClose: () => void = () => {};

  private colors(): LuniusColors {
    return getColors(this.themeMode);
  }

  private getHasActiveSession(): boolean {
    if (this.session === null) {
      return false;
    }
    return this.session.state !== CollaborationSessionState.IDLE;
  }

  private getSession(): CollaborationSession {
    if (this.session === null) {
      return {
        sessionId: '',
        noteId: '',
        noteTitle: '',
        hostDeviceId: '',
        participants: [],
        state: CollaborationSessionState.IDLE,
        createdAt: 0,
        lastActivityAt: 0
      };
    }
    return this.session;
  }

  private handleJoinClick(): void {
    const trimmed: string = this.joinSessionId.trim();
    if (trimmed.length > 0) {
      this.onJoinSession(trimmed);
    }
  }

  private getStateLabel(state: CollaborationSessionState): string {
    if (state === CollaborationSessionState.HOSTING) {
      return 'Waiting...';
    }
    if (state === CollaborationSessionState.CONNECTED) {
      return 'Connected';
    }
    if (state === CollaborationSessionState.DISCONNECTED) {
      return 'Disconnected';
    }
    if (state === CollaborationSessionState.JOINING) {
      return 'Joining...';
    }
    return 'Idle';
  }

  private getDeviceTypeLabel(deviceType: string): string {
    if (deviceType === 'phone') {
      return 'Phone';
    }
    if (deviceType === 'tablet') {
      return 'Tablet';
    }
    if (deviceType === '2in1') {
      return 'PC';
    }
    return deviceType;
  }

  private getStateColor(state: CollaborationSessionState): string {
    if (state === CollaborationSessionState.CONNECTED) {
      return '#4CAF50';
    }
    if (state === CollaborationSessionState.HOSTING ||
        state === CollaborationSessionState.JOINING) {
      return '#FF9800';
    }
    return this.colors().textTertiary;
  }

  private getNoteTitle(): string {
    if (this.session === null) {
      return '';
    }
    return this.session.noteTitle;
  }

  private getParticipants(): CollaboratorDevice[] {
    if (this.session === null) {
      return [];
    }
    return this.session.participants;
  }

  private getParticipantCount(): number {
    if (this.session === null) {
      return 0;
    }
    return this.session.participants.length;
  }

  private getSessionState(): CollaborationSessionState {
    if (this.session === null) {
      return CollaborationSessionState.IDLE;
    }
    return this.session.state;
  }

  build() {
    if (this.isVisible) {
      Column() {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('rgba(0,0,0,0.45)')
          .onClick(() => { this.onClose(); })

        Column() {
          Row() {
            Text('Collaboration')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.colors().textPrimary)
              .layoutWeight(1)

            Button({ type: ButtonType.Circle }) {
              Text('\u2715')
                .fontSize(10)
                .fontColor(this.colors().textTertiary)
            }
            .width(22)
            .height(22)
            .backgroundColor(Color.Transparent)
            .onClick(() => { this.onClose(); })
          }
          .width('100%')
          .height(40)
          .padding({ left: Spacing.LG, right: Spacing.SM })
          .backgroundColor(this.colors().surface2)
          .border({ width: { bottom: 1 }, color: this.colors().border })
          .borderRadius({ topLeft: Radius.MD, topRight: Radius.MD })

          if (this.getHasActiveSession()) {
            this.SessionStatusView()
          }

          if (this.session !== null && this.session.participants.length > 0) {
            this.DeviceListView()
          } else if (this.session === null || this.session.state === CollaborationSessionState.IDLE) {
            this.IdleStateView()
          }

          Row() {
            if (this.getHasActiveSession()) {
              Button('Leave session')
                .fontSize(12)
                .fontColor('#FFFFFF')
                .backgroundColor('#D32F2F')
                .borderRadius(Radius.SM)
                .layoutWeight(1)
                .height(36)
                .onClick(() => { this.onLeaveSession(); })
            } else {
              Button('Start session')
                .fontSize(12)
                .fontColor('#FFFFFF')
                .backgroundColor(this.colors().accent)
                .borderRadius(Radius.SM)
                .layoutWeight(1)
                .height(36)
                .onClick(() => { this.onStartSession(); })
            }
          }
          .width('100%')
          .padding({ left: Spacing.LG, right: Spacing.LG, top: Spacing.MD, bottom: Spacing.LG })
          .backgroundColor(this.colors().surface2)
          .border({ width: { top: 1 }, color: this.colors().border })
          .borderRadius({ bottomLeft: Radius.MD, bottomRight: Radius.MD })
        }
        .width(300)
        .backgroundColor(this.colors().frostedBg)
        .borderRadius(Radius.MD)
        .border({ width: 1, color: this.colors().border })
        .shadow({ radius: 20, color: 'rgba(0,0,0,0.35)', offsetX: 0, offsetY: 8 })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .zIndex(250)
    }
  }

  @Builder
  SessionStatusView() {
    Column() {
      Row() {
        Circle({ width: 7, height: 7 })
          .fill(this.getStateColor(this.getSessionState()))
          .margin({ right: Spacing.SM })

        Text(this.getStateLabel(this.getSessionState()))
          .fontSize(12)
          .fontColor(this.colors().textSecondary)

        Text('  |  ' + this.getNoteTitle())
          .fontSize(11)
          .fontColor(this.colors().textTertiary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .flexShrink(1)
      }
      .width('100%')
      .padding({ left: Spacing.LG, right: Spacing.LG, top: Spacing.SM })

      Text(this.getParticipantCount().toString() + ' device' + (this.getParticipantCount() !== 1 ? 's' : '') + ' online')
        .fontSize(11)
        .fontColor(this.colors().textTertiary)
        .width('100%')
        .padding({ left: Spacing.LG, right: Spacing.LG, bottom: Spacing.SM })
    }
    .width('100%')
    .backgroundColor(this.colors().surface1)
    .border({ width: { bottom: 1 }, color: this.colors().border })
  }

  @Builder
  DeviceListView() {
    Column() {
      Text('Participants')
        .fontSize(11)
        .fontColor(this.colors().textTertiary)
        .fontWeight(FontWeight.Medium)
        .width('100%')
        .padding({ left: Spacing.LG, top: Spacing.MD, bottom: Spacing.SM })

      ForEach(this.getParticipants(), (device: CollaboratorDevice, index: number) => {
        Row() {
          Circle({ width: 8, height: 8 })
            .fill(DEVICE_CURSOR_COLORS[index % DEVICE_CURSOR_COLORS.length])
            .margin({ right: Spacing.SM })

          Column() {
            Text(device.deviceName)
              .fontSize(12)
              .fontColor(this.colors().textPrimary)

            Text(this.getDeviceTypeLabel(device.deviceType))
              .fontSize(10)
              .fontColor(this.colors().textTertiary)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          if (device.isHost) {
            Text('Host')
              .fontSize(10)
              .fontColor(this.colors().accent)
              .padding({ left: Spacing.SM, right: Spacing.SM, top: 1, bottom: 1 })
              .backgroundColor(this.colors().tagBg)
              .borderRadius(Radius.SM)
          }

          if (device.isOnline) {
            Circle({ width: 6, height: 6 })
              .fill('#4CAF50')
              .margin({ left: Spacing.SM })
          }
        }
        .width('100%')
        .height(40)
        .padding({ left: Spacing.LG, right: Spacing.LG })
        .backgroundColor(this.colors().frostedBg)
      }, (device: CollaboratorDevice) => device.deviceId)
    }
    .width('100%')
    .border({ width: { bottom: 1 }, color: this.colors().border })
  }

  @Builder
  IdleStateView() {
    Column() {
      Column() {
        Text('\uD83D\uDCE1')
          .fontSize(32)
          .margin({ bottom: Spacing.SM })

        Text('No active session')
          .fontSize(13)
          .fontColor(this.colors().textPrimary)
          .margin({ bottom: Spacing.XS })

        Text('Start a session to collaborate in real-time with nearby devices')
          .fontSize(11)
          .fontColor(this.colors().textTertiary)
          .textAlign(TextAlign.Center)
          .width('90%')
          .lineHeight(16)
      }
      .width('100%')
      .padding({ top: Spacing.XL, bottom: Spacing.LG })
      .justifyContent(FlexAlign.Center)

      Row() {
        TextInput({ placeholder: 'Session ID...' })
          .fontSize(12)
          .fontColor(this.colors().textPrimary)
          .placeholderColor(this.colors().textTertiary)
          .height(34)
          .layoutWeight(1)
          .backgroundColor(this.colors().surface1)
          .borderRadius(Radius.SM)
          .padding({ left: Spacing.MD, right: Spacing.MD })
          .onChange((value: string) => {
            this.joinSessionId = value;
          })

        Button('Join')
          .fontSize(12)
          .fontColor('#FFFFFF')
          .height(34)
          .backgroundColor(this.colors().accent)
          .borderRadius(Radius.SM)
          .padding({ left: Spacing.LG, right: Spacing.LG })
          .margin({ left: Spacing.SM })
          .onClick(() => { this.handleJoinClick(); })
      }
      .width('100%')
      .padding({ left: Spacing.LG, right: Spacing.LG, bottom: Spacing.LG })
    }
    .width('100%')
  }
}
