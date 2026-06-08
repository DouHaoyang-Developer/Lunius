// utils/LQLParser.ets
// LQL 递归下降语法分析器 → LQLAst

import { Token, TokenType, tokenizeLQL } from './LQLTokenizer';
import { FilterGroup, FilterCondition, SortRule } from '../models/BasesTypes';

export enum LQLOutputType {
  TABLE = 'TABLE',
  LIST = 'LIST',
  TASK = 'TASK',
  CALENDAR = 'CALENDAR'
}

export interface SourceExpr {
  type: 'path' | 'tag' | 'link';
  value: string;
}

export interface LQLAst {
  outputType: LQLOutputType;
  columns: string[];
  fromSources: SourceExpr[];
  whereClause: FilterGroup | null;
  sortRules: SortRule[];
  groupBy: string;
  limit: number;
}

export class LQLParser {
  private tokens: Token[] = [];
  private pos: number = 0;

  parse(input: string): LQLAst {
    this.tokens = tokenizeLQL(input);
    this.pos = 0;
    return this.parseQuery();
  }

  private peek(): Token {
    return this.pos < this.tokens.length ? this.tokens[this.pos] : this.tokens[this.tokens.length - 1];
  }

  private advance(): Token {
    const t = this.peek();
    this.pos++;
    return t;
  }

  private expect(type: TokenType, value?: string): Token {
    const t = this.advance();
    if (t.type !== type) {
      throw new Error(`Expected ${type} but got ${t.type} '${t.value}' at position ${t.position}`);
    }
    if (value !== undefined && t.value.toUpperCase() !== value.toUpperCase()) {
      throw new Error(`Expected '${value}' but got '${t.value}' at position ${t.position}`);
    }
    return t;
  }

  private matchKeyword(...values: string[]): boolean {
    const t = this.peek();
    if (t.type === TokenType.KEYWORD) {
      for (const v of values) {
        if (t.value.toUpperCase() === v.toUpperCase()) return true;
      }
    }
    return false;
  }

  private parseQuery(): LQLAst {
    const ast: LQLAst = {
      outputType: LQLOutputType.TABLE,
      columns: [],
      fromSources: [],
      whereClause: null,
      sortRules: [],
      groupBy: '',
      limit: 0
    };

    // 输出类型
    const first = this.peek();
    if (first.type === TokenType.KEYWORD) {
      const kw = first.value.toUpperCase();
      if (kw === 'TABLE' || kw === 'LIST' || kw === 'TASK' || kw === 'CALENDAR') {
        ast.outputType = kw as LQLOutputType;
        this.advance();
      }
    }

    // TABLE 的列
    if (ast.outputType === LQLOutputType.TABLE) {
      while (this.peek().type === TokenType.IDENTIFIER) {
        ast.columns.push(this.advance().value);
        if (this.peek().type === TokenType.COMMA) this.advance();
      }
    }

    // FROM
    if (this.matchKeyword('FROM')) {
      this.advance(); // skip FROM
      this.parseFromClause(ast);
    }

    // WHERE
    if (this.matchKeyword('WHERE')) {
      this.advance(); // skip WHERE
      ast.whereClause = this.parseWhereClause();
    }

    // SORT
    if (this.matchKeyword('SORT')) {
      this.advance(); // skip SORT
      this.parseSortClause(ast);
    }

    // GROUP BY
    if (this.matchKeyword('GROUP')) {
      this.advance(); // skip GROUP
      this.expect(TokenType.KEYWORD, 'BY');
      if (this.peek().type === TokenType.IDENTIFIER) {
        ast.groupBy = this.advance().value;
      }
    }

    // LIMIT
    if (this.matchKeyword('LIMIT')) {
      this.advance(); // skip LIMIT
      if (this.peek().type === TokenType.NUMBER) {
        ast.limit = parseInt(this.advance().value);
      }
    }

    return ast;
  }

  private parseFromClause(ast: LQLAst): void {
    while (this.peek().type !== TokenType.EOF &&
           !this.matchKeyword('WHERE', 'SORT', 'GROUP', 'LIMIT')) {
      const t = this.peek();

      if (t.type === TokenType.STRING) {
        ast.fromSources.push({ type: 'path', value: this.advance().value });
      } else if (t.type === TokenType.TAG) {
        ast.fromSources.push({ type: 'tag', value: this.advance().value });
      }

      // 跳过 OR
      if (this.matchKeyword('OR')) this.advance();
      if (this.peek().type === TokenType.COMMA) this.advance();
    }
  }

  private parseWhereClause(): FilterGroup {
    const group: FilterGroup = {
      conjunction: 'and',
      conditions: []
    };

    let currentConjunction: 'and' | 'or' = 'and';

    while (this.peek().type !== TokenType.EOF &&
           !this.matchKeyword('SORT', 'GROUP', 'LIMIT')) {
      // 切换连接词
      if (this.matchKeyword('AND')) {
        this.advance();
        currentConjunction = 'and';
        continue;
      }
      if (this.matchKeyword('OR')) {
        this.advance();
        currentConjunction = 'or';
        continue;
      }

      const cond = this.parseCondition();
      if (cond) {
        group.conjunction = currentConjunction;
        group.conditions.push(cond);
      } else {
        break;
      }
    }

    return group;
  }

  private parseCondition(): FilterCondition | null {
    const t = this.peek();
    if (t.type !== TokenType.IDENTIFIER) return null;

    const property = this.advance().value;

    let useExists = true;
    let opValue = 'exists';
    let negate = false;

    if (this.matchKeyword('NOT')) {
      this.advance();
      negate = true;
    }

    if (this.peek().type === TokenType.OPERATOR) {
      useExists = false;
      const op = this.advance().value;
      if (op === '=') { opValue = negate ? 'not_equals' : 'equals'; }
      else if (op === '!=') { opValue = 'not_equals'; }
      else if (op === '>' || op === '>=') { opValue = 'greater_than'; }
      else if (op === '<' || op === '<=') { opValue = 'less_than'; }
    }

    if (this.matchKeyword('TRUE')) {
      const cond: FilterCondition = { property: property, operator: 'equals', value: 'true' };
      return cond;
    }

    let value = '';
    if (this.peek().type === TokenType.STRING) {
      value = this.advance().value;
    } else if (this.peek().type === TokenType.NUMBER) {
      value = this.advance().value;
    } else if (this.peek().type === TokenType.TAG) {
      value = this.advance().value;
    }

    if (useExists) {
      const cond: FilterCondition = { property: property, operator: 'exists', value: '' };
      return cond;
    }

    // 直接构建 FilterCondition（操作符已确定）
    if (opValue === 'equals') {
      const cond: FilterCondition = { property: property, operator: 'equals', value: value };
      return cond;
    }
    if (opValue === 'not_equals') {
      const cond: FilterCondition = { property: property, operator: 'not_equals', value: value };
      return cond;
    }
    if (opValue === 'greater_than') {
      const cond: FilterCondition = { property: property, operator: 'greater_than', value: value };
      return cond;
    }
    if (opValue === 'less_than') {
      const cond: FilterCondition = { property: property, operator: 'less_than', value: value };
      return cond;
    }
    const cond: FilterCondition = { property: property, operator: 'contains', value: value };
    return cond;
  }

  private parseSortClause(ast: LQLAst): void {
    while (this.peek().type === TokenType.IDENTIFIER) {
      const prop = this.advance().value;
      let dir: 'asc' | 'desc' = 'asc';
      if (this.matchKeyword('ASC')) { this.advance(); dir = 'asc'; }
      else if (this.matchKeyword('DESC')) { this.advance(); dir = 'desc'; }
      ast.sortRules.push({ property: prop, direction: dir });
      if (this.peek().type === TokenType.COMMA) this.advance();
    }
  }
}

export function parseLQL(input: string): LQLAst {
  const parser = new LQLParser();
  return parser.parse(input);
}
