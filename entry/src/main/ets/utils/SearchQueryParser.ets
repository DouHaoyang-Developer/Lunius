// utils/SearchQueryParser.ets
// 搜索查询解析器 — 解析 tag: path: file: property: -tag: 等结构化搜索运算符

export interface PropertyFilter {
  key: string;
  operator: 'equals' | 'not_equals' | 'contains' | 'greater_than' | 'less_than' | 'exists';
  value: string;
}

export interface ParsedSearchQuery {
  textTerms: string[];
  tags: string[];
  paths: string[];
  files: string[];
  notTags: string[];
  propertyFilters: PropertyFilter[];
  caseSensitive: boolean;
}

export function parseSearchQuery(raw: string): ParsedSearchQuery {
  const result: ParsedSearchQuery = {
    textTerms: [],
    tags: [],
    paths: [],
    files: [],
    notTags: [],
    propertyFilters: [],
    caseSensitive: false
  };

  let remaining = raw;

  // property:key:value 或 property:key:>3 或 property:key
  const propRegex = /property:([^\s:]+)(?::([^\s]+))?/gi;
  let m: RegExpExecArray | null;
  while ((m = propRegex.exec(raw)) !== null) {
    const key = m[1];
    const rawVal = m[2];
    let operator: 'equals' | 'not_equals' | 'contains' | 'greater_than' | 'less_than' | 'exists' = 'exists';
    let value = '';
    if (rawVal !== undefined && rawVal !== '') {
      if (rawVal.startsWith('>')) {
        operator = 'greater_than';
        value = rawVal.substring(1);
      } else if (rawVal.startsWith('<')) {
        operator = 'less_than';
        value = rawVal.substring(1);
      } else if (rawVal.startsWith('!')) {
        operator = 'not_equals';
        value = rawVal.substring(1);
      } else {
        operator = 'equals';
        value = rawVal;
      }
    }
    result.propertyFilters.push({ key: key, operator: operator, value: value });
    remaining = remaining.replace(m[0], '');
  }

  // tag:/path:/file: 运算符
  const operatorRegex = /(tag|path|file):([^\s]+)/gi;
  while ((m = operatorRegex.exec(remaining)) !== null) {
    const op = m[1].toLowerCase();
    const value = m[2];
    switch (op) {
      case 'tag':
        result.tags.push(value);
        break;
      case 'path':
        result.paths.push(value);
        break;
      case 'file':
        result.files.push(value);
        break;
    }
    remaining = remaining.replace(m[0], '');
  }

  // -tag: 否定运算符
  const negRegex = /-tag:([^\s]+)/g;
  while ((m = negRegex.exec(remaining)) !== null) {
    result.notTags.push(m[1]);
    remaining = remaining.replace(m[0], '');
  }

  result.textTerms = remaining.trim().split(/\s+/).filter((s: string) => s.length > 0);
  return result;
}
