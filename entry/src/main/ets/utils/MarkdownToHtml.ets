/**
 * Markdown → HTML 转换器
 * 输出仅包含 RTV parseHTMLAsAST 支持的标签：<p> <strong> <b> <i> <u> <s> <a> <span>
 */

import { lqlExecutor } from './LQLExecutor';
import { lqlRenderer } from './LQLRenderer';

interface LQLBlockEntry {
  placeholder: string;
  code: string;
}

export async function markdownToHtml(md: string): Promise<string> {
  if (!md) {
    return '';
  }

  // 1. 提取代码块，Mermaid / LQL 特殊处理
  const codeBlocks: string[] = [];
  const lqlBlocks: LQLBlockEntry[] = [];
  let blockIndex = 0;
  let processed = md.replace(/```(\w*)\n([\s\S]*?)```/g, (_m: string, lang: string, code: string): string => {
    const idx = blockIndex;
    blockIndex = blockIndex + 1;
    if (lang === 'lql') {
      const lb: LQLBlockEntry = { placeholder: '@@LQLBLOCK_' + idx + '@@', code: code };
      lqlBlocks.push(lb);
      return `\n@@LQLBLOCK_${idx}@@\n`;
    }
    if (lang === 'mermaid') {
      const lineCount = code.trim().split('\n').length;
      codeBlocks.push(`<p><span style="fontFamily:monospace;background-color:#F8F0FF;color:#9C27B0;fontWeight:bold;padding:8px;display:block;border-left:4px solid #9C27B0">[Mermaid 图表 — 共 ${lineCount} 行]</span></p>`);
    } else {
      const lines: string[] = code.trimEnd().split('\n');
      let escaped = '';
      for (let j = 0; j < lines.length; j++) {
        escaped += escapeHtml(lines[j]);
        if (j < lines.length - 1) { escaped += '\n'; }
      }
      codeBlocks.push(`<p><span style="fontFamily:monospace;background-color:#F0F0F0;padding:4px">${escaped}</span></p>`);
    }
    const placeholder = `\n@@CODEBLOCK_${codeBlocks.length - 1}@@\n`;
    return placeholder;
  });

  // 2. 执行 LQL 查询并替换占位符
  for (let i = 0; i < lqlBlocks.length; i++) {
    const lb = lqlBlocks[i];
    try {
      const result = await lqlExecutor.execute(lb.code);
      const html = lqlRenderer.render(result);
      processed = processed.replace(lb.placeholder, `<div style="margin:12px 0;">${html}</div>`);
    } catch (e) {
      processed = processed.replace(lb.placeholder, '<p><span style="color:#E74C3C;font-size:12px;">LQL 查询错误</span></p>');
    }
  }

  // 3. 行内代码保护
  const inlineCodes: string[] = [];
  processed = processed.replace(/`([^`]+)`/g, (_m: string, code: string): string => {
    const idx = inlineCodes.length;
    inlineCodes.push(escapeHtml(code));
    return `@@INLINECODE_${idx}@@`;
  });

  // 4. 图片 → 链接替代表示
  const mediaItems: string[] = [];
  processed = processed.replace(/!\[([^\]]*)\]\(([^)]+)\)/g, (_m: string, alt: string, _url: string): string => {
    mediaItems.push(`[图片: ${escapeHtml(alt)}]`);
    return `@@MEDIA_${mediaItems.length - 1}@@`;
  });

  // 5. 表格提取
  const tableItems: string[] = [];
  processed = processed.replace(/(^\|.+\|[ \t]*\n)(^\|[-:| ]+\|[ \t]*\n)((?:^\|.+\|[ \t]*\n)*)/gm,
    (_m: string): string => {
      const lines = _m.trim().split('\n');
      if (lines.length < 2) {
        return _m;
      }
      const headerCells = lines[0].split('|').filter((c: string) => c.trim() !== '');
      const rows: string[][] = [];
      for (let r = 2; r < lines.length; r++) {
        const cells = lines[r].split('|').filter((c2: string) => c2.trim() !== '');
        if (cells.length > 0) {
          rows.push(cells);
        }
      }
      let html = '';
      for (let c = 0; c < headerCells.length; c++) {
        html += '<span style="fontWeight:bold">' + processInline(headerCells[c].trim()) + '</span>';
        if (c < headerCells.length - 1) {
          html += ' | ';
        }
      }
      html += '\n';
      html += '<span style="color:#CCCCCC">' + '-'.repeat(20) + '</span>\n';
      for (let ri = 0; ri < rows.length; ri++) {
        const row = rows[ri];
        for (let ci = 0; ci < row.length; ci++) {
          html += processInline(row[ci].trim());
          if (ci < row.length - 1) {
            html += ' | ';
          }
        }
        html += '\n';
      }
      tableItems.push('<p>' + html.replace(/\n/g, '</p><p>') + '</p>');
      return '@@TABLE_' + (tableItems.length - 1) + '@@';
    });

  // 6. 链接提取
  const linkItems: string[] = [];
  processed = processed.replace(/\[([^\]]+)\]\(([^)]+)\)/g, (_m: string, text: string, url: string): string => {
    linkItems.push('<a href="' + escapeAttr(url) + '">' + escapeHtml(text) + '</a>');
    return '@@LINK_' + (linkItems.length - 1) + '@@';
  });

  // 7. 按行处理块级
  const lines = processed.split('\n');
  const result: string[] = [];
  let inList: 'ul' | 'ol' | null = null;
  let inQuote: boolean = false;

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const trimmedLine = line.trim();

    // 代码块 / LQL 占位
    if (trimmedLine.startsWith('@@CODEBLOCK_') || trimmedLine.startsWith('@@LQLBLOCK_')) {
      flushList(result, inList);
      inList = null;
      flushQuote(result, inQuote);
      inQuote = false;
      result.push(trimmedLine);
      continue;
    }

    // 空行
    if (trimmedLine === '') {
      flushList(result, inList);
      inList = null;
      flushQuote(result, inQuote);
      inQuote = false;
      result.push('<p></p>');
      continue;
    }

    // 水平分割线
    if (!line.includes('|') && /^(---|\*\*\*|___)\s*$/.test(trimmedLine)) {
      flushList(result, inList);
      inList = null;
      result.push('<p>───</p>');
      continue;
    }

    // 标题
    const headingMatch = line.match(/^(#{1,6})\s+(.*)/);
    if (headingMatch) {
      flushList(result, inList);
      inList = null;
      result.push('<p><strong>' + processInline(headingMatch[2]) + '</strong></p>');
      continue;
    }

    // 列表项
    const ulMatch = line.match(/^([ \t]*)[\-\*\+]\s+(.*)/);
    const olMatch = line.match(/^([ \t]*)\d+\.\s+(.*)/);

    if (ulMatch !== null || olMatch !== null) {
      const match = ulMatch !== null ? ulMatch : olMatch;
      const indent: number = match !== null ? match[1].length : 0;
      const content: string = match !== null ? processInline(match[2]) : '';
      const isOrdered: boolean = olMatch !== null;
      const listType: 'ul' | 'ol' = isOrdered ? 'ol' : 'ul';
      const prefix: string = isOrdered ? '1. ' : '• ';

      if (inList === null) {
        inList = listType;
      } else if (inList !== listType) {
        flushList(result, inList);
        inList = listType;
      }

      if (indent > 0) {
        result.push('<p><span style="paddingLeft:' + (indent * 12) + 'px">' + prefix + content + '</span></p>');
      } else {
        result.push('<p>' + prefix + content + '</p>');
      }
      continue;
    }

    // Callout
    const calloutMatch = line.match(/^>\s*\[!(\w+)\]\s?(.*)/);
    if (calloutMatch) {
      flushQuote(result, inQuote);
      inQuote = false;
      const calloutColors: Map<string, string> = new Map();
      calloutColors.set('note', '#4A90D9');
      calloutColors.set('warning', '#F5A623');
      calloutColors.set('tip', '#4CAF50');
      calloutColors.set('danger', '#E53935');
      calloutColors.set('info', '#2196F3');
      calloutColors.set('abstract', '#9C27B0');
      calloutColors.set('success', '#4CAF50');
      calloutColors.set('question', '#FF9800');
      const cc = calloutColors.get(calloutMatch[1]) || '#7B68EE';
      result.push('<p><span style="fontWeight:bold;color:' + cc + '">[!' + calloutMatch[1] + ']</span> ' +
        processInline(calloutMatch[2] || '') + '</p>');
      continue;
    }

    // 引用
    const quoteMatch = line.match(/^>\s?(.*)/);
    if (quoteMatch) {
      if (!inQuote) {
        result.push('<p>│</p>');
        inQuote = true;
      }
      result.push('<p>' + processInline(quoteMatch[1]) + '</p>');
      continue;
    }

    // 普通段落
    flushList(result, inList);
    inList = null;
    flushQuote(result, inQuote);
    inQuote = false;
    result.push('<p>' + processInline(restoreLine(line, inlineCodes, mediaItems, linkItems, tableItems)) + '</p>');
  }

  flushList(result, inList);
  flushQuote(result, inQuote);
  return result.join('\n');
}

// ─── 行内 Markdown → HTML ──────────────────

function processInline(text: string): string {
  let t = text;
  t = t.replace(/\*\*\*(.+?)\*\*\*/g, '<strong><i>$1</i></strong>');
  t = t.replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>');
  t = t.replace(/\*(.+?)\*/g, '<i>$1</i>');
  t = t.replace(/~~(.+?)~~/g, '<s>$1</s>');
  return t;
}

// ─── 辅助 ──────────────────────────────────

function restoreLine(line: string, codes: string[], media: string[], links: string[], tables: string[]): string {
  let l = line;
  for (let i = 0; i < codes.length; i++) {
    l = l.replace('@@INLINECODE_' + i + '@@', '<span style="fontFamily:monospace;background-color:#F0F0F0">' + codes[i] + '</span>');
  }
  for (let i = 0; i < media.length; i++) {
    l = l.replace('@@MEDIA_' + i + '@@', media[i]);
  }
  for (let i = 0; i < links.length; i++) {
    l = l.replace('@@LINK_' + i + '@@', links[i]);
  }
  for (let i = 0; i < tables.length; i++) {
    l = l.replace('@@TABLE_' + i + '@@', tables[i]);
  }
  return l;
}

function escapeHtml(s: string): string {
  let r = s;
  r = r.replace(/&/g, '&amp;');
  r = r.replace(/</g, '&lt;');
  r = r.replace(/>/g, '&gt;');
  return r;
}

function escapeAttr(s: string): string {
  let r = s;
  r = r.replace(/&/g, '&amp;');
  r = r.replace(/"/g, '&quot;');
  return r;
}

function flushList(result: string[], listType: 'ul' | 'ol' | null): void {
  if (listType !== null) {
    result.push('<p></p>');
  }
}

function flushQuote(result: string[], inQuote: boolean): void {
  if (inQuote) {
    result.push('<p></p>');
  }
}
