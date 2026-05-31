// utils/TemplateEngine.ets
// 模板变量引擎 — 支持 {{date}} {{time}} {{title}} {{filename}} {{folder}} 等变量

export interface TemplateContext {
  date: string;
  time: string;
  title: string;
  filename: string;
  folder: string;
}

export function renderTemplate(template: string, ctx: TemplateContext): string {
  const now = new Date();
  const dateStr = ctx.date || `${now.getFullYear()}-${String(now.getMonth()+1).padStart(2,'0')}-${String(now.getDate()).padStart(2,'0')}`;
  const timeStr = ctx.time || `${String(now.getHours()).padStart(2,'0')}:${String(now.getMinutes()).padStart(2,'0')}`;

  return template
    .replace(/\{\{date\}\}/g, dateStr)
    .replace(/\{\{time\}\}/g, timeStr)
    .replace(/\{\{title\}\}/g, ctx.title || '未命名')
    .replace(/\{\{filename\}\}/g, ctx.filename || ctx.title || '未命名')
    .replace(/\{\{folder\}\}/g, ctx.folder || '');
}

export function makeTemplateContext(title: string, folder?: string): TemplateContext {
  const now = new Date();
  return {
    date: `${now.getFullYear()}-${String(now.getMonth()+1).padStart(2,'0')}-${String(now.getDate()).padStart(2,'0')}`,
    time: `${String(now.getHours()).padStart(2,'0')}:${String(now.getMinutes()).padStart(2,'0')}`,
    title: title,
    filename: title,
    folder: folder || ''
  };
}
