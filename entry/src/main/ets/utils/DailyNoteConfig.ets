// utils/DailyNoteConfig.ets
// 每日笔记配置 — 日期格式/模板/文件夹/启动时打开等可配置项

export interface DailyNoteConfig {
  dateFormat: string;
  templatePath: string;
  folder: string;
  openOnStartup: boolean;
}

const DEFAULT_CONFIG: DailyNoteConfig = {
  dateFormat: 'YYYY-MM-DD',
  templatePath: '',
  folder: '',
  openOnStartup: false
};

let cachedConfig: DailyNoteConfig | null = null;

export function getDefaultDailyNoteConfig(): DailyNoteConfig {
  return {
    dateFormat: DEFAULT_CONFIG.dateFormat,
    templatePath: DEFAULT_CONFIG.templatePath,
    folder: DEFAULT_CONFIG.folder,
    openOnStartup: DEFAULT_CONFIG.openOnStartup
  };
}

export function formatDateWithConfig(date: Date, format: string): string {
  const y = date.getFullYear().toString();
  const m = (date.getMonth() + 1).toString().padStart(2, '0');
  const d = date.getDate().toString().padStart(2, '0');
  switch (format) {
    case 'YYYYMMDD': return y + m + d;
    case 'MM-DD-YYYY': return m + '-' + d + '-' + y;
    case 'DD-MM-YYYY': return d + '-' + m + '-' + y;
    default: return y + '-' + m + '-' + d;
  }
}

export function getDailyNoteFileName(config: DailyNoteConfig): string {
  const dateStr = formatDateWithConfig(new Date(), config.dateFormat);
  return dateStr + '.md';
}
