// utils/SearchQueryParser.ets
// 搜索查询解析器 — 解析 tag: path: file: - 等结构化搜索运算符

export interface ParsedSearchQuery {
  textTerms: string[];
  tags: string[];
  paths: string[];
  files: string[];
  notTags: string[];
  caseSensitive: boolean;
}

export function parseSearchQuery(raw: string): ParsedSearchQuery {
  const result: ParsedSearchQuery = {
    textTerms: [],
    tags: [],
    paths: [],
    files: [],
    notTags: [],
    caseSensitive: false
  };

  let remaining = raw;
  const operatorRegex = /(tag|path|file):([^\s]+)/gi;
  let m: RegExpExecArray | null;

  while ((m = operatorRegex.exec(raw)) !== null) {
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

  // 处理 -tag: 否定运算符
  const negRegex = /-tag:([^\s]+)/g;
  while ((m = negRegex.exec(remaining)) !== null) {
    result.notTags.push(m[1]);
    remaining = remaining.replace(m[0], '');
  }

  result.textTerms = remaining.trim().split(/\s+/).filter((s: string) => s.length > 0);
  return result;
}
