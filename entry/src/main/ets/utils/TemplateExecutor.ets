// utils/TemplateExecutor.ets
// 模板执行器 — 条件/循环/日期/LQL 内联求值

import { TemplateExpr, TemplateExprType, TemplateParser } from './TemplateParser';
import { lqlExecutor } from './LQLExecutor';
import { lqlRenderer } from './LQLRenderer';

export interface TemplateContext {
  variables: Record<string, string | string[]>;
}

export class TemplateExecutor {
  async applyTemplate(template: string, context: TemplateContext): Promise<string> {
    let result = template;

    // 1. LQL 内联查询: {{lql: TABLE ...}}
    result = await this.applyLqlQueries(result);

    // 2. 条件块: {{#if condition}}body{{else}}alt{{/if}}
    result = this.applyIfBlocks(result, context);

    // 3. 循环块: {{#each array}}item{{/each}}
    result = this.applyEachBlocks(result, context);

    // 4. 日期计算: {{date: +7d}}
    result = this.applyDateCalc(result);

    // 5. 简单变量: {{title}} {{date}}
    result = this.applyVariables(result, context);

    return result;
  }

  private async applyLqlQueries(template: string): Promise<string> {
    const lqlRegex = /\{\{lql:\s*([^}]+)\}\}/g;
    let result = template;
    const matches = template.matchAll(lqlRegex);
    const replacements: { original: string; html: string }[] = [];

    for (const m of matches) {
      try {
        const lqlText = m[1].trim();
        const lqlResult = await lqlExecutor.execute(lqlText);
        const html = lqlRenderer.render(lqlResult);
        replacements.push({ original: m[0], html: `<div style="margin:8px 0;">${html}</div>` });
      } catch (e) {
        replacements.push({ original: m[0], html: `[LQL错误: ${e}]` });
      }
    }

    for (const r of replacements) {
      result = result.replace(r.original, r.html);
    }
    return result;
  }

  private applyIfBlocks(template: string, context: TemplateContext): string {
    const ifRegex = /\{\{#if\s+([^}]+)\}\}([\s\S]*?)\{\{\/if\}\}/g;
    return template.replace(ifRegex, (_m: string, condition: string, body: string): string => {
      // 处理 {{else}}
      let ifBody = body;
      let elseBody = '';
      const elseIdx = body.indexOf('{{else}}');
      if (elseIdx >= 0) {
        ifBody = body.substring(0, elseIdx);
        elseBody = body.substring(elseIdx + 8);
      }

      const result = this.evaluateCondition(condition.trim(), context);
      if (result) {
        // 递归处理 ifBody 中的变量
        return this.replaceVariables(ifBody, context);
      }
      return elseBody ? this.replaceVariables(elseBody, context) : '';
    });
  }

  private applyEachBlocks(template: string, context: TemplateContext): string {
    const eachRegex = /\{\{#each\s+([^}]+)\}\}([\s\S]*?)\{\{\/each\}\}/g;
    return template.replace(eachRegex, (_m: string, arrayExpr: string, body: string): string => {
      const arr = this.resolveArray(arrayExpr.trim(), context);
      if (arr.length === 0) return '';

      let result = '';
      for (const item of arr) {
        const itemCtx: TemplateContext = {
          variables: { ...context.variables, 'this': item }
        };
        result += this.replaceVariables(body, itemCtx);
      }
      return result;
    });
  }

  private applyDateCalc(template: string): string {
    return template.replace(/\{\{date:\s*([^}]+)\}\}/g, (_m: string, dateExpr: string): string => {
      return this.resolveDate(dateExpr.trim());
    });
  }

  private applyVariables(template: string, context: TemplateContext): string {
    return this.replaceVariables(template, context);
  }

  // ─── 工具方法 ─────────────────────────────────

  private replaceVariables(text: string, context: TemplateContext): string {
    return text.replace(/\{\{(\w+)\}\}/g, (_m: string, varName: string): string => {
      const val = context.variables[varName];
      if (Array.isArray(val)) {
        return val.join(', ');
      }
      return val !== undefined ? val : `{{${varName}}}`;
    });
  }

  private evaluateCondition(condition: string, context: TemplateContext): boolean {
    // 简单条件：status == "draft" 或 status != "draft"
    const eqMatch = condition.match(/^(\w+)\s*==\s*"([^"]+)"$/);
    if (eqMatch) {
      const val = context.variables[eqMatch[1]];
      return String(val) === eqMatch[2];
    }
    const neqMatch = condition.match(/^(\w+)\s*!=\s*"([^"]+)"$/);
    if (neqMatch) {
      const val = context.variables[neqMatch[1]];
      return String(val) !== neqMatch[2];
    }
    // 变量是否存在
    const existsMatch = condition.match(/^(\w+)$/);
    if (existsMatch) {
      const val = context.variables[existsMatch[1]];
      return val !== undefined && val !== '' && val !== 'false';
    }
    return false;
  }

  private resolveArray(arrayExpr: string, context: TemplateContext): string[] {
    // file.tags → context.variables['tags']
    const parts = arrayExpr.split('.');
    const rootVar = parts[parts.length - 1] || parts[0];
    const val = context.variables[rootVar];
    if (Array.isArray(val)) return val;
    if (typeof val === 'string') return val.split(',').map((s: string) => s.trim()).filter((s: string) => s.length > 0);
    return [];
  }

  private resolveDate(dateExpr: string): string {
    const now = new Date();
    let target = now;

    // 解析偏移量: +7d / -1m / +1y
    const offsetRegex = /([+-]?\d+)([dmy])/g;
    let m: RegExpExecArray | null;
    while ((m = offsetRegex.exec(dateExpr)) !== null) {
      const num = parseInt(m[1]);
      const unit = m[2];
      if (unit === 'd') target = new Date(target.getTime() + num * 86400000);
      if (unit === 'm') target = new Date(target.getFullYear(), target.getMonth() + num, target.getDate());
      if (unit === 'y') target = new Date(target.getFullYear() + num, target.getMonth(), target.getDate());
    }

    // 格式化
    const formatMatch = dateExpr.match(/format\s+"([^"]+)"/);
    const fmt = formatMatch ? formatMatch[1] : 'YYYY-MM-DD';

    return this.formatDate(target, fmt);
  }

  private formatDate(date: Date, format: string): string {
    const y = String(date.getFullYear());
    const m = String(date.getMonth() + 1).padStart(2, '0');
    const d = String(date.getDate()).padStart(2, '0');
    const h = String(date.getHours()).padStart(2, '0');
    const mi = String(date.getMinutes()).padStart(2, '0');

    return format
      .replace('YYYY', y)
      .replace('MM', m)
      .replace('DD', d)
      .replace('HH', h)
      .replace('mm', mi);
  }
}

export const templateExecutor: TemplateExecutor = new TemplateExecutor();
