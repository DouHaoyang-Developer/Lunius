// utils/TemplateExecutor.ets
// 模板执行器 — 条件/循环/日期/LQL 内联求值

import { TemplateExpr, TemplateExprType, TemplateParser } from './TemplateParser';
import { lqlExecutor } from './LQLExecutor';
import { lqlRenderer } from './LQLRenderer';

export class VariablesMap {
  private data: Map<string, string | string[]> = new Map();

  get(key: string): string | string[] | undefined {
    return this.data.get(key);
  }

  set(key: string, value: string | string[]): void {
    this.data.set(key, value);
  }

  has(key: string): boolean {
    return this.data.has(key);
  }

  keys(): string[] {
    const result: string[] = [];
    this.data.forEach((_v: string | string[], k: string) => {
      result.push(k);
    });
    return result;
  }
}

export interface TemplateContext {
  variables: VariablesMap;
}

interface LQLReplacement {
  original: string;
  html: string;
}

export class TemplateExecutor {
  async applyTemplate(template: string, context: TemplateContext): Promise<string> {
    let result = template;

    result = await this.applyLqlQueries(result);
    result = this.applyIfBlocks(result, context);
    result = this.applyEachBlocks(result, context);
    result = this.applyDateCalc(result);
    result = this.applyVariables(result, context);

    return result;
  }

  private async applyLqlQueries(template: string): Promise<string> {
    let result = template;
    const lqlRegex = /\{\{lql:\s*([^}]+)\}\}/g;
    const replacements: LQLReplacement[] = [];
    let match: RegExpExecArray | null;
    while ((match = lqlRegex.exec(template)) !== null) {
      try {
        const lqlText = match[1].trim();
        const lqlResult = await lqlExecutor.execute(lqlText);
        const html = lqlRenderer.render(lqlResult);
        const rep: LQLReplacement = { original: match[0], html: '<div style="margin:8px 0;">' + html + '</div>' };
        replacements.push(rep);
      } catch (e) {
        const rep: LQLReplacement = { original: match[0], html: '[LQL错误]' };
        replacements.push(rep);
      }
    }
    for (let i = 0; i < replacements.length; i++) {
      const r = replacements[i];
      result = result.split(r.original).join(r.html);
    }
    return result;
  }

  private applyIfBlocks(template: string, context: TemplateContext): string {
    let result = template;
    let previous = '';
    while (previous !== result) {
      previous = result;
      const ifRegex = /\{\{#if\s+([^}]+)\}\}([\s\S]*?)\{\{\/if\}\}/g;
      result = result.replace(ifRegex, (_m: string, condition: string, body: string): string => {
        if (body.includes('{{#if') || body.includes('{{#each')) {
          return _m;
        }
        return this.evaluateIfBody(body, condition.trim(), context);
      });
    }
    return result;
  }

  private evaluateIfBody(body: string, condition: string, context: TemplateContext): string {
    let ifBody = body;
    let elseBody = '';
    const elseIdx = body.indexOf('{{else}}');
    if (elseIdx >= 0) {
      ifBody = body.substring(0, elseIdx);
      elseBody = body.substring(elseIdx + 8);
    }
    if (this.evaluateCondition(condition, context)) {
      return this.replaceVariables(ifBody, context);
    }
    if (elseBody !== '') {
      return this.replaceVariables(elseBody, context);
    }
    return '';
  }

  private applyEachBlocks(template: string, context: TemplateContext): string {
    let result = template;
    let previous = '';
    while (previous !== result) {
      previous = result;
      const eachRegex = /\{\{#each\s+([^}]+)\}\}([\s\S]*?)\{\{\/each\}\}/g;
      result = result.replace(eachRegex, (_m: string, arrayExpr: string, body: string): string => {
        if (body.includes('{{#each') || body.includes('{{#if')) {
          return _m;
        }
        const arr = this.resolveArray(arrayExpr.trim(), context);
        if (arr.length === 0) return '';
        let res = '';
        for (let i = 0; i < arr.length; i++) {
          const item = arr[i];
          const itemMap: VariablesMap = new VariablesMap();
          const ctxKeys = context.variables.keys();
          for (let k = 0; k < ctxKeys.length; k++) {
            const ck = ctxKeys[k];
            const cv = context.variables.get(ck);
            if (cv !== undefined) {
              itemMap.set(ck, cv);
            }
          }
          itemMap.set('this', item);
          const itemCtx: TemplateContext = { variables: itemMap };
          res += this.replaceVariables(body, itemCtx);
        }
        return res;
      });
    }
    return result;
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
      const val = context.variables.get(varName);
      if (val === undefined) {
        return '{{' + varName + '}}';
      }
      if (Array.isArray(val)) {
        return val.join(', ');
      }
      return val;
    });
  }

  private evaluateCondition(condition: string, context: TemplateContext): boolean {
    const eqMatch = condition.match(/^(\w+)\s*==\s*"([^"]+)"$/);
    if (eqMatch !== null) {
      const val = context.variables.get(eqMatch[1]);
      return String(val) === eqMatch[2];
    }
    const neqMatch = condition.match(/^(\w+)\s*!=\s*"([^"]+)"$/);
    if (neqMatch !== null) {
      const val = context.variables.get(neqMatch[1]);
      return String(val) !== neqMatch[2];
    }
    const existsMatch = condition.match(/^(\w+)$/);
    if (existsMatch !== null) {
      const val = context.variables.get(existsMatch[1]);
      return val !== undefined && val !== '' && val !== 'false';
    }
    return false;
  }

  private resolveArray(arrayExpr: string, context: TemplateContext): string[] {
    const parts = arrayExpr.split('.');
    const rootVar = parts[0] || arrayExpr;
    const val = context.variables.get(rootVar);
    if (val === undefined) return [];
    if (Array.isArray(val)) return val;
    if (typeof val === 'string') {
      return val.split(',').map((s: string) => s.trim()).filter((s: string) => s.length > 0);
    }
    return [];
  }

  private resolveDate(dateExpr: string): string {
    const now = new Date();
    let targetMs = now.getTime();
    let targetMonth = now.getMonth();
    let targetYear = now.getFullYear();
    let useMonth = false;
    let useYear = false;

    const offsetRegex = /([+-]?\d+)([dmy])/g;
    let m: RegExpExecArray | null;
    while ((m = offsetRegex.exec(dateExpr)) !== null) {
      const num = parseInt(m[1]);
      const unit = m[2];
      if (unit === 'd') { targetMs += num * 86400000; }
      if (unit === 'm') { targetMonth += num; useMonth = true; }
      if (unit === 'y') { targetYear += num; useYear = true; }
    }

    let target: Date;
    if (useMonth || useYear) {
      target = new Date(targetYear, targetMonth, now.getDate(), now.getHours(), now.getMinutes());
    } else {
      target = new Date(targetMs);
    }

    const formatMatch = dateExpr.match(/format\s+"([^"]+)"/);
    const fmt = formatMatch ? formatMatch[1] : 'YYYY-MM-DD';

    return this.formatDate(target, fmt);
  }

  private formatDate(date: Date, format: string): string {
    const y = String(date.getFullYear());
    const mStr = '0' + String(date.getMonth() + 1);
    const m = mStr.substring(mStr.length - 2);
    const dStr = '0' + String(date.getDate());
    const d = dStr.substring(dStr.length - 2);
    const hStr = '0' + String(date.getHours());
    const h = hStr.substring(hStr.length - 2);
    const miStr = '0' + String(date.getMinutes());
    const mi = miStr.substring(miStr.length - 2);

    let result = format;
    result = result.replace('YYYY', y);
    result = result.replace('MM', m);
    result = result.replace('DD', d);
    result = result.replace('HH', h);
    result = result.replace('mm', mi);
    return result;
  }
}

export const templateExecutor: TemplateExecutor = new TemplateExecutor();
