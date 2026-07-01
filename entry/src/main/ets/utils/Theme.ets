// utils/Theme.ets
// Lunius 主题配色与多设备适配常量

import { display } from '@kit.ArkUI';

export enum ThemeMode {
  LIGHT = 'light',
  DARK = 'dark'
}

export interface LuniusColors {
  bgPrimary: string;
  bgSecondary: string;
  bgTertiary: string;
  bgHover: string;
  bgActive: string;
  textPrimary: string;
  textSecondary: string;
  textMuted: string;
  accent: string;
  border: string;
  sidebarBg: string;
  editorBg: string;
  ribbonBg: string;
  tabBg: string;
  tabActiveBg: string;
  divider: string;
  iconPrimary: string;
  iconSecondary: string;
  scrollBar: string;
  folderIcon: string;
  fileIcon: string;
  linkColor: string;
  tagBg: string;
  tagText: string;
  codeBg: string;
  codeText: string;
  quoteBorder: string;
  quoteBg: string;
}

export const LightColors: LuniusColors = {
  bgPrimary: '#FFFFFF',
  bgSecondary: '#FAFAFA',
  bgTertiary: '#F5F5F5',
  bgHover: '#EBEBEB',
  bgActive: '#E0E0E0',
  textPrimary: '#2E2E2E',
  textSecondary: '#5C5C5C',
  textMuted: '#999999',
  accent: '#7B68EE',
  border: '#E0E0E0',
  sidebarBg: '#F8F8F8',
  editorBg: '#FFFFFF',
  ribbonBg: '#F2F2F2',
  tabBg: '#F5F5F5',
  tabActiveBg: '#FFFFFF',
  divider: '#E8E8E8',
  iconPrimary: '#5C5C5C',
  iconSecondary: '#999999',
  scrollBar: '#C1C1C1',
  folderIcon: '#C7A03C',
  fileIcon: '#7B68EE',
  linkColor: '#7B68EE',
  tagBg: '#E8E0FF',
  tagText: '#5B4BC4',
  codeBg: '#F5F5F5',
  codeText: '#D73A49',
  quoteBorder: '#7B68EE',
  quoteBg: '#F8F5FF'
};

export const DarkColors: LuniusColors = {
  bgPrimary: '#1E1E1E',
  bgSecondary: '#262626',
  bgTertiary: '#2D2D2D',
  bgHover: '#333333',
  bgActive: '#3D3D3D',
  textPrimary: '#D4D4D4',
  textSecondary: '#A0A0A0',
  textMuted: '#666666',
  accent: '#7B68EE',
  border: '#333333',
  sidebarBg: '#262626',
  editorBg: '#1E1E1E',
  ribbonBg: '#1A1A1A',
  tabBg: '#262626',
  tabActiveBg: '#1E1E1E',
  divider: '#333333',
  iconPrimary: '#A0A0A0',
  iconSecondary: '#666666',
  scrollBar: '#4D4D4D',
  folderIcon: '#C7A03C',
  fileIcon: '#7B68EE',
  linkColor: '#9370DB',
  tagBg: '#3D3566',
  tagText: '#B8A9E8',
  codeBg: '#2D2D2D',
  codeText: '#FF7B72',
  quoteBorder: '#7B68EE',
  quoteBg: '#2A2538'
};

export function getColors(mode: ThemeMode): LuniusColors {
  return mode === ThemeMode.DARK ? DarkColors : LightColors;
}

// 响应式断点 (vp)
export class Breakpoints {
  static readonly SM: number = 600;   // 手机
  static readonly MD: number = 840;   // 平板
  static readonly LG: number = 1200;  // PC/2in1
}

export enum DeviceType {
  PHONE = 'phone',
  TABLET = 'tablet',
  PC = 'pc'
}

export function getDeviceType(width: number): DeviceType {
  if (width < Breakpoints.SM) return DeviceType.PHONE;
  if (width < Breakpoints.MD) return DeviceType.TABLET;
  return DeviceType.PC;
}

// 侧边栏宽度配置
export class SidebarWidth {
  static readonly PHONE: number = 280;
  static readonly TABLET_LEFT: number = 260;
  static readonly TABLET_RIGHT: number = 240;
  static readonly PC_LEFT: number = 280;
  static readonly PC_RIGHT: number = 260;
  static readonly RIBBON: number = 44;
}

// 字体规范
interface TypographyStyle {
  size: number;
  weight: FontWeight;
  family?: string;
}

interface TypographyConfig {
  title: TypographyStyle;
  heading: TypographyStyle;
  body: TypographyStyle;
  small: TypographyStyle;
  caption: TypographyStyle;
  mono: TypographyStyle;
}

const titleStyle: TypographyStyle = { size: 20, weight: FontWeight.Bold };
const headingStyle: TypographyStyle = { size: 18, weight: FontWeight.Medium };
const bodyStyle: TypographyStyle = { size: 14, weight: FontWeight.Regular };
const smallStyle: TypographyStyle = { size: 12, weight: FontWeight.Regular };
const captionStyle: TypographyStyle = { size: 11, weight: FontWeight.Regular };
const monoStyle: TypographyStyle = { size: 13, weight: FontWeight.Regular, family: 'monospace' };

export const Typography: TypographyConfig = {
  title: titleStyle,
  heading: headingStyle,
  body: bodyStyle,
  small: smallStyle,
  caption: captionStyle,
  mono: monoStyle
};
