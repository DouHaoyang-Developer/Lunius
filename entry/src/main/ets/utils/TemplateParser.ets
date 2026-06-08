// utils/TemplateParser.ets
// 模板表达式解析器 — 识别 {{...}} 块并区分类型

export enum TemplateExprType {
  VARIABLE = 'variable',
  IF_BLOCK = 'if_block',
  EACH_BLOCK = 'each_block',
  LQL_QUERY = 'lql_query',
  DATE_CALC = 'date_calc'
}

export interface TemplateExpr {
  type: TemplateExprType;
  raw: string;
  // variable
  variableName?: string;
  defaultValue?: string;
  // if_block
  ifCondition?: string;
  ifBody?: string;
  elseBody?: string;
  // each_block
  eachArray?: string;
  eachItem?: string;
  eachBody?: string;
  // lql_query
  lqlText?: string;
  // date_calc
  dateOffset?: string;
  dateFormat?: string;
}

export class TemplateParser {
  parse(template: string): TemplateExpr[] {
    const exprs: TemplateExpr[] = [];
    let pos = 0;

    while (pos < template.length) {
      const openIdx = template.indexOf('{{', pos);
      if (openIdx === -1) break;

      const closeIdx = template.indexOf('}}', openIdx);
      if (closeIdx === -1) break;

      const inner = template.substring(openIdx + 2, closeIdx).trim();
      const expr = this.parseInner(inner);
      if (expr) {
        exprs.push(expr);
      }

      pos = closeIdx + 2;
    }

    return exprs;
  }

  private parseInner(inner: string): TemplateExpr | null {
    // LQL 查询: {{lql: TABLE ...}}
    if (inner.startsWith('lql:')) {
      return {
        type: TemplateExprType.LQL_QUERY,
        raw: inner,
        lqlText: inner.substring(4).trim()
      };
    }

    // 条件块: {{#if condition}}body{{/if}}
    if (inner.startsWith('#if ')) {
      return {
        type: TemplateExprType.IF_BLOCK,
        raw: inner,
        ifCondition: inner.substring(4).trim()
      };
    }

    // 循环块: {{#each array}}body{{/each}}
    if (inner.startsWith('#each ')) {
      return {
        type: TemplateExprType.EACH_BLOCK,
        raw: inner,
        eachArray: inner.substring(6).trim()
      };
    }

    // 日期计算: {{date: +7d}} 或 {{date: now | format "YYYY-MM-DD"}}
    if (inner.startsWith('date:')) {
      const datePart = inner.substring(5).trim();
      let offset = '';
      let format = 'YYYY-MM-DD';

      const pipeIdx = datePart.indexOf('|');
      if (pipeIdx >= 0) {
        offset = datePart.substring(0, pipeIdx).trim();
        const formatMatch = datePart.substring(pipeIdx + 1).match(/format\s+"([^"]+)"/);
        if (formatMatch) {
          format = formatMatch[1];
        }
      } else {
        offset = datePart;
      }

      return {
        type: TemplateExprType.DATE_CALC,
        raw: inner,
        dateOffset: offset === 'now' ? '+0d' : offset,
        dateFormat: format
      };
    }

    // 闭合标签: {{/if}} {{/each}} — 在 applyTemplate 中处理
    if (inner === '/if' || inner === '/each') {
      return null;
    }

    // 变量: {{title}} {{date}} 等
    return {
      type: TemplateExprType.VARIABLE,
      raw: inner,
      variableName: inner
    };
  }
}

export const templateParser: TemplateParser = new TemplateParser();
