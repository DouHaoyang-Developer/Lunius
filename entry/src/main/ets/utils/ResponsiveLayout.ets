// utils/ResponsiveLayout.ets
// 响应式布局状态管理

import { Breakpoints, DeviceType, getDeviceType } from './Theme';

@Observed
export class ResponsiveState {
  screenWidth: number = 720;
  screenHeight: number = 1280;
  deviceType: DeviceType = DeviceType.TABLET;
  isLandscape: boolean = false;

  updateSize(width: number, height: number): void {
    this.screenWidth = width;
    this.screenHeight = height;
    this.deviceType = getDeviceType(width);
    this.isLandscape = width > height;
  }

  get isPhone(): boolean {
    return this.deviceType === DeviceType.PHONE;
  }

  get isTablet(): boolean {
    return this.deviceType === DeviceType.TABLET;
  }

  get isPC(): boolean {
    return this.deviceType === DeviceType.PC;
  }

  get showLeftSidebar(): boolean {
    return !this.isPhone || this.isLandscape;
  }

  get showRightSidebar(): boolean {
    return this.isPC || (this.isTablet && this.isLandscape);
  }

  get showRibbon(): boolean {
    return this.isPC || this.isTablet;
  }

  get editorMaxWidth(): number {
    if (this.isPC) return 900;
    if (this.isTablet) return 700;
    return this.screenWidth - 32;
  }
}
