// utils/TemplateEngine.ets
// 模板变量引擎 — 支持 {{date}} {{time}} {{title}} + {{#if}}/{{#each}}/{{lql:}}/{{date: offset}}

import { templateExecutor, TemplateContext as ExecutorContext, VariablesMap } from './TemplateExecutor';

export interface TemplateContext {
  date: string;
  time: string;
  title: string;
  filename: string;
  folder: string;
  tags?: string[];
}

export function renderTemplate(template: string, ctx: TemplateContext): string {
  const now = new Date();
  const dateStr = ctx.date || now.getFullYear() + '-' + String(now.getMonth()+1).padStart(2,'0') + '-' + String(now.getDate()).padStart(2,'0');
  const timeStr = ctx.time || String(now.getHours()).padStart(2,'0') + ':' + String(now.getMinutes()).padStart(2,'0');

  return template
    .replace(/\{\{date\}\}/g, dateStr)
    .replace(/\{\{time\}\}/g, timeStr)
    .replace(/\{\{title\}\}/g, ctx.title || '未命名')
    .replace(/\{\{filename\}\}/g, ctx.filename || ctx.title || '未命名')
    .replace(/\{\{folder\}\}/g, ctx.folder || '');
}

export async function renderTemplateAsync(template: string, ctx: TemplateContext): Promise<string> {
  const vars: VariablesMap = new VariablesMap();
  vars.set('date', ctx.date);
  vars.set('time', ctx.time);
  vars.set('title', ctx.title);
  vars.set('filename', ctx.filename);
  vars.set('folder', ctx.folder);

  if (ctx.tags) {
    vars.set('tags', ctx.tags);
  }

  const execCtx: ExecutorContext = { variables: vars };
  return await templateExecutor.applyTemplate(template, execCtx);
}

export function makeTemplateContext(title: string, folder?: string): TemplateContext {
  const now = new Date();
  const dateFull = now.getFullYear() + '-' + String(now.getMonth()+1).padStart(2,'0') + '-' + String(now.getDate()).padStart(2,'0');
  const timeFull = String(now.getHours()).padStart(2,'0') + ':' + String(now.getMinutes()).padStart(2,'0');
  const ctx: TemplateContext = {
    date: dateFull,
    time: timeFull,
    title: title,
    filename: title,
    folder: folder || ''
  };
  return ctx;
}
