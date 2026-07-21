// utils/Theme.ets
// Lunius Design System v2 — 精炼、层次分明、专业
// 设计原则：低对比度背景层 + 高对比度内容层 + 克制的强调色

import { display } from '@kit.ArkUI';

// ─── 主题模式 ───────────────────────────────

export enum ThemeMode {
  LIGHT = 'light',
  DARK = 'dark'
}

// ─── 设计令牌接口 ─────────────────────────────

export interface LuniusColors {
  // 表面层级（从低到高）
  surface0: string;        // 最底层背景
  surface1: string;        // 侧边栏背景
  surface2: string;        // 卡片/悬浮背景
  surface3: string;        // 激活/选中背景
  surfaceHover: string;    // hover 态
  surfaceActive: string;   // active 态

  // 文字层级
  textPrimary: string;     // 正文
  textSecondary: string;   // 次要
  textTertiary: string;    // 提示/占位
  textDisabled: string;    // 禁用

  // 强调色
  accent: string;           // 主强调
  accentHover: string;      // hover 加深
  accentActive: string;     // active 更深
  accentSubtle: string;     // 轻量背景态
  onAccent: string;         // 强调色上的文字

  // 语义色
  info: string;
  infoBg: string;
  success: string;
  successBg: string;
  warning: string;
  warningBg: string;
  error: string;
  errorBg: string;

  // 边框与分隔
  border: string;           // 默认边框
  borderStrong: string;    // 强调边框
  divider: string;          // 分隔线

  // 功能色
  linkColor: string;
  tagBg: string;
  tagText: string;
  codeBg: string;
  codeText: string;
  quoteBorder: string;
  quoteBg: string;
  folderIcon: string;
  fileIcon: string;

  // 毛玻璃
  frostedBg: string;
  frostedBgLight: string;
  frostedBgThick: string;
  overlayBg: string;

  // 移动端
  mobileNavBg: string;
  mobileToolbarBg: string;

  // 环境光
  ambientGlowRate: number;
  ambientGlowDegree: number;

  // ── 向后兼容别名（已废弃，新代码请用新令牌）──
  bgPrimary: string;       // → surface0
  bgSecondary: string;    // → surface2
  bgTertiary: string;     // → surface1
  bgHover: string;        // → surfaceHover
  bgActive: string;       // → surfaceActive
  textMuted: string;      // → textTertiary
  iconPrimary: string;    // → textPrimary
  iconSecondary: string;  // → textSecondary
  editorBg: string;      // → surface0
  sidebarBg: string;     // → surface1
  ribbonBg: string;      // → surface1
  tabBg: string;         // → surface1
  tabActiveBg: string;   // → surface2
  scrollBar: string;     // → border
}

// ─── 浅色主题 ───────────────────────────────

export const LightColors: LuniusColors = {
  surface0: '#FFFFFF',
  surface1: '#F7F7F8',
  surface2: '#F0F0F2',
  surface3: '#E8E8EB',
  surfaceHover: '#EDEDF0',
  surfaceActive: '#E0E0E5',

  textPrimary: '#1A1A1D',
  textSecondary: '#555559',
  textTertiary: '#8E8E93',
  textDisabled: '#C4C4C8',

  accent: '#6B46C1',
  accentHover: '#5B36B0',
  accentActive: '#4B2A9A',
  accentSubtle: '#F3EFFE',
  onAccent: '#FFFFFF',

  info: '#2563EB',
  infoBg: '#EFF6FF',
  success: '#16A34A',
  successBg: '#F0FDF4',
  warning: '#D97706',
  warningBg: '#FFFBEB',
  error: '#DC2626',
  errorBg: '#FEF2F2',

  border: '#E5E5E8',
  borderStrong: '#D1D1D6',
  divider: '#EEEEF0',

  linkColor: '#6B46C1',
  tagBg: '#F3EFFE',
  tagText: '#5B36B0',
  codeBg: '#F5F5F7',
  codeText: '#D6336C',
  quoteBorder: '#6B46C1',
  quoteBg: '#FAF8FF',
  folderIcon: '#B8860B',
  fileIcon: '#6B46C1',

  frostedBg: 'rgba(255,255,255,0.82)',
  frostedBgLight: 'rgba(250,250,252,0.70)',
  frostedBgThick: 'rgba(255,255,255,0.92)',
  overlayBg: 'rgba(0,0,0,0.12)',

  mobileNavBg: 'rgba(255,255,255,0.90)',
  mobileToolbarBg: 'rgba(247,247,248,0.88)',

  ambientGlowRate: 0.4,
  ambientGlowDegree: 0.3,

  // 向后兼容别名
  bgPrimary: '#FFFFFF',
  bgSecondary: '#F0F0F2',
  bgTertiary: '#F7F7F8',
  bgHover: '#EDEDF0',
  bgActive: '#E8E8EB',
  textMuted: '#8E8E93',
  iconPrimary: '#1A1A1D',
  iconSecondary: '#555559',
  editorBg: '#FFFFFF',
  sidebarBg: '#F7F7F8',
  ribbonBg: '#F7F7F8',
  tabBg: '#F7F7F8',
  tabActiveBg: '#F0F0F2',
  scrollBar: '#E5E5E8'
};

// ─── 深色主题 ───────────────────────────────

export const DarkColors: LuniusColors = {
  surface0: '#1A1A1D',
  surface1: '#212126',
  surface2: '#2A2A30',
  surface3: '#33333B',
  surfaceHover: '#2D2D35',
  surfaceActive: '#3A3A44',

  textPrimary: '#E4E4E7',
  textSecondary: '#A1A1AA',
  textTertiary: '#71717A',
  textDisabled: '#52525B',

  accent: '#A78BFA',
  accentHover: '#C4B5FD',
  accentActive: '#8B5CF6',
  accentSubtle: '#2D2640',
  onAccent: '#1A1A1D',

  info: '#60A5FA',
  infoBg: '#1E2A3A',
  success: '#4ADE80',
  successBg: '#1A2E25',
  warning: '#FBBF24',
  warningBg: '#2E2818',
  error: '#F87171',
  errorBg: '#2E1F22',

  border: '#2E2E36',
  borderStrong: '#3F3F4A',
  divider: '#282830',

  linkColor: '#A78BFA',
  tagBg: '#2D2640',
  tagText: '#C4B5FD',
  codeBg: '#26262E',
  codeText: '#F472B6',
  quoteBorder: '#7C3AED',
  quoteBg: '#241F36',
  folderIcon: '#D4A537',
  fileIcon: '#A78BFA',

  frostedBg: 'rgba(26,26,29,0.82)',
  frostedBgLight: 'rgba(33,33,38,0.70)',
  frostedBgThick: 'rgba(26,26,29,0.92)',
  overlayBg: 'rgba(0,0,0,0.30)',

  mobileNavBg: 'rgba(33,33,38,0.90)',
  mobileToolbarBg: 'rgba(33,33,38,0.88)',

  ambientGlowRate: 0.4,
  ambientGlowDegree: 0.3,

  // 向后兼容别名
  bgPrimary: '#1A1A1D',
  bgSecondary: '#2A2A30',
  bgTertiary: '#212126',
  bgHover: '#2D2D35',
  bgActive: '#33333B',
  textMuted: '#71717A',
  iconPrimary: '#E4E4E7',
  iconSecondary: '#A1A1AA',
  editorBg: '#1A1A1D',
  sidebarBg: '#212126',
  ribbonBg: '#212126',
  tabBg: '#212126',
  tabActiveBg: '#2A2A30',
  scrollBar: '#2E2E36'
};

export function getColors(mode: ThemeMode): LuniusColors {
  return mode === ThemeMode.DARK ? DarkColors : LightColors;
}

// ─── 响应式断点 ─────────────────────────────

export class Breakpoints {
  static readonly SM: number = 600;
  static readonly MD: number = 840;
  static readonly LG: number = 1200;
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

// ─── 尺寸常量 ───────────────────────────────

export class SidebarWidth {
  static readonly PHONE: number = 300;
  static readonly TABLET_LEFT: number = 260;
  static readonly TABLET_RIGHT: number = 240;
  static readonly PC_LEFT: number = 280;
  static readonly PC_RIGHT: number = 260;
  static readonly RIBBON: number = 48;
  static readonly RIBBON_PC: number = 52;
  static readonly COLLAPSED: number = 0;
}

export class Spacing {
  static readonly XS: number = 4;
  static readonly SM: number = 8;
  static readonly MD: number = 12;
  static readonly LG: number = 16;
  static readonly XL: number = 24;
  static readonly XXL: number = 32;
  static readonly EDGE_GESTURE: number = 20;
  static readonly MOBILE_NAV_HEIGHT: number = 56;
  static readonly MOBILE_TOOLBAR_HEIGHT: number = 44;
  static readonly SIDEBAR_TAB_HEIGHT: number = 40;
  static readonly TOOLBAR_HEIGHT: number = 44;
  static readonly STATUS_BAR_HEIGHT: number = 28;
  static readonly RIBBON_ITEM: number = 40;
  static readonly RIBBON_ITEM_PC: number = 44;
  static readonly TAB_HEIGHT: number = 36;
  static readonly TAB_HEIGHT_COMPACT: number = 32;
  static readonly FILE_TREE_ITEM: number = 32;
}

export class Radius {
  static readonly XS: number = 3;
  static readonly SM: number = 6;
  static readonly MD: number = 8;
  static readonly LG: number = 12;
  static readonly XL: number = 16;
  static readonly FULL: number = 999;
  static readonly SHEET: number = 20;
  static readonly CAPSULE: number = 28;
}

// ─── 图标系统 ───────────────────────────────
// 使用几何 Unicode 符号 + 少量 Emoji，统一风格
// 优先使用无修饰符的纯符号，确保跨设备一致性

export class Icons {
  // 导航
  static readonly FILE_EXPLORER: string = '\u2630';       // ☰ 三横线
  static readonly SEARCH: string = '\u25CE';             // ◎ 同心圆
  static readonly GRAPH: string = '\u25C8';              // ◈ 菱形
  static readonly DAILY_NOTE: string = '\u25A3';         // ▣ 方块
  static readonly SETTINGS: string = '\u2699';          // ⚙ 齿轮
  static readonly THEME: string = '\u25D0';             // ◐ 半圆

  // 文件操作
  static readonly NEW_NOTE: string = '\u2795';           // ➕ 加号
  static readonly SAVE: string = '\u25C9';              // ◉ 实心圆
  static readonly PROPERTIES: string = '\u25C6';        // ◆ 菱形
  static readonly ATTACHMENT: string = '\u229E';         // ⊞ 方格
  static readonly IMAGE: string = '\u25A4';             // ▤ 网格方块

  // 导航箭头
  static readonly BACK: string = '\u2190';              // ←
  static readonly FORWARD: string = '\u2192';           // →
  static readonly CHEVRON_UP: string = '\u02C4';        // ˄
  static readonly CHEVRON_DOWN: string = '\u02C5';     // ˅
  static readonly CLOSE: string = '\u2715';             // ✕
  static readonly MORE: string = '\u22EF';              // ⋯
  static readonly PLUS: string = '+';
  static readonly DASH: string = '\u2014';              // —
  static readonly COMMAND: string = '\u2318';           // ⌘
  static readonly MENU: string = '\u2630';              // ☰
  static readonly PIN: string = '\u25C2';               // ◂ 三角
  static readonly CHECK: string = '\u2713';             // ✓
  static readonly BULLET: string = '\u2022';           // •
  static readonly UNDO: string = '\u21B6';             // ↶
  static readonly REDO: string = '\u21B7';             // ↷
  static readonly ZOOM_IN: string = '\u2295';           // ⊕
  static readonly ZOOM_OUT: string = '\u2296';         // ⊖
  static readonly RESET: string = '\u21BA';            // ↺

  // 侧边栏
  static readonly SIDEBAR_LEFT: string = '\u25E0';      // ◠ 上半圆
  static readonly SIDEBAR_RIGHT: string = '\u25E1';     // ◡ 下半圆
  static readonly TAB_COUNT: string = '\u25A4';        // ▤
  static readonly QUICK_SWITCH: string = '\u25CB';      // ○ 空心圆
  static readonly EXPAND_LEFT: string = '\u25C0';      // ◀
  static readonly EXPAND_RIGHT: string = '\u25B6';     // ▶

  // 标签页
  static readonly NEW_TAB: string = '\u2795';           // ➕
  static readonly CLOSE_TAB: string = '\u2715';        // ✕
  static readonly TAB: string = '\u25A4';               // ▤

  // 编辑
  static readonly BOLD: string = 'B';
  static readonly ITALIC: string = 'I';
  static readonly HEADING: string = 'H';
  static readonly STRIKE: string = 'S';
  static readonly LINK: string = '\u26AD';             // ⚭ 链接符号
  static readonly CODE: string = '\u2237';             // ∷ 冒号
  static readonly QUOTE: string = '\u201C';            // "
  static readonly LIST: string = '\u2261';             // ≡ 三横
  static readonly CHECKLIST: string = '\u2610';        // ☐ 复选框
  static readonly CHECKBOX: string = '\u2610';         // ☐ 复选框
  static readonly NUMBER: string = '\u2317';           // ⌗ 编号符号

  // 视图模式
  static readonly VIEW_SOURCE: string = '\u2261';       // ≡ 源码
  static readonly VIEW_PREVIEW: string = '\u25A3';     // ▣ 预览
  static readonly VIEW_SPLIT: string = '\u22A2';        // ⊢ 分屏

  // 状态
  static readonly SYNC: string = '\u21BB';            // ↻ 循环
  static readonly SYNC_DONE: string = '\u2713';       // ✓
  static readonly PENDING: string = '\u2191';         // ↑
  static readonly LOADING: string = '\u2295';         // ⊕

  // 文件树
  static readonly FOLDER_OPEN: string = '\u25A2';     // ▢ 空心方块
  static readonly FOLDER_CLOSED: string = '\u25A0';   // ■ 实心方块
  static readonly FILE: string = '\u25A4';            // ▤ 网格方块
  static readonly VAULT: string = '\u25C6';           // ◆ 菱形
  static readonly CHEVRON_RIGHT: string = '\u25B8';   // ▸ 小右三角

  // 面板
  static readonly OUTLINE: string = '\u2261';         // ≡ 三横
  static readonly BACKLINK: string = '\u26AD';        // ⚭ 链接
  static readonly BOOKMARK: string = '\u25C2';         // ◂ 三角
  static readonly PLUGIN: string = '\u2294';          // ⊔ 插件

  // 协作
  static readonly COLLABORATE: string = '\u229E';       // ⊞ 方格

  // 图谱
  static readonly REFRESH: string = '\u21BB';          // ↻
}

// ─── 排版 ───────────────────────────────────

interface TypographyStyle {
  size: number;
  weight: FontWeight;
  family?: string;
  lineHeight?: number;
  letterSpacing?: number;
}

interface TypographyConfig {
  display: TypographyStyle;   // 大标题/空状态
  title: TypographyStyle;      // 页面标题
  heading: TypographyStyle;     // 区块标题
  body: TypographyStyle;       // 正文
  bodySmall: TypographyStyle;  // 小正文
  caption: TypographyStyle;    // 说明文字
  micro: TypographyStyle;       // 极小文字（徽标等）
  mono: TypographyStyle;       // 等宽
}

export const Typography: TypographyConfig = {
  display: { size: 24, weight: FontWeight.Bold, lineHeight: 32 },
  title:    { size: 18, weight: FontWeight.Medium, lineHeight: 24 },
  heading:  { size: 15, weight: FontWeight.Medium, lineHeight: 20 },
  body:     { size: 14, weight: FontWeight.Regular, lineHeight: 20 },
  bodySmall:{ size: 13, weight: FontWeight.Regular, lineHeight: 18 },
  caption:  { size: 12, weight: FontWeight.Regular, lineHeight: 16 },
  micro:    { size: 10, weight: FontWeight.Medium, lineHeight: 14, letterSpacing: 0.5 },
  mono:     { size: 13, weight: FontWeight.Regular, family: 'monospace', lineHeight: 18 }
};

// ─── 侧边栏标签页配置 ─────────────────────────

export interface SidebarTab {
  id: string;
  icon: string;
  label: string;
}

export const LeftSidebarTabs: SidebarTab[] = [
  { id: 'fileExplorer', icon: Icons.FILE_EXPLORER, label: '\u6587\u4EF6' },
  { id: 'search', icon: Icons.SEARCH, label: '\u641C\u7D22' },
  { id: 'bookmarks', icon: Icons.PIN, label: '\u4E66\u7B7E' }
];

export const RightSidebarTabs: SidebarTab[] = [
  { id: 'outline', icon: Icons.PROPERTIES, label: '\u5927\u7EB2' },
  { id: 'backlinks', icon: Icons.BACKLINK, label: '\u53CD\u5411\u94FE\u63A5' },
  { id: 'bookmarks', icon: Icons.PIN, label: '\u4E66\u7B7E' }
];

// ─── 动画令牌 ───────────────────────────────

export class Motion {
  static readonly FAST: number = 150;    // 快速过渡
  static readonly NORMAL: number = 250;   // 标准过渡
  static readonly SLOW: number = 400;    // 慢速过渡
  static readonly SHEET: number = 300;    // 弹窗过渡
}

// ─── 编辑器模式 ─────────────────────────────

export class EditorViewMode {
  static readonly LIVE: string = 'live';
  static readonly SOURCE: string = 'source';
  static readonly PREVIEW: string = 'preview';
  static readonly SPLIT: string = 'split';

  static readonly ALL: string[] = ['live', 'source', 'preview', 'split'];
  static readonly LABELS: Record<string, string> = {
    'live': '\u5B9E\u65F6',
    'source': '\u6E90\u7801',
    'preview': '\u9605\u8BFB',
    'split': '\u5206\u5C4F'
  };
}
