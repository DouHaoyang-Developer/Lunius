/**
 * Markdown → HTML 转换器
 * 输出仅包含 RTV parseHTMLAsAST 支持的标签：<p> <strong> <b> <i> <u> <s> <a> <span>
 */

export function markdownToHtml(md: string): string {
  if (!md) {
    return '';
  }

  // 1. 提取代码块（用缩进+背景色模拟）
  const codeBlocks: string[] = [];
  let processed = md.replace(/```(\w*)\n([\s\S]*?)```/g, (_m: string, _lang: string, code: string): string => {
    const lines: string[] = code.trimEnd().split('\n');
    let escaped = '';
    for (let j = 0; j < lines.length; j++) {
      escaped += escapeHtml(lines[j]);
      if (j < lines.length - 1) {
        escaped += '\n';
      }
    }
    codeBlocks.push(`<p><span style="fontFamily:monospace;background-color:#F0F0F0;padding:4">${escaped}</span></p>`);
    return `\n@@CODEBLOCK_${codeBlocks.length - 1}@@\n`;
  });

  // 2. 行内代码保护
  const inlineCodes: string[] = [];
  processed = processed.replace(/`([^`]+)`/g, (_m: string, code: string): string => {
    inlineCodes.push(escapeHtml(code));
    return `@@INLINECODE_${inlineCodes.length - 1}@@`;
  });

  // 3. 图片 → 链接替代表示
  const mediaItems: string[] = [];
  processed = processed.replace(/!\[([^\]]*)\]\(([^)]+)\)/g, (_m: string, alt: string, _url: string): string => {
    mediaItems.push(`[图片: ${escapeHtml(alt)}]`);
    return `@@MEDIA_${mediaItems.length - 1}@@`;
  });

  // 3.5 表格提取 → 占位符
  const tableItems: string[] = [];
  processed = processed.replace(
    /(^\|.+\|[ \t]*\n)(^\|[-:| ]+\|[ \t]*\n)((?:^\|.+\|[ \t]*\n)*)/gm,
    (_m: string): string => {
      const lines = _m.trim().split('\n');
      if (lines.length < 2) {
        return _m;
      }
      // 解析表头
      const headerCells = lines[0].split('|').filter((c: string) => c.trim() !== '');
      // 数据行从第 2 行开始（第 1 行是分隔行）
      const rows: string[][] = [];
      for (let r = 2; r < lines.length; r++) {
        const cells = lines[r].split('|').filter((c: string) => c.trim() !== '');
        if (cells.length > 0) {
          rows.push(cells);
        }
      }
      let html = '';
      // 表头
      for (let c = 0; c < headerCells.length; c++) {
        html += '<span style="fontWeight:bold">' + processInline(headerCells[c].trim()) + '</span>';
        if (c < headerCells.length - 1) {
          html += ' | ';
        }
      }
      html += '\n';
      // 分隔线
      html += '<span style="color:#CCCCCC">' + '—'.repeat(20) + '</span>\n';
      // 数据行
      for (const row of rows) {
        for (let c = 0; c < row.length; c++) {
          html += processInline(row[c].trim());
          if (c < row.length - 1) {
            html += ' | ';
          }
        }
        html += '\n';
      }
      tableItems.push('<p>' + html.replace(/\n/g, '</p><p>') + '</p>');
      return '@@TABLE_' + (tableItems.length - 1) + '@@';
    });

  // 4. 链接提取
  const linkItems: string[] = [];
  processed = processed.replace(/\[([^\]]+)\]\(([^)]+)\)/g, (_m: string, text: string, url: string): string => {
    linkItems.push(`<a href="${escapeAttr(url)}">${escapeHtml(text)}</a>`);
    return `@@LINK_${linkItems.length - 1}@@`;
  });

  // 5. 按行处理块级
  const lines = processed.split('\n');
  const result: string[] = [];
  let inList: 'ul' | 'ol' | null = null;
  let inQuote = false;

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];

    // 代码块占位
    if (/^@@CODEBLOCK_\d+@@$/.test(line.trim())) {
      flushList(result, inList);
      inList = null;
      flushQuote(result, inQuote);
      inQuote = false;
      result.push(line.trim());
      continue;
    }

    // 空行：结束列表/引用
    if (line.trim() === '') {
      flushList(result, inList);
      inList = null;
      flushQuote(result, inQuote);
      inQuote = false;
      result.push('<p></p>');
      continue;
    }

    // 水平分割线 → <p>───</p>（排除表格分隔行 |---|）
    if (!line.includes('|') && /^(---|\*\*\*|___)\s*$/.test(line.trim())) {
      flushList(result, inList);
      inList = null;
      result.push('<p>───</p>');
      continue;
    }

    // 标题 → <p><strong>
    const headingMatch = line.match(/^(#{1,6})\s+(.*)/);
    if (headingMatch) {
      flushList(result, inList);
      inList = null;
      result.push(`<p><strong>${processInline(headingMatch[2])}</strong></p>`);
      continue;
    }

    // 列表项处理（支持缩进嵌套，用 paddingLeft 模拟层级）
    const ulMatch = line.match(/^([ \t]*)[\-\*\+]\s+(.*)/);
    const olMatch = line.match(/^([ \t]*)\d+\.\s+(.*)/);

    if (ulMatch || olMatch) {
      const indent: number = (ulMatch || olMatch)![1].length;
      const content: string = processInline((ulMatch || olMatch)![2]);
      const isOrdered: boolean = !!olMatch;
      const listType: 'ul' | 'ol' = isOrdered ? 'ol' : 'ul';
      const prefix: string = isOrdered
        ? ((line.match(/^\s*\d+/) as string[])[0] || '1') + '. '
        : '• ';

      if (inList === null) {
        inList = listType;
      } else if (inList !== listType) {
        flushList(result, inList);
        inList = listType;
      }

      if (indent > 0) {
        result.push(`<p><span style="paddingLeft:${indent * 12}px">${prefix}${content}</span></p>`);
      } else {
        result.push(`<p>${prefix}${content}</p>`);
      }
      continue;
    }

    // 引用
    const quoteMatch = line.match(/^>\s?(.*)/);
    if (quoteMatch) {
      if (!inQuote) {
        result.push('<p>│</p>');
        inQuote = true;
      }
      result.push(`<p>${processInline(quoteMatch[1])}</p>`);
      continue;
    }

    // 普通段落
    flushList(result, inList);
    inList = null;
    flushQuote(result, inQuote);
    inQuote = false;
    result.push(`<p>${processInline(restoreLine(line, inlineCodes, mediaItems, linkItems, tableItems))}</p>`);
  }

  flushList(result, inList);
  flushQuote(result, inQuote);
  return result.join('\n');
}

// ─── 行内 Markdown → HTML（仅用 RTV 支持的标签）───

function processInline(text: string): string {
  let t = text;
  t = t.replace(/\*\*\*(.+?)\*\*\*/g, '<strong><i>$1</i></strong>');
  t = t.replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>');
  t = t.replace(/\*(.+?)\*/g, '<i>$1</i>');
  t = t.replace(/~~(.+?)~~/g, '<s>$1</s>');
  return t;
}

// ─── 辅助 ──────────────────────────────────────

function restoreLine(line: string, codes: string[], media: string[], links: string[], tables: string[]): string {
  let l = line;
  for (let i = 0; i < codes.length; i++) {
    l = l.replace(`@@INLINECODE_${i}@@`, `<span style="fontFamily:monospace;background-color:#F0F0F0">${codes[i]}</span>`);
  }
  for (let i = 0; i < media.length; i++) {
    l = l.replace(`@@MEDIA_${i}@@`, media[i]);
  }
  for (let i = 0; i < links.length; i++) {
    l = l.replace(`@@LINK_${i}@@`, links[i]);
  }
  for (let i = 0; i < tables.length; i++) {
    l = l.replace(`@@TABLE_${i}@@`, tables[i]);
  }
  return l;
}

function escapeHtml(s: string): string {
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

function escapeAttr(s: string): string {
  return s.replace(/&/g, '&amp;').replace(/"/g, '&quot;');
}

function flushList(result: string[], listType: 'ul' | 'ol' | null): void {
  if (listType) {
    result.push('<p></p>');
  }
}

function flushQuote(result: string[], inQuote: boolean): void {
  if (inQuote) {
    result.push('<p></p>');
  }
}
