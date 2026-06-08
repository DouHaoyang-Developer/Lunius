// utils/TemplateEngine.ets
// 模板变量引擎 — 支持 {{date}} {{time}} {{title}} + {{#if}}/{{#each}}/{{lql:}}/{{date: offset}}

import { templateExecutor, TemplateContext as ExecutorContext } from './TemplateExecutor';

export interface TemplateContext {
  date: string;
  time: string;
  title: string;
  filename: string;
  folder: string;
  tags?: string[];
  frontmatter?: Record<string, string | string[]>;
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

export async function renderTemplateAsync(template: string, ctx: TemplateContext): Promise<string> {
  const vars: Record<string, string | string[]> = {
    'date': ctx.date,
    'time': ctx.time,
    'title': ctx.title,
    'filename': ctx.filename,
    'folder': ctx.folder
  };

  if (ctx.tags) {
    vars['tags'] = ctx.tags;
  }

  if (ctx.frontmatter) {
    for (const key of Object.keys(ctx.frontmatter)) {
      vars[key] = ctx.frontmatter[key];
    }
  }

  const execCtx: ExecutorContext = { variables: vars };
  return await templateExecutor.applyTemplate(template, execCtx);
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
